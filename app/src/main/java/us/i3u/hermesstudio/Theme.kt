package us.i3u.hermesstudio

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/** Shared dark palette: visually aligned with iPhone while using Material roles. */
private val StudioColors = darkColorScheme(
    primary = Color(0xFF7A5CFF),
    onPrimary = Color.White,
    primaryContainer = Color(0xFF34286F),
    onPrimaryContainer = Color(0xFFE9E2FF),
    secondary = Color(0xFFB9B1D0),
    onSecondary = Color(0xFF211A2F),
    secondaryContainer = Color(0xFF302A3C),
    onSecondaryContainer = Color(0xFFE8E0F8),
    tertiary = Color(0xFF62D2E8),
    background = Color(0xFF0D0D12),
    onBackground = Color(0xFFF5F3FA),
    surface = Color(0xFF0D0D12),
    onSurface = Color(0xFFF5F3FA),
    surfaceVariant = Color(0xFF232329),
    onSurfaceVariant = Color(0xFFA7A3AF),
    surfaceContainerLowest = Color(0xFF09090D),
    surfaceContainerLow = Color(0xFF151519),
    surfaceContainer = Color(0xFF1C1C21),
    surfaceContainerHigh = Color(0xFF232329),
    surfaceContainerHighest = Color(0xFF2B2B32),
    outline = Color(0xFF383840),
    outlineVariant = Color(0xFF2B2B32),
    error = Color(0xFFFF8A91),
    errorContainer = Color(0xFF5A2027),
    onErrorContainer = Color(0xFFFFD9DC),
)

private val StudioShapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(18.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(30.dp),
)

private val StudioTypography = Typography(
    displaySmall = Typography().displaySmall.copy(fontSize = 36.sp, lineHeight = 42.sp, fontWeight = FontWeight.Bold),
    headlineMedium = Typography().headlineMedium.copy(fontSize = 30.sp, lineHeight = 36.sp, fontWeight = FontWeight.Bold),
    titleLarge = Typography().titleLarge.copy(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.SemiBold),
    titleMedium = Typography().titleMedium.copy(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = Typography().bodyLarge.copy(fontSize = 17.sp, lineHeight = 24.sp),
    bodyMedium = Typography().bodyMedium.copy(fontSize = 15.sp, lineHeight = 21.sp),
)

@Composable
fun HermesTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = StudioColors,
        typography = StudioTypography,
        shapes = StudioShapes,
        content = content,
    )
}

/** Studio shows a short clock for today and a date for older rows. */
fun formatStamp(raw: String?): String {
    if (raw.isNullOrBlank()) return ""
    val millis = raw.toLongOrNull()
    if (millis != null) {
        val normalized = if (millis < 100_000_000_000L) millis * 1000 else millis
        val now = java.util.Calendar.getInstance()
        val then = java.util.Calendar.getInstance().apply { timeInMillis = normalized }
        val sameDay = now.get(java.util.Calendar.ERA) == then.get(java.util.Calendar.ERA) &&
            now.get(java.util.Calendar.YEAR) == then.get(java.util.Calendar.YEAR) &&
            now.get(java.util.Calendar.DAY_OF_YEAR) == then.get(java.util.Calendar.DAY_OF_YEAR)
        return android.text.format.DateFormat.format(if (sameDay) "h:mm a" else "yyyy-MM-dd", normalized).toString()
    }
    // ISO 8601: keep the clock when the day is today, otherwise the date.
    val date = raw.take(10)
    val time = raw.drop(11).take(5)
    val today = android.text.format.DateFormat.format("yyyy-MM-dd", System.currentTimeMillis()).toString()
    return if (date == today && time.isNotBlank()) time else date
}
