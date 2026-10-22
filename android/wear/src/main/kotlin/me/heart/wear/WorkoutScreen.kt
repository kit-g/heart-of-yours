package me.heart.wear

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.material3.AnimatedPage
import androidx.wear.compose.material3.HorizontalPagerScaffold
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.LinearProgressIndicator
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ProgressIndicatorDefaults
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import androidx.wear.compose.ui.tooling.preview.WearPreviewDevices
import kotlinx.coroutines.delay
import android.text.format.DateFormat
import java.text.DecimalFormat
import java.util.Date
import kotlin.math.roundToInt

/// The workout in progress, as the phone summarised it (#459), in two pages.
/// The first is the set up next, read top to bottom in the order it is used —
/// the exercise and which set, its values, last time's — and at the foot where
/// the workout stands. While a rest runs its countdown leads the page; paused,
/// that leads. The second, a swipe away (#464), is the whole workout, for
/// going back to a set already done.
///
/// The clocks are instants, never counts: the countdown and the elapsed time
/// tick here, and the phone only speaks when something changes — the same
/// contract as the Apple Watch's page (ios/Watch/WorkoutView.swift).
///
/// The controls (#460) are there only while the phone can hear them; a
/// command is applied here at once, and the phone's answer replaces it.
@Composable
fun WorkoutScreen(
    workout: PhoneState.Workout,
    reachable: Boolean,
    send: (Command) -> Unit,
    waiting: Boolean = false,
    unsynced: Set<String> = emptySet(),
) {
    // absent from a phone that predates it, rather than an empty page
    if (workout.exercises.isEmpty()) return UpNextPage(workout, reachable, waiting, send)
    val pages = rememberPagerState { 2 }
    // wrist down: back to the set up next, which is what is worth a glance
    val dimmed = LocalDimmed.current
    LaunchedEffect(dimmed) {
        if (dimmed) pages.scrollToPage(0)
    }
    HorizontalPagerScaffold(pages) {
        HorizontalPager(pages) { page ->
            AnimatedPage(page, pages) {
                when (page) {
                    0 -> UpNextPage(workout, reachable, waiting, send)
                    else -> WorkoutList(workout, reachable, unsynced, send)
                }
            }
        }
    }
}

/// The first page: the set up next, and everything about the moment.
@Composable
private fun UpNextPage(workout: PhoneState.Workout, reachable: Boolean, waiting: Boolean, send: (Command) -> Unit) {
    val accent = Color(workout.accent)
    // wrist down (#462): once a minute, when the system says, and no controls
    val dimmed = LocalDimmed.current
    val ticking by ticking()
    val now = if (dimmed) LocalAmbientTick.current else ticking
    val list = rememberTransformingLazyColumnState()
    // back to the top, which is what is worth a glance: with the wrist down,
    // and when the moment moves on — a new set up next, a rest begun
    LaunchedEffect(dimmed, workout.set?.setId, workout.rest?.start) {
        list.scrollToItem(0)
    }

    // Wear's margin, a share of the screen; the round edge takes the rest
    val margin = (LocalConfiguration.current.screenWidthDp * 0.052f).dp
    ScreenScaffold(scrollState = list) { padding ->
        TransformingLazyColumn(
            state = list,
            contentPadding = PaddingValues(
                start = margin,
                end = margin,
                top = padding.calculateTopPadding(),
                bottom = padding.calculateBottomPadding(),
            ),
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            // out of reach too (#465): what is done here queues, and reaches the
            // phone when it is back
            val controls = workout.controls?.takeIf { !dimmed }
            // paused (#134), that leads, with the way back: nothing else on
            // the page moves until the clock does
            if (workout.pausedAt != null) {
                when (controls) {
                    null -> workout.controls?.let { copy ->
                        item {
                            Text(
                                copy.paused,
                                style = MaterialTheme.typography.titleMedium,
                                color = accent,
                                textAlign = TextAlign.Center,
                                modifier = Modifier.fillMaxWidth(),
                            )
                        }
                    }
                    else -> item { Paused(workout.workoutId, controls, accent, send) }
                }
            }
            workout.rest?.let { rest ->
                item { Rest(rest, now, accent) }
                if (controls != null && now < rest.end) {
                    item { RestControls(workout.workoutId, controls, send) }
                }
            }
            if (workout.exercise.isNotEmpty()) {
                item {
                    Text(
                        workout.exercise,
                        style = MaterialTheme.typography.titleMedium,
                        color = accent,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        // where a round screen is narrowest when it leads
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 28.dp),
                    )
                }
            }
            workout.set?.position?.let { position ->
                item { Muted(position) }
            }
            val set = workout.set
            when {
                controls != null && set != null -> item { SetControls(workout.workoutId, set, controls, accent, send) }
                // every set ticked: the one thing left to do
                controls != null -> item { FinishControl(workout.workoutId, controls, accent, send) }
                set != null -> {
                    values(set)?.let { values ->
                        item { Text(values, style = MaterialTheme.typography.displaySmall) }
                    }
                    set.previous?.let { previous -> item { Muted(previous) } }
                }
            }
            // the phone away, or back and still being handed what it missed
            controls?.let { copy ->
                when {
                    !reachable -> item { Away(copy.unreachable) }
                    waiting -> item { Away(copy.sending.ifEmpty { copy.unreachable }) }
                }
            }
            item { Footer(workout, now, controls, send) }
        }
    }
}

