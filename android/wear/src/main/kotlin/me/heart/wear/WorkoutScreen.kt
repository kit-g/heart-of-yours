package me.heart.wear

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.LinearProgressIndicator
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ProgressIndicatorDefaults
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.ui.tooling.preview.WearPreviewDevices
import kotlinx.coroutines.delay
import java.text.DecimalFormat

/// The workout in progress, as the phone summarised it (#459): the set up
/// next, read top to bottom in the order it is used — the exercise and which
/// set, its values, last time's — and at the foot where the workout stands.
/// While a rest runs its countdown leads the page; paused, that leads.
///
/// The clocks are instants, never counts: the countdown and the elapsed time
/// tick here, and the phone only speaks when something changes — the same
/// contract as the Apple Watch's page (ios/Watch/WorkoutView.swift).
@Composable
fun WorkoutScreen(workout: PhoneState.Workout) {
    val accent = Color(workout.accent)
    val now by ticking()
    val list = rememberScalingLazyListState()

    ScreenScaffold(scrollState = list) { padding ->
        ScalingLazyColumn(
            state = list,
            contentPadding = padding,
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            val controls = workout.controls
            if (workout.pausedAt != null && controls != null) {
                item { Text(controls.paused, style = MaterialTheme.typography.titleMedium, color = accent) }
            }
            workout.rest?.let { rest ->
                item { Rest(rest, now, accent) }
            }
            if (workout.exercise.isNotEmpty()) {
                item {
                    Text(
                        workout.exercise,
                        style = MaterialTheme.typography.titleMedium,
                        color = accent,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            workout.set?.position?.let { position ->
                item { Muted(position) }
            }
            workout.set?.let { set ->
                values(set)?.let { values ->
                    item { Text(values, style = MaterialTheme.typography.displaySmall) }
                }
                set.previous?.let { previous -> item { Muted(previous) } }
            }
            item { Footer(workout, now) }
        }
    }
}

/// The rest countdown, and what it says once it has run out. The phone's next
/// state would take the rest away anyway; this covers the wait for it.
@Composable
private fun Rest(rest: PhoneState.Workout.Rest, now: Long, accent: Color) {
    if (now >= rest.end) {
        Text(rest.over, style = MaterialTheme.typography.titleMedium, color = accent)
        return
    }
    val left = rest.end - now
    Column(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .clearAndSetSemantics { contentDescription = "${rest.label} ${clock(left, up = false)}" },
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Muted(rest.label)
            Text(clock(left, up = false), style = MaterialTheme.typography.numeralSmall)
        }
        LinearProgressIndicator(
            progress = { (left.toFloat() / (rest.end - rest.start)).coerceIn(0f, 1f) },
            colors = ProgressIndicatorDefaults.colors(indicatorColor = accent),
        )
    }
}

/// Where the workout stands: its name, and how long it has run — or where it
/// stood when it was paused.
@Composable
private fun Footer(workout: PhoneState.Workout, now: Long) {
    val until = workout.pausedAt?.takeIf { it >= workout.clock } ?: now
    Row(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, start = 12.dp, end = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
    ) {
        Muted(workout.title, Modifier.weight(1f, fill = false))
        Muted(clock(until - workout.clock, up = true))
    }
}

@Composable
private fun Muted(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
    )
}

/// The clock, read once a second, on the second.
@Composable
private fun ticking() = produceState(System.currentTimeMillis()) {
    while (true) {
        value = System.currentTimeMillis()
        delay(1000 - value % 1000)
    }
}

/// "60 kg × 5", "× 12", "60 kg": the set's values as the phone shows them,
/// null for a set that counts neither.
internal fun values(set: PhoneState.Workout.UpNext): String? {
    val weight = set.weight?.let { listOfNotNull(number(it), set.unit).joinToString(" ") }
    return when {
        weight != null && set.reps != null -> "$weight × ${set.reps}"
        weight != null -> weight
        set.reps != null -> "× ${set.reps}"
        else -> null
    }
}

/// A weight as the phone writes one: no trailing zeros, the locale's decimal mark.
internal fun number(value: Double): String = DecimalFormat("#.##").format(value)

/// "1:05", or "1:02:03" past the hour. The countdown rounds up, so it reads
/// 0:01 in its last second rather than 0:00.
internal fun clock(millis: Long, up: Boolean): String {
    val seconds = when (up) {
        true -> millis / 1000
        false -> (millis + 999) / 1000
    }.coerceAtLeast(0)
    val (h, m, s) = Triple(seconds / 3600, seconds / 60 % 60, seconds % 60)
    return when (h) {
        0L -> "%d:%02d".format(m, s)
        else -> "%d:%02d:%02d".format(h, m, s)
    }
}

@WearPreviewDevices
@Composable
private fun WorkoutPreview() {
    val now = System.currentTimeMillis()
    HeartTheme {
        WorkoutScreen(
            PhoneState.Workout(
                workoutId = "w",
                startedAt = now - 754_000,
                title = "Push day",
                exercise = "Bench Press (Barbell)",
                next = "Next: 60 kg × 5",
                rest = PhoneState.Workout.Rest(now - 30_000, now + 60_000, "Rest", "Rest's up"),
                accent = 0xFFD4F547.toInt(),
                set = PhoneState.Workout.UpNext("e", "s", 60.0, 5, "kg", 2.5, "Last time: 57.5 kg × 5", "Set 2 of 3"),
                exercises = emptyList(),
                controls = null,
                activity = null,
                clockStart = null,
                pausedAt = null,
                pausable = false,
                pauses = emptyList(),
            ),
        )
    }
}
