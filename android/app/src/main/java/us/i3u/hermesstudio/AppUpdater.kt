package us.i3u.hermesstudio

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File

data class AvailableUpdate(
    val commit: String,
    val downloadUrl: String,
)

enum class InstallResult { OpenedInstaller, PermissionRequired }

/** Updates the GitHub-distributed APK without involving a third-party service. */
object AppUpdater {
    private const val RELEASE_API =
        "https://api.github.com/repos/twuijri/hermes-studio-mobile/releases/tags/latest-debug"
    private const val APK_NAME = "hermes-studio-android.apk"
    private val client = OkHttpClient()

    suspend fun check(): AvailableUpdate? = withContext(Dispatchers.IO) {
        if (BuildConfig.BUILD_COMMIT == "local") return@withContext null
        val request = Request.Builder()
            .url(RELEASE_API)
            .header("Accept", "application/vnd.github+json")
            .header("User-Agent", "Hermes-Studio-Mobile/${BuildConfig.VERSION_NAME}")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) return@withContext null
            parseRelease(response.body?.string().orEmpty(), BuildConfig.BUILD_COMMIT)
        }
    }

    internal fun parseRelease(json: String, installedCommit: String): AvailableUpdate? {
        val root = runCatching { JSONObject(json) }.getOrNull() ?: return null
        val commit = Regex("(?i)[0-9a-f]{40}")
            .find(root.optString("body"))?.value?.lowercase()
            ?: return null
        val assets = root.optJSONArray("assets") ?: return null
        val url = (0 until assets.length())
            .mapNotNull { assets.optJSONObject(it) }
            .firstOrNull { it.optString("name") == APK_NAME }
            ?.optString("browser_download_url")
            ?.takeIf { it.startsWith("https://github.com/") }
            ?: return null
        return if (commit == installedCommit.lowercase()) null else AvailableUpdate(commit, url)
    }

    suspend fun download(context: Context, update: AvailableUpdate): File = withContext(Dispatchers.IO) {
        val directory = File(context.cacheDir, "updates").apply { mkdirs() }
        val destination = File(directory, APK_NAME)
        val request = Request.Builder()
            .url(update.downloadUrl)
            .header("User-Agent", "Hermes-Studio-Mobile/${BuildConfig.VERSION_NAME}")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("HTTP ${response.code}")
            val body = response.body ?: error("Empty update")
            destination.outputStream().use { output -> body.byteStream().use { it.copyTo(output) } }
        }
        if (destination.length() < 1_000_000) error("Incomplete update")
        destination
    }

    fun install(context: Context, apk: File): InstallResult {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !context.packageManager.canRequestPackageInstalls()) {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ),
            )
            return InstallResult.PermissionRequired
        }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", apk)
        context.startActivity(
            Intent(Intent.ACTION_VIEW, uri)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        return InstallResult.OpenedInstaller
    }
}
