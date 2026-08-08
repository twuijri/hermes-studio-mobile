package us.i3u.hermesstudio

import androidx.compose.ui.text.font.FontWeight
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatMarkdownTest {
    @Test
    fun `studio headings and lists become native blocks`() {
        val blocks = parseChatMarkdown(
            """
            ### البريد غير المقروء
            - **635** عاجلة وتتطلب إجراء.
              - طلبات معلومات.

            1. **تنظيف البريد**
            """.trimIndent(),
        )

        assertEquals(ChatMarkdownBlock.Heading(3, "البريد غير المقروء"), blocks[0])
        assertEquals(ChatMarkdownBlock.Unordered(0, "**635** عاجلة وتتطلب إجراء."), blocks[1])
        assertEquals(ChatMarkdownBlock.Unordered(1, "طلبات معلومات."), blocks[2])
        assertEquals(ChatMarkdownBlock.Ordered(0, "1.", "**تنظيف البريد**"), blocks[3])
    }

    @Test
    fun `inline bold hides markdown markers and keeps bold span`() {
        val rendered = chatMarkdownInline("تنبيه **مهم** الآن")

        assertEquals("تنبيه مهم الآن", rendered.text)
        assertFalse(rendered.text.contains("**"))
        assertTrue(rendered.spanStyles.any { it.item.fontWeight == FontWeight.Bold })
    }
}
