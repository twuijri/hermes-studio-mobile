package us.i3u.hermesstudio

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal sealed interface ChatMarkdownBlock {
    val text: String

    data class Paragraph(override val text: String) : ChatMarkdownBlock
    data class Heading(val level: Int, override val text: String) : ChatMarkdownBlock
    data class Unordered(val indent: Int, override val text: String) : ChatMarkdownBlock
    data class Ordered(val indent: Int, val marker: String, override val text: String) : ChatMarkdownBlock
    data class Quote(override val text: String) : ChatMarkdownBlock
    data class Code(override val text: String) : ChatMarkdownBlock
}

internal fun parseChatMarkdown(source: String): List<ChatMarkdownBlock> {
    val lines = source.replace("\r\n", "\n").replace('\r', '\n').split('\n')
    val blocks = mutableListOf<ChatMarkdownBlock>()
    val paragraph = mutableListOf<String>()
    val code = mutableListOf<String>()
    var inFence = false

    fun flushParagraph() {
        if (paragraph.isNotEmpty()) {
            blocks += ChatMarkdownBlock.Paragraph(paragraph.joinToString("\n"))
            paragraph.clear()
        }
    }
    fun flushCode() {
        if (code.isNotEmpty()) {
            blocks += ChatMarkdownBlock.Code(code.joinToString("\n"))
            code.clear()
        }
    }

    lines.forEach { raw ->
        val trimmed = raw.trim()
        if (trimmed.startsWith("```") || trimmed.startsWith("~~~")) {
            flushParagraph()
            if (inFence) flushCode()
            inFence = !inFence
            return@forEach
        }
        if (inFence) {
            code += raw
            return@forEach
        }
        if (trimmed.isEmpty()) {
            flushParagraph()
            return@forEach
        }

        parseHeading(trimmed)?.let {
            flushParagraph()
            blocks += it
            return@forEach
        }
        parseUnordered(raw)?.let {
            flushParagraph()
            blocks += it
            return@forEach
        }
        parseOrdered(raw)?.let {
            flushParagraph()
            blocks += it
            return@forEach
        }
        if (trimmed.startsWith("> ")) {
            flushParagraph()
            blocks += ChatMarkdownBlock.Quote(trimmed.drop(2))
            return@forEach
        }
        paragraph += trimmed
    }
    flushParagraph()
    flushCode()
    return blocks
}

private fun parseHeading(line: String): ChatMarkdownBlock.Heading? {
    val level = line.takeWhile { it == '#' }.length
    if (level !in 1..6 || line.getOrNull(level) != ' ') return null
    return ChatMarkdownBlock.Heading(level, line.drop(level + 1))
}

private fun parseUnordered(line: String): ChatMarkdownBlock.Unordered? {
    val prefix = line.takeWhile { it == ' ' || it == '\t' }
    val value = line.drop(prefix.length)
    if (value.length < 2 || value[0] !in charArrayOf('-', '*', '+', '•', '◦') || value[1] != ' ') return null
    val spaces = prefix.fold(0) { total, char -> total + if (char == '\t') 2 else 1 }
    return ChatMarkdownBlock.Unordered(spaces / 2, value.drop(2))
}

private fun parseOrdered(line: String): ChatMarkdownBlock.Ordered? {
    val prefix = line.takeWhile { it == ' ' || it == '\t' }
    val value = line.drop(prefix.length)
    val digits = value.takeWhile(Char::isDigit)
    val punctuation = value.getOrNull(digits.length)
    if (digits.isEmpty() || punctuation == null || punctuation !in charArrayOf('.', ')')) return null
    if (value.getOrNull(digits.length + 1) != ' ') return null
    val spaces = prefix.fold(0) { total, char -> total + if (char == '\t') 2 else 1 }
    return ChatMarkdownBlock.Ordered(spaces / 2, "$digits$punctuation", value.drop(digits.length + 2))
}

internal fun chatMarkdownInline(
    source: String,
    linkColor: Color = Color.Unspecified,
    codeBackground: Color = Color.Transparent,
): AnnotatedString = buildAnnotatedString {
    appendMarkdown(source, 0, source.length, linkColor, codeBackground)
}

private fun AnnotatedString.Builder.appendMarkdown(
    source: String,
    start: Int,
    end: Int,
    linkColor: Color,
    codeBackground: Color,
) {
    var index = start
    while (index < end) {
        when {
            source[index] == '\\' && index + 1 < end -> {
                append(source[index + 1])
                index += 2
            }
            source.startsWith("**", index) || source.startsWith("__", index) -> {
                val delimiter = source.substring(index, index + 2)
                val close = source.indexOf(delimiter, index + 2).takeIf { it in (index + 2)..<end }
                if (close != null) {
                    pushStyle(SpanStyle(fontWeight = FontWeight.Bold))
                    appendMarkdown(source, index + 2, close, linkColor, codeBackground)
                    pop()
                    index = close + 2
                } else {
                    append(delimiter)
                    index += 2
                }
            }
            source[index] == '`' -> {
                val close = source.indexOf('`', index + 1).takeIf { it in (index + 1)..<end }
                if (close != null) {
                    pushStyle(SpanStyle(fontFamily = FontFamily.Monospace, background = codeBackground))
                    append(source.substring(index + 1, close))
                    pop()
                    index = close + 1
                } else {
                    append('`')
                    index++
                }
            }
            source[index] == '[' -> {
                val labelEnd = source.indexOf(']', index + 1)
                val urlStart = labelEnd + 1
                val urlEnd = if (labelEnd in (index + 1)..<end && source.getOrNull(urlStart) == '(') {
                    source.indexOf(')', urlStart + 1)
                } else -1
                if (urlEnd in (urlStart + 1)..<end) {
                    val url = source.substring(urlStart + 1, urlEnd)
                    pushStringAnnotation("URL", url)
                    pushStyle(SpanStyle(color = linkColor, textDecoration = TextDecoration.Underline))
                    appendMarkdown(source, index + 1, labelEnd, linkColor, codeBackground)
                    pop()
                    pop()
                    index = urlEnd + 1
                } else {
                    append('[')
                    index++
                }
            }
            source[index] == '*' || source[index] == '_' -> {
                val delimiter = source[index]
                val close = source.indexOf(delimiter, index + 1).takeIf { it in (index + 1)..<end }
                if (close != null) {
                    pushStyle(SpanStyle(fontStyle = FontStyle.Italic))
                    appendMarkdown(source, index + 1, close, linkColor, codeBackground)
                    pop()
                    index = close + 1
                } else {
                    append(delimiter)
                    index++
                }
            }
            else -> {
                append(source[index])
                index++
            }
        }
    }
}

