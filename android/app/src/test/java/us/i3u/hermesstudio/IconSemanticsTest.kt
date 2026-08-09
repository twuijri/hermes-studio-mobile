package us.i3u.hermesstudio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/** Protects the mobile icon language from falling back to generic placeholders. */
class IconSemanticsTest {

    private val activity = File("src/main/java/us/i3u/hermesstudio/MainActivity.kt").readText()
    private val studioSettings = File("src/main/java/us/i3u/hermesstudio/StudioSettings.kt").readText()
    private val drawableDir = File("src/main/res/drawable")

    @Test
    fun everyStudioChannelHasItsOwnNamedVectorAsset() {
        val expected = listOf(
            "telegram", "discord", "slack", "whatsapp", "matrix",
            "weixin", "wecom", "feishu", "dingtalk", "qqbot",
        )
        assertEquals(expected, CHANNELS.map { it.platform })
        assertEquals("icons must not accidentally share a drawable id", CHANNELS.size, CHANNELS.map { it.iconRes }.toSet().size)

        expected.forEach { platform ->
            val file = File(drawableDir, "ic_channel_${platform}.xml")
            assertTrue("missing icon for $platform", file.isFile)
            val vector = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file).documentElement
            assertEquals("vector", vector.tagName)
            assertEquals("24", vector.getAttribute("android:viewportWidth"))
            assertEquals("24", vector.getAttribute("android:viewportHeight"))
            val path = vector.getElementsByTagName("path").item(0) as? Element
            assertNotNull("$platform vector has no path", path)
            assertTrue("$platform vector path is empty", path!!.getAttribute("android:pathData").isNotBlank())
        }
    }

    @Test
    fun channelScreensRenderBrandAssetsInsteadOfOneGenericHub() {
        val channels = activity.substringAfter("private fun ChannelsScreen")
            .substringBefore("/** One channel")
        val channel = activity.substringAfter("private fun ChannelScreen")
            .substringBefore("@Composable\ninternal fun SettingsSection")

        assertTrue(channels.contains("painterResource(spec.iconRes)"))
        assertTrue(channel.contains("painterResource(spec.iconRes)"))
        assertFalse(channels.contains("Icons.Filled.Hub"))
        assertFalse(channel.contains("Icons.Filled.Hub"))
    }

    @Test
    fun settingRowsRequireAContextualIcon() {
        assertTrue(studioSettings.contains("private fun StudioToggle(icon: ImageVector"))
        assertTrue(studioSettings.contains("private fun StudioNumber(\n    icon: ImageVector"))
        assertTrue(studioSettings.contains("private fun StudioChoice(\n    icon: ImageVector"))
        assertFalse("the old sun placeholder must not represent models", activity.contains("Icons.Filled.WbSunny"))
        assertFalse("settings must not reuse the old sun placeholder", studioSettings.contains("Icons.Filled.WbSunny"))
    }

    @Test
    fun launcherKeepsThePurpleCoreVisuallySeparated() {
        val foreground = File(drawableDir, "ic_launcher_foreground.xml").readText()
        val colors = File("src/main/res/values/colors.xml").readText()

        assertTrue("launcher needs the brand clearance ring", foreground.contains("M54,44 A10,10"))
        assertTrue("clearance must match the icon background", foreground.contains("@color/ic_launcher_background"))
        assertTrue("launcher background must match the iOS master", colors.contains("#091125"))
    }
}
