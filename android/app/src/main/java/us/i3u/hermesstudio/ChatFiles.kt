package us.i3u.hermesstudio

import org.json.JSONArray
import java.net.URLDecoder

/** A local Studio file linked from an assistant Markdown message. */
data class ChatFileLink(
    val label: String,
    val path: String,
    val fileName: String,
)

data class ParsedChatMessage(
    val text: String,
    val files: List<ChatFileLink>,
)

private val MARKDOWN_LINK = Regex(
    """(?<!!)\[([^\]\r\n]+)]\(\s*(?:<([^>\r\n]+)>|([^\s)\r\n]+))\s*\)""",
)
private val FILES_HEADING = Regex(
    """(?im)^\s{0,3}#{1,6}\s+(?:files|attachments|downloads|الملفات|المرفقات)\s*$""",
)
private val CONVENTIONAL_EXTENSION = Regex("""\.[A-Za-z0-9]{1,12}$""")

/**
 * Pulls absolute local-file links out of Markdown so the native UI can render
 * download cards. Ordinary web links and Markdown images stay in the message.
 */
fun parseChatMessage(content: String): ParsedChatMessage {
    val contentBlocks = parseStudioContentBlocks(content)
    val visibleContent = contentBlocks?.text ?: content
    val accepted = MARKDOWN_LINK.findAll(visibleContent).mapNotNull { match ->
        val rawTarget = match.groups[2]?.value ?: match.groups[3]?.value ?: return@mapNotNull null
        val path = unwrapStudioDownloadPath(rawTarget.trim())
        if (!isStudioLocalFile(path)) return@mapNotNull null
        val label = decodeUrlPart(match.groupValues[1]).trim().ifBlank { inferDownloadFileName(path) }
        match to ChatFileLink(
            label = label,
            path = path,
            fileName = inferDownloadFileName(path, label),
        )
    }.toList()

    if (accepted.isEmpty() && contentBlocks == null) return ParsedChatMessage(content, emptyList())

    val body = buildString {
        var cursor = 0
        accepted.forEach { (match, _) ->
            append(visibleContent, cursor, match.range.first)
            cursor = match.range.last + 1
        }
        append(visibleContent, cursor, visibleContent.length)
    }
        .replace(FILES_HEADING, "")
        .replace(Regex("""\n[ \t]*\n(?:[ \t]*\n)+"""), "\n\n")
        .trim()

    val files = (contentBlocks?.files.orEmpty() + accepted.map { it.second })
        .distinctBy { it.path }
    return ParsedChatMessage(body, files)
}

/**
 * Studio stores a message carrying uploads as a JSON string of content blocks.
 * The web client turns those blocks back into attachment cards; doing the same
 * here prevents an audio note or document from appearing as raw JSON after a
 * history refresh.
 */
private fun parseStudioContentBlocks(content: String): ParsedChatMessage? {
    val trimmed = content.trim()
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return null
    val array = runCatching { JSONArray(trimmed) }.getOrNull() ?: return null
    val text = mutableListOf<String>()
    val files = mutableListOf<ChatFileLink>()
    var recognized = false

    for (index in 0 until array.length()) {
        val block = array.optJSONObject(index) ?: continue
        when (block.optString("type")) {
            "text" -> {
                recognized = true
                block.optString("text").trim().takeIf(String::isNotEmpty)?.let(text::add)
            }

            "file", "image" -> {
                recognized = true
                val path = block.optString("path").trim()
                if (path.isBlank() || !isStudioLocalFile(path)) continue
                val name = block.optString("name").trim().ifBlank { inferDownloadFileName(path) }
                files += ChatFileLink(
                    label = name,
                    path = path,
                    fileName = inferDownloadFileName(path, name),
                )
            }
        }
    }

    return if (recognized) ParsedChatMessage(text.joinToString("\n\n"), files.distinctBy { it.path }) else null
}

fun inferDownloadFileName(path: String, label: String? = null): String {
    val cleanLabel = decodeUrlPart(label.orEmpty()).trim()
    val decodedPath = decodeUrlPart(unwrapStudioDownloadPath(path))
        .substringBefore('?')
        .substringBefore('#')
    val basename = decodedPath.split('/', '\\').lastOrNull().orEmpty().trim()
    val preferred = when {
        CONVENTIONAL_EXTENSION.containsMatchIn(cleanLabel) -> cleanLabel
        CONVENTIONAL_EXTENSION.containsMatchIn(basename) -> basename
        cleanLabel.isNotBlank() -> cleanLabel
        basename.isNotBlank() -> basename
        else -> "download"
    }
    return preferred
        .split('/', '\\')
        .last()
        .replace(Regex("""[\u0000-\u001f<>:\"/\\|?*]"""), "_")
        .trim()
        .ifBlank { "download" }
}

fun unwrapStudioDownloadPath(value: String): String {
    if (!value.startsWith("/api/hermes/download?")) return decodeUrlPart(value)
    val encoded = value.substringAfter('?').split('&')
        .firstOrNull { it.substringBefore('=') == "path" }
        ?.substringAfter('=', "")
        .orEmpty()
    return if (encoded.isBlank()) decodeUrlPart(value) else decodeUrlPart(encoded)
}

private fun isStudioLocalFile(path: String): Boolean =
    path.startsWith('/') || Regex("""^[A-Za-z]:[\\/]""").containsMatchIn(path)

private fun decodeUrlPart(value: String): String = runCatching {
    URLDecoder.decode(value.replace("+", "%2B"), Charsets.UTF_8.name())
}.getOrDefault(value)
