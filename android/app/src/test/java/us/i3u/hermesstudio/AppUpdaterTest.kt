package us.i3u.hermesstudio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppUpdaterTest {
    private val installed = "1111111111111111111111111111111111111111"
    private val current = "2222222222222222222222222222222222222222"
    private val url = "https://github.com/twuijri/hermes-studio-mobile/releases/download/latest-debug/hermes-studio-android.apk"

    @Test
    fun `rolling release exposes a newer signed apk`() {
        val update = AppUpdater.parseRelease(
            """{"body":"built from `$current`","assets":[{"name":"hermes-studio-android.apk","browser_download_url":"$url"}]}""",
            installed,
        )

        assertEquals(current, update?.commit)
        assertEquals(url, update?.downloadUrl)
    }

    @Test
    fun `same build and non github downloads are rejected`() {
        val same = """{"body":"$installed","assets":[{"name":"hermes-studio-android.apk","browser_download_url":"$url"}]}"""
        val unsafe = """{"body":"$current","assets":[{"name":"hermes-studio-android.apk","browser_download_url":"https://example.com/app.apk"}]}"""

        assertNull(AppUpdater.parseRelease(same, installed))
        assertNull(AppUpdater.parseRelease(unsafe, installed))
    }
}
