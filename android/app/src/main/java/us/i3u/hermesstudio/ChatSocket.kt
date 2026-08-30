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
    data class ActionResolved(val kind: RequiredAction, val id: String, val resolved: Boolean) : RunEvent
    data class QueueChanged(val messages: List<QueuedRun>?, val insertionActive: Boolean?) : RunEvent
    data class BackgroundAgent(val task: BackgroundAgentRun) : RunEvent
    data class ResumedState(
        val pageId: String?,
        val messages: List<ResumedMessage>?,
        val model: String?,
        val provider: String?,
        val reasoningEffort: String?,
        val workspace: String?,
        val workspaceChanges: List<WorkspaceRunChange>,
    ) : RunEvent
    data class Failed(val error: String, val retryableTransport: Boolean) : RunEvent
}

enum class ToolRunStatus { Running, Done, Error }

enum class RequiredAction { Approval, Clarification }

data class ResumedMessage(
    val id: String?,
    val role: String,
    val content: String,
    val reasoning: String?,
)

data class WorkspaceRunChange(
    val id: String,
    val assistantMessageId: String?,
    val workspace: String?,
    val filesChanged: Int,
    val additions: Int,
    val deletions: Int,
)

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

    fun insertQueuedRun(sessionId: String, queueId: String) {
        socket?.emit("insert_queued_run", JSONObject().put("session_id", sessionId).put("queue_id", queueId))
    }

    fun cancelQueuedRun(sessionId: String, queueId: String) {
        socket?.emit("cancel_queued_run", JSONObject().put("session_id", sessionId).put("queue_id", queueId))
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
        cachedPageId: String? = null,
    ): Flow<RunEvent> = callbackFlow {
        val payload = JSONObject()
            .put("input", contentFor(input, attachments))
            .put("profile", profile)
            .put("session_id", sessionId)
        if (!reasoningEffort.isNullOrBlank()) payload.put("reasoning_effort", reasoningEffort)
        if (!model.isNullOrBlank()) payload.put("model", model)
        if (!provider.isNullOrBlank()) payload.put("provider", provider)
        if (!runtime.isHermes) {
            payload.put("source", if (runtime.globalAgent) "global_agent" else "coding_agent")
            if (runtime.globalAgent) payload.put("session_source", "global_agent")
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
        var resumePageId = cachedPageId

        fun eventPayload(args: Array<out Any?>): JSONObject? = args.firstOrNull() as? JSONObject

        live.on(Socket.EVENT_CONNECT) {
            if (!submitted) {
                submitted = true
                live.emit("run", payload)
            } else {
                // A mobile network can change while an agent is working. Join
                // the existing session again instead of submitting the turn a
                // second time or showing a false "disconnected" reply.
                val resume = JSONObject().put("session_id", sessionId).put("profile", profile)
                live.emit("app.resume", resume.put("id", resumePageId.orEmpty()))
            }
        }
        fun restoreSnapshot(event: JSONObject) {
            event.optString("id").takeIf(String::isNotBlank)?.let { resumePageId = it }
            trySend(parseResumedState(event))
            usageFrom(event)?.let { trySend(it) }
            trySend(RunEvent.QueueChanged(parseQueue(event), event.optJSONObject("queueInsertion") != null))
            event.optJSONArray("backgroundTasks")?.let { tasks ->
                for (index in 0 until tasks.length()) parseBackgroundTask(tasks.optJSONObject(index))?.let {
                    trySend(RunEvent.BackgroundAgent(it))
                }
            }
            event.optJSONArray("events")?.let { events ->
                for (index in 0 until events.length()) {
                    val restored = events.optJSONObject(index) ?: continue
                    val data = restored.optJSONObject("data") ?: restored
                    when (restored.optString("event")) {
                        "approval.requested" -> parseRequiredAction(data, RequiredAction.Approval)?.let { trySend(it) }
                        "clarify.requested" -> parseRequiredAction(data, RequiredAction.Clarification)?.let { trySend(it) }
                    }
                }
            }
        }
        fun handleResume(args: Array<out Any?>) {
            val event = eventPayload(args) ?: return
            restoreSnapshot(event)
            if (event.optBoolean("isWorking", false)) {
                runStarted = true
                return
            }
            if (event.optInt("queue_remaining", 0) > 0 || event.optInt("background_pending", 0) > 0) return
            terminal = true
            val completion = completionFromResume(event)
            if (completion != null) {
                trySend(completion)
            } else {
                trySend(RunEvent.Failed("run finished without output", retryableTransport = false))
            }
            close()
        }
        live.on("resumed") { args -> handleResume(args) }
        live.on("app.resumed") { args -> handleResume(args) }
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
            val event = args.firstOrNull() as? JSONObject
            usageFrom(event)?.let { trySend(it) }
            trySend(
                RunEvent.Done(
                    output = event?.optString("output").orEmpty(),
                    reasoning = event?.optString("reasoning").orEmpty(),
                ),
            )
            if ((event?.optInt("queue_remaining", 0) ?: 0) == 0 && (event?.optInt("background_pending", 0) ?: 0) == 0) {
                terminal = true
                close()
            }
        }
        live.on("run.failed") { args ->
            val event = args.firstOrNull() as? JSONObject
            val message = event?.optString("error").orEmpty()
            trySend(RunEvent.Failed(message.ifBlank { "run failed" }, retryableTransport = false))
            if ((event?.optInt("queue_remaining", 0) ?: 0) == 0 && (event?.optInt("background_pending", 0) ?: 0) == 0) {
                terminal = true
                close()
            }
        }
        // Keep the full interaction identity so the mobile decision is applied
        // to the exact interrupted run, including after a reconnect.
        live.on("approval.requested") { args ->
            val event = eventPayload(args) ?: JSONObject()
            parseRequiredAction(event, RequiredAction.Approval)?.let { trySend(it) }
        }
        live.on("clarify.requested") { args ->
            val event = eventPayload(args) ?: JSONObject()
            parseRequiredAction(event, RequiredAction.Clarification)?.let { trySend(it) }
        }
        live.on("approval.resolved") { args -> eventPayload(args)?.let { event -> trySend(RunEvent.ActionResolved(RequiredAction.Approval, event.firstString("approval_id", "id"), event.optBoolean("resolved", true))) } }
        live.on("clarify.resolved") { args -> eventPayload(args)?.let { event -> trySend(RunEvent.ActionResolved(RequiredAction.Clarification, event.firstString("clarify_id", "id"), event.optBoolean("resolved", true))) } }
        live.on("run.queued") { args -> eventPayload(args)?.let { event -> trySend(RunEvent.QueueChanged(parseQueue(event), null)) } }
        live.on("run.queue_insertion.updated") { args -> eventPayload(args)?.let { event -> trySend(RunEvent.QueueChanged(null, event.optString("phase").isNotBlank() && event.optString("phase") != "cancelled")) } }
        listOf("subagent.start", "subagent.tool", "subagent.progress", "subagent.text", "subagent.thinking", "subagent.complete", "delegation.updated").forEach { name ->
            live.on(name) { args -> eventPayload(args)?.let { event -> parseBackgroundTask(event, name.substringAfter('.'))?.let { trySend(RunEvent.BackgroundAgent(it)) } } }
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

    private fun parseRequiredAction(event: JSONObject, kind: RequiredAction): RunEvent.RequiresAction? {
        val id = if (kind == RequiredAction.Approval) event.firstString("approval_id", "id") else event.firstString("clarify_id", "id")
        if (id.isBlank()) return null
        val options = (event.optJSONArray("choices") ?: event.optJSONArray("options"))?.let { array ->
            (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
        }.orEmpty()
        val prompt = if (kind == RequiredAction.Approval) event.firstString("description", "command", "prompt", "message") else event.firstString("prompt", "question", "message")
        return RunEvent.RequiresAction(kind, id, prompt, options)
    }

    private fun parseQueue(event: JSONObject): List<QueuedRun>? {
        val array = event.optJSONArray("queued_messages") ?: event.optJSONArray("queueMessages") ?: return null
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val id = item.firstString("queue_id", "id")
            if (id.isBlank()) return@mapNotNull null
            val raw = item.opt("input")
            val preview = item.firstString("display_input", "preview").ifBlank { raw?.toString().orEmpty() }
            QueuedRun(id, preview.take(180), index + 1)
        }
    }

    private fun parseBackgroundTask(event: JSONObject?, fallbackStatus: String = ""): BackgroundAgentRun? {
        event ?: return null
        val id = event.firstString("subagent_id", "task_id", "id")
        if (id.isBlank()) return null
        return BackgroundAgentRun(
            id = id,
            runtime = event.firstString("runtime", "agent", "agent_id"),
            status = event.firstString("status", "phase").ifBlank { fallbackStatus },
            label = event.firstString("label", "name", "task", "goal", "prompt").ifBlank { id },
            output = event.firstString("output", "summary", "result", "error").takeIf(String::isNotBlank),
        )
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

internal fun parseResumedState(payload: JSONObject): RunEvent.ResumedState {
    val messages = if (payload.optBoolean("messagesCached", false)) null else payload.optJSONArray("messages")?.let { array ->
        (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val role = item.optString("display_role").ifBlank { item.optString("role") }
            val raw = item.opt("display_content").takeUnless { it == null || it == JSONObject.NULL }
                ?: item.opt("content")
            val content = when (raw) {
                is String -> raw
                is JSONArray -> (0 until raw.length()).mapNotNull { partIndex ->
                    val part = raw.optJSONObject(partIndex)
                    part?.optString("text")?.takeIf(String::isNotBlank)
                }.joinToString("\n")
                null, JSONObject.NULL -> ""
                else -> raw.toString()
            }
            if (role.isBlank() || content.isBlank()) return@mapNotNull null
            ResumedMessage(
                id = item.firstString("id", "message_id").takeIf(String::isNotBlank),
                role = role,
                content = content,
                reasoning = item.optString("reasoning").takeIf(String::isNotBlank),
            )
        }
    }
    val changes = payload.optJSONArray("workspaceRunChanges")?.let { array ->
        (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            val id = item.firstString("change_id", "id")
            if (id.isBlank()) return@mapNotNull null
            WorkspaceRunChange(
                id = id,
                assistantMessageId = item.firstString("assistant_message_id", "message_id").takeIf(String::isNotBlank),
                workspace = item.optString("workspace").takeIf(String::isNotBlank),
                filesChanged = item.optInt("files_changed"),
                additions = item.optInt("additions"),
                deletions = item.optInt("deletions"),
            )
        }
    }.orEmpty()
    return RunEvent.ResumedState(
        pageId = payload.optString("id").takeIf(String::isNotBlank),
        messages = messages,
        model = payload.optString("model").takeIf(String::isNotBlank),
        provider = payload.optString("provider").takeIf(String::isNotBlank),
        reasoningEffort = payload.firstString("reasoning_effort", "reasoningEffort").takeIf(String::isNotBlank),
        workspace = payload.optString("workspace").takeIf(String::isNotBlank),
        workspaceChanges = changes,
    )
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