internal fun chatTextDirection(text: String): TextDirection {
    text.forEach { char ->
        when (Character.getDirectionality(char)) {
            Character.DIRECTIONALITY_RIGHT_TO_LEFT,
            Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC,
            Character.DIRECTIONALITY_RIGHT_TO_LEFT_EMBEDDING,
            Character.DIRECTIONALITY_RIGHT_TO_LEFT_OVERRIDE,
            -> return TextDirection.Rtl
            Character.DIRECTIONALITY_LEFT_TO_RIGHT,
            Character.DIRECTIONALITY_LEFT_TO_RIGHT_EMBEDDING,
            Character.DIRECTIONALITY_LEFT_TO_RIGHT_OVERRIDE,
            -> return TextDirection.Ltr
        }
    }
    return TextDirection.Content
}

@Composable
internal fun ChatMarkdownText(text: String, modifier: Modifier = Modifier) {
    val linkColor = MaterialTheme.colorScheme.primary
    val codeBackground = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        parseChatMarkdown(text).forEach { block ->
            when (block) {
                is ChatMarkdownBlock.Heading -> MarkdownLine(
                    block.text,
                    modifier = Modifier.padding(top = 10.dp, bottom = 2.dp),
                    fontWeight = FontWeight.Bold,
                    style = when (block.level) {
                        1 -> MaterialTheme.typography.headlineSmall
                        2 -> MaterialTheme.typography.titleLarge
                        3 -> MaterialTheme.typography.titleMedium.copy(fontSize = 19.sp, lineHeight = 26.sp)
                        4 -> MaterialTheme.typography.titleMedium
                        else -> MaterialTheme.typography.titleSmall
                    },
                )
                is ChatMarkdownBlock.Unordered -> MarkdownListRow("◦", block.text, block.indent, subtleMarker = true)
                is ChatMarkdownBlock.Ordered -> MarkdownListRow(block.marker, block.text, block.indent, subtleMarker = false)
                is ChatMarkdownBlock.Quote -> MarkdownLine(
                    block.text,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.055f))
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                )
                is ChatMarkdownBlock.Code -> MarkdownLine(
                    block.text,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f))
                        .padding(9.dp),
                    monospace = true,
                )
                is ChatMarkdownBlock.Paragraph -> MarkdownLine(block.text)
            }
        }
    }
}

@Composable
private fun MarkdownLine(
    text: String,
    modifier: Modifier = Modifier,
    fontWeight: FontWeight? = null,
    style: androidx.compose.ui.text.TextStyle = MaterialTheme.typography.bodyLarge,
    monospace: Boolean = false,
) {
    val direction = chatTextDirection(text)
    Text(
        text = chatMarkdownInline(
            text,
            linkColor = MaterialTheme.colorScheme.primary,
            codeBackground = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f),
        ),
        modifier = modifier.fillMaxWidth(),
        style = style.copy(
            textDirection = direction,
            fontFamily = if (monospace) FontFamily.Monospace else style.fontFamily,
        ),
        fontWeight = fontWeight,
        textAlign = if (direction == TextDirection.Rtl) TextAlign.Right else TextAlign.Left,
    )
}

@Composable
private fun MarkdownListRow(marker: String, text: String, indent: Int, subtleMarker: Boolean) {
    val direction = chatTextDirection(text)
    // A local physical-LTR row keeps the marker on the real right for Arabic;
    // the text itself still uses the correct Unicode paragraph direction.
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = if (direction == TextDirection.Rtl) 0.dp else (indent * 16).dp,
                    end = if (direction == TextDirection.Rtl) (indent * 16).dp else 0.dp,
                ),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            if (direction == TextDirection.Rtl) {
                MarkdownLine(text, modifier = Modifier.weight(1f))
                MarkdownMarker(marker, subtleMarker)
            } else {
                MarkdownMarker(marker, subtleMarker)
                MarkdownLine(text, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun MarkdownMarker(marker: String, subtle: Boolean) {
    Text(
        marker,
        color = if (subtle) MaterialTheme.colorScheme.onSurfaceVariant else Color.Unspecified,
        style = if (subtle) MaterialTheme.typography.labelMedium else MaterialTheme.typography.bodyLarge,
        fontWeight = FontWeight.SemiBold,
    )
}
