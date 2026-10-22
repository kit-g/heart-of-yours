package me.heart.wear

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme

/// The watch is always dark, on a true black ground for OLED. The neutrals are
/// Forge dark's (lib/core/theme/tokens.dart); the accent arrives with each
/// workout state, in the phone's own preset, as it does on the Apple Watch.
private val scheme = ColorScheme(
    primary = Color(0xFFD4F547),
    onPrimary = Color(0xFF121408),
    background = Color.Black,
    onBackground = Color(0xFFF1F2E9),
    onSurface = Color(0xFFF1F2E9),
    onSurfaceVariant = Color(0xFF9BA092),
    surfaceContainer = Color(0xFF191B15),
    surfaceContainerLow = Color(0xFF191B15),
    surfaceContainerHigh = Color(0xFF232720),
    outline = Color(0xFF6F746A),
    outlineVariant = Color(0xFF2A2D24),
    error = Color(0xFFFF6B57),
)

@Composable
fun HeartTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = scheme, content = content)
}
