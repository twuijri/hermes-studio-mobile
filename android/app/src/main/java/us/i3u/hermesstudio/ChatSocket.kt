package us.i3u.hermesstudio

import io.socket.client.IO
import io.socket.client.Socket
import io.socket.engineio.client.transports.Polling
import io.socket.engineio.client.transports.WebSocket
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.net.URLEncoder

/** What a run tells us while it is happening. */
sealed interface RunEvent {
    data class Started(val occurredAtMillis: Long) : RunEvent
    data class Text(val delta: String) : RunEvent
    data class Reasoning(val delta: String) : RunEvent
    data class Tool(
        val id: String,
        val name: String,
        val detail: String?,
        val status: ToolRunStatus,
        val durationSeconds: Double?,
        val occurredAtMillis: Long,
    ) : RunEvent
    data class Usage(val contextTokens: Long, val contextWindow: Long?) : RunEvent
    data class Done(val output: String, val reasoning: String) : RunEvent
    data class RequiresAction(
        val kind: RequiredAction,
        val id: String,
        val prompt: String,
        val options: List<String> = emptyList(),
    ) : RunEvent
    data class Failed(val error: String, val retryableTransport: Boolean) : RunEvent
}

enum class ToolRunStatus { Running, Done, Error }

enum class RequiredAction { Approval, Clarification }

/**
 * The streaming half of the chat API.
 *
 * `POST /api/chat-run/runs` is the server's own wrapper around this socket: it
 * connects, waits for the whole answer, and returns it. Talking to /chat-run
 * directly is the same conversation, except the words arrive as they are
 * written, and the run can be stopped part-way.
 */