/// The rest countdown, and what it says once it has run out. The phone's next
/// state would take the rest away anyway; this covers the wait for it.
@Composable
private fun Rest(rest: PhoneState.Workout.Rest, now: Long, accent: Color) {
    if (now >= rest.end) {
        Text(
            rest.over,
            style = MaterialTheme.typography.titleMedium,
            color = accent,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        return
    }
    // dimmed, a countdown would be wrong between the minute's redraws: when
    // the rest ends is true all minute long
    if (LocalDimmed.current) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Muted(rest.label)
            Text(timeOfDay(rest.end), style = MaterialTheme.typography.numeralSmall)
        }
        return
    }
    val left = rest.end - now
    Column(
        Modifier
            .fillMaxWidth()
            // it leads the page, where a round screen is narrowest
            .padding(horizontal = 20.dp)
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
private fun Footer(workout: PhoneState.Workout, now: Long, controls: PhoneState.Workout.Controls?, send: (Command) -> Unit) {
    val until = workout.pausedAt?.takeIf { it >= workout.clock } ?: now
    Column(
        Modifier
            .fillMaxWidth()
            .padding(top = 8.dp, start = 12.dp, end = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
            Muted(workout.title, Modifier.weight(1f, fill = false))
            Muted(
                when (LocalDimmed.current) {
                    true -> minutes(until - workout.clock)
                    false -> clock(until - workout.clock, up = true)
                },
            )
        }
        workout.controls?.let { copy -> Vitals(workout.workoutId, copy) }
        // pausing is the phone's opt-in (#134): off, no control
        if (workout.pausable && workout.pausedAt == null && controls != null) {
            PauseButton(workout.workoutId, controls, send)
        }
    }
}

/// What the watch measures (#461), while it measures this workout: heart rate
/// and energy, labelled in the phone's words. What reaches Health Connect, and
/// only with the user's say, is [Readings]'s business, never this page's.
@Composable
private fun Vitals(workoutId: String, controls: PhoneState.Workout.Controls) {
    val reading by Measuring.now.collectAsStateWithLifecycle()
    val now = reading?.takeIf { it.workoutId == workoutId } ?: return
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        now.heartRate?.let { bpm ->
            val text = "${bpm.roundToInt()} ${controls.bpm}"
            Muted(text, Modifier.semantics(mergeDescendants = true) { contentDescription = "${controls.heartRate} $text" })
        }
        now.energy?.let { kcal ->
            val text = "${kcal.roundToInt()} ${controls.kcal}"
            Muted(text, Modifier.semantics(mergeDescendants = true) { contentDescription = "${controls.energy} $text" })
        }
    }
}

/// The phone out of reach, or catching up: one line, with a phone.
@Composable
private fun Away(text: String) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painterResource(R.drawable.ic_phone),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(14.dp),
        )
        Text(
            text,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
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

/// When [millis] falls, as the watch tells the time: "12:41", or "12:41 PM".
@Composable
private fun timeOfDay(millis: Long): String {
    val context = LocalContext.current
    return DateFormat.getTimeFormat(context).format(Date(millis))
}

/// "0:12", "1:05": an elapsed clock to the minute, for the dimmed page.
internal fun minutes(millis: Long): String {
    val minutes = (millis / 60_000).coerceAtLeast(0)
    return "%d:%02d".format(minutes / 60, minutes % 60)
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
            reachable = false,
            send = {},
            workout = PhoneState.Workout(
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