class ChatSocket(
    private var baseUrl: String,
    private var token: String,
) {
    private var socket: Socket? = null

    fun update(baseUrl: String, token: String) {
        this.baseUrl = baseUrl.trimEnd('/')
        this.token = token
    }

    /** Stops the run the server is streaming for this session. */
    fun abort(sessionId: String) {
        runCatching { socket?.emit("abort", JSONObject().put("session_id", sessionId)) }
    }

    fun respondToApproval(sessionId: String, approvalId: String, choice: String) {
        socket?.emit("approval.respond", JSONObject().put("session_id", sessionId).put("approval_id", approvalId).put("choice", choice))
    }

    fun respondToClarification(sessionId: String, clarifyId: String, response: String) {
        socket?.emit("clarify.respond", JSONObject().put("session_id", sessionId).put("clarify_id", clarifyId).put("response", response))
    }

    fun run(
        profile: String,
        sessionId: String,
        input: String,
        attachments: List<Upload>,
        reasoningEffort: String?,
        model: String?,
        provider: String?,
        runtime: AgentRuntimeSelection = AgentRuntimeSelection(),
    ): Flow<RunEvent> = callbackFlow {
        val payload = JSONObject()
            .put("input", contentFor(input, attachments))
            .put("profile", profile)
            .put("session_id", sessionId)
        if (!reasoningEffort.isNullOrBlank()) payload.put("reasoning_effort", reasoningEffort)
        if (!model.isNullOrBlank()) payload.put("model", model)
        if (!provider.isNullOrBlank()) payload.put("provider", provider)
        if (!runtime.isHermes) {
            payload.put("source", "coding_agent")
            payload.put("coding_agent_id", runtime.codingAgentId)
            payload.put("mode", "global")
        }

        val options = IO.Options.builder()
            .setForceNew(true)
            .setReconnection(true)
            .setReconnectionAttempts(Int.MAX_VALUE)
            .setReconnectionDelay(1_000)
            .setReconnectionDelayMax(30_000)
            .setTransports(arrayOf(WebSocket.NAME, Polling.NAME))
            .setAuth(mapOf("token" to token))
            .setQuery("profile=" + URLEncoder.encode(profile, "UTF-8"))
            .setTimeout(30_000)
            .build()

        val live = IO.socket(URI.create(baseUrl.trimEnd('/') + "/chat-run"), options)
        socket = live
        var runStarted = false
        var terminal = false
        var submitted = false

        fun eventPayload(args: Array<out Any?>): JSONObject? = args.firstOrNull() as? JSONObject

        live.on(Socket.EVENT_CONNECT) {
            if (!submitted) {
                submitted = true
                live.emit("run", payload)
            } else {
                // A mobile network can change while an agent is working. Join
                // the existing session again instead of submitting the turn a
                // second time or showing a false "disconnected" reply.
                live.emit(
                    "resume",
                    JSONObject().put("session_id", sessionId).put("profile", profile),
                )
            }
        }
        live.on("resumed") { args ->
            val event = eventPayload(args) ?: return@on
            usageFrom(event)?.let { trySend(it) }
            if (event.optBoolean("isWorking", false)) {
                runStarted = true
                return@on
            }
            terminal = true
            val completion = completionFromResume(event)
            if (completion != null) {
                trySend(completion)
            } else {
                trySend(RunEvent.Failed("run finished without output", retryableTransport = false))
            }
            close()
        }
        live.on("run.started") {
            runStarted = true
            trySend(RunEvent.Started(System.currentTimeMillis()))
        }
        live.on("message.delta") { args ->
            val delta = eventPayload(args).firstString("delta", "text")
            if (delta.isNotEmpty()) {
                runStarted = true
                trySend(RunEvent.Text(delta))
            }
        }
        // Some models report thinking under one name, some under the other.
        listOf("reasoning.delta", "thinking.delta").forEach { event ->
            live.on(event) { args ->
                val delta = eventPayload(args).firstString("delta", "text")
                if (delta.isNotEmpty()) {
                    runStarted = true
                    trySend(RunEvent.Reasoning(delta))
                }
            }
        }
        live.on("tool.started") { args ->
            runStarted = true
            parseToolEvent(
                event = eventPayload(args),
                status = ToolRunStatus.Running,
                occurredAtMillis = System.currentTimeMillis(),
            )?.let { trySend(it) }
        }
        live.on("tool.completed") { args ->
            runStarted = true
            parseToolEvent(
                event = eventPayload(args),
                status = ToolRunStatus.Done,
                occurredAtMillis = System.currentTimeMillis(),
            )?.let { trySend(it) }
        }
        live.on("tool.failed") { args ->
            runStarted = true
            parseToolEvent(
                event = eventPayload(args),
                status = ToolRunStatus.Error,
                occurredAtMillis = System.currentTimeMillis(),
            )?.let { trySend(it) }
        }
        live.on("run.completed") { args ->
            terminal = true
            val event = args.firstOrNull() as? JSONObject
            usageFrom(event)?.let { trySend(it) }
            trySend(
                RunEvent.Done(
                    output = event?.optString("output").orEmpty(),
                    reasoning = event?.optString("reasoning").orEmpty(),
                ),
            )
            close()
        }
        live.on("run.failed") { args ->
            terminal = true
            val event = args.firstOrNull() as? JSONObject
            val message = event?.optString("error").orEmpty()
            trySend(RunEvent.Failed(message.ifBlank { "run failed" }, retryableTransport = false))
            close()
        }
        // A run that needs a human decision cannot be answered from here yet, so
        // it is reported rather than left hanging.
        live.on("approval.requested") { args ->
            val event = eventPayload(args) ?: JSONObject()
            val options = (event.optJSONArray("choices") ?: event.optJSONArray("options"))?.let { array ->
                (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
            }.orEmpty()
            trySend(RunEvent.RequiresAction(
                RequiredAction.Approval,
                event.firstString("approval_id", "id"),
                event.firstString("description", "command", "prompt", "message"),
                options,
            ))
        }
        live.on("clarify.requested") { args ->
            val event = eventPayload(args) ?: JSONObject()
            val options = (event.optJSONArray("choices") ?: event.optJSONArray("options"))?.let { array ->
                (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
            }.orEmpty()
            trySend(RunEvent.RequiresAction(
                RequiredAction.Clarification,
                event.firstString("clarify_id", "id"),
                event.firstString("prompt", "question", "message"),
                options,
            ))
        }
        live.on(Socket.EVENT_CONNECT_ERROR) { args ->
            // Before the first successful connection REST is the safe fallback.
            // Afterwards Socket.IO owns reconnection and resume; surfacing every
            // temporary radio/network loss as an assistant message is wrong.
            if (!submitted) {
                terminal = true
                val detail = args.firstOrNull()?.toString().orEmpty()
                trySend(RunEvent.Failed(detail.ifBlank { "connect_error" }, retryableTransport = true))
                close()
            }
        }
        live.on(Socket.EVENT_DISCONNECT) { args ->
            if (!terminal && !submitted) {
                trySend(RunEvent.Failed("disconnected", retryableTransport = !runStarted))
                close()
            } else if (!terminal && args.firstOrNull()?.toString() == "io server disconnect") {
                // Server-requested disconnects are not retried automatically by
                // Socket.IO, while transport and network disconnects are.
                live.connect()
            }
        }

        live.connect()

        awaitClose {
            live.off()
            live.disconnect()
            if (socket === live) socket = null
        }
    }

    /** Studio accepts a bare string, or blocks when files ride along. */
    private fun contentFor(input: String, attachments: List<Upload>): Any =
        if (attachments.isEmpty()) {
            input
        } else {
            JSONArray().apply {
                if (input.isNotBlank()) put(JSONObject().put("type", "text").put("text", input))
                attachments.forEach { file ->
                    put(
                        JSONObject()
                            .put("type", if (file.mime.startsWith("image/")) "image" else "file")
                            .put("name", file.name)
                            .put("path", file.path)
                            .put("media_type", file.mime),
                    )
                }
            }
        }
}

internal fun usageFrom(payload: JSONObject?): RunEvent.Usage? {
    payload ?: return null
    fun number(vararg keys: String): Long? = keys.firstNotNullOfOrNull { key ->
        if (!payload.has(key) || payload.isNull(key)) return@firstNotNullOfOrNull null
        when (val value = payload.opt(key)) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }
    }
    val used = number("contextTokens", "context_tokens", "tokenCount", "token_count") ?: return null
    return RunEvent.Usage(
        contextTokens = used.coerceAtLeast(0),
        contextWindow = number("contextWindow", "context_window", "contextLength", "context_length")
            ?.takeIf { it > 0 },
    )
}

/** Returns the answer persisted while this phone was temporarily offline. */
internal fun completionFromResume(payload: JSONObject): RunEvent.Done? {
    if (payload.optBoolean("isWorking", false)) return null
    val messages = payload.optJSONArray("messages") ?: return null
    var lastUserIndex = -1
    for (index in 0 until messages.length()) {
        val role = messages.optJSONObject(index)?.optString("role").orEmpty()
        if (role == "user" || role == "command") lastUserIndex = index
    }
    if (lastUserIndex < 0) return null

    for (index in messages.length() - 1 downTo lastUserIndex + 1) {
        val message = messages.optJSONObject(index) ?: continue
        if (message.optString("role") != "assistant") continue
        val output = message.optString("display_content")
            .ifBlank { message.optString("content") }
        if (output.isBlank()) continue
        return RunEvent.Done(
            output = output,
            reasoning = message.optString("reasoning"),
        )
    }
    return null
}

/** Normalizes tool payloads emitted by both current and older Studio bridges. */
internal fun parseToolEvent(
    event: JSONObject?,
    status: ToolRunStatus,
    occurredAtMillis: Long,
): RunEvent.Tool? {
    event ?: return null
    val id = event.firstString("tool_call_id", "call_id", "id")
    val name = event.firstString("tool", "name", "tool_name", "function_name")
    if (id.isBlank() && name.isBlank()) return null

    val duration = listOf("duration_seconds", "duration")
        .firstNotNullOfOrNull { key ->
            if (!event.has(key) || event.isNull(key)) return@firstNotNullOfOrNull null
            event.optDouble(key).takeIf { it.isFinite() && it >= 0.0 }
        }
    val reportedError = event.opt("error").let { value ->
        when (value) {
            is Boolean -> value
            is Number -> value.toInt() != 0
            is String -> value.isNotBlank() && !value.equals("false", ignoreCase = true)
            else -> false
        }
    }

    return RunEvent.Tool(
        id = id,
        name = name.ifBlank { "tool" },
        detail = event.toolDetail(),
        status = if (status == ToolRunStatus.Done && reportedError) ToolRunStatus.Error else status,
        durationSeconds = duration,
        occurredAtMillis = occurredAtMillis,
    )
}

private fun JSONObject?.firstString(vararg keys: String): String {
    if (this == null) return ""
    return keys.firstNotNullOfOrNull { key ->
        if (!has(key) || isNull(key)) return@firstNotNullOfOrNull null
        optString(key).trim().takeIf { it.isNotBlank() }
    }.orEmpty()
}

private fun JSONObject.toolDetail(): String? {
    firstString("preview", "detail").takeIf { it.isNotBlank() }?.let { return it.oneLine() }
    val raw = listOf("arguments", "args", "function_args")
        .firstNotNullOfOrNull { key -> opt(key).takeUnless { it == null || it == JSONObject.NULL } }
        ?: return null
    val selected = if (raw is JSONObject) {
        listOf("command", "cmd", "path", "file_path", "query", "url", "prompt")
            .firstNotNullOfOrNull { key -> raw.opt(key).takeUnless { it == null || it == JSONObject.NULL } }
            ?: raw
    } else {
        raw
    }
    return selected.toString().oneLine().takeIf { it.isNotBlank() }
}

private fun String.oneLine(): String = replace(Regex("\\s+"), " ").trim().let {
    if (it.length <= 180) it else it.take(177) + "…"
}
