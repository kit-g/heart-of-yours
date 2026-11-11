package me.heart.wear

import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnItemScope
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnScope
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Dialog
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.FilledTonalIconButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.IconButtonDefaults
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.minimumInteractiveComponentSize
import androidx.wear.compose.material3.SurfaceTransformation
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.lazy.TransformationSpec
import kotlin.math.max

/// What the set up next would be logged as: as the phone sent it until the
/// crown moves it. A new set, or the same set sent again with new values,
/// starts over.
@Stable
internal class SetDraft(set: PhoneState.Workout.UpNext) {
    var weight by mutableDoubleStateOf(set.weight ?: 0.0)
    var reps by mutableDoubleStateOf((set.reps ?: 0).toDouble())
    var editing by mutableStateOf<Field?>(null)
}

/// The next set's values and its tick (#460). The values only become the set's
/// when Done sends them. The watch moves on at once, and the phone's answer is
/// what stands. The twin of `SetControls` in ios/Watch/WorkoutView.swift.
internal fun TransformingLazyColumnScope.setControls(
    workoutId: String,
    set: PhoneState.Workout.UpNext,
    draft: SetDraft,
    controls: PhoneState.Workout.Controls,
    accent: Color,
    send: (Command) -> Unit,
    spec: TransformationSpec,
    /// Whether this set offers the stopwatch (#484).
    timed: Boolean = false,
    /// When its stopwatch started, null while it isn't running. Kept by the
    /// page: a lowered wrist takes these controls away, and not the hold.
    holding: Long? = null,
    onHold: (Long?) -> Unit = {},
    now: Long = 0,
) {
    if (set.weight != null || set.reps != null) {
        item {
            Row(line(spec), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (set.weight != null && set.unit != null) {
                    ValuePill(number(draft.weight), set.unit, Modifier.weight(1f)) { draft.editing = Field.Weight }
                }
                if (set.reps != null) {
                    ValuePill(number(draft.reps), controls.reps, Modifier.weight(1f)) { draft.editing = Field.Reps }
                }
            }
        }
    }
    set.previous?.let { previous ->
        item {
            Text(
                previous,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = line(spec),
            )
        }
    }
    val done = { seconds: Int? ->
        onHold(null)
        send(
            Command.Complete(
                workoutId = workoutId,
                setId = set.setId,
                // only what this set takes: a reps-only set sends no weight
                weight = set.weight?.let { draft.weight },
                reps = set.reps?.let { draft.reps.toInt() },
                seconds = seconds,
            ),
        )
    }
    when {
        // the hold is on: Done logs what it took, as the phone's does (#171)
        holding != null -> {
            val elapsed = (now - holding).coerceAtLeast(0)
            item {
                Text(
                    clock(elapsed, up = true),
                    style = MaterialTheme.typography.numeralSmall,
                    textAlign = TextAlign.Center,
                    modifier = line(spec),
                )
            }
            item {
                Button(
                    onClick = { done((elapsed / 1000).toInt().coerceAtLeast(1)) },
                    colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
                    transformation = SurfaceTransformation(spec),
                    modifier = button(spec),
                ) {
                    Text(controls.done, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                }
            }
            item {
                FilledTonalButton(
                    onClick = { onHold(null) },
                    transformation = SurfaceTransformation(spec),
                    modifier = button(spec),
                ) {
                    Text(controls.cancel, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                }
            }
        }
        else -> {
            if (timed) {
                item {
                    Button(
                        onClick = { onHold(System.currentTimeMillis()) },
                        colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
                        transformation = SurfaceTransformation(spec),
                        modifier = button(spec),
                    ) {
                        Text(controls.start, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                    }
                }
            }
            item {
                Button(
                    onClick = { done(null) },
                    // a counted set needs a count; the phone would refuse it anyway
                    enabled = set.reps == null || draft.reps >= 1,
                    // with a stopwatch on offer, Done is the quiet way: ticked as prescribed
                    colors = when (timed) {
                        true -> ButtonDefaults.filledTonalButtonColors()
                        false -> ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black)
                    },
                    transformation = SurfaceTransformation(spec),
                    modifier = button(spec),
                ) {
                    Text(controls.done, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                }
            }
        }
    }
}

/// The value the set's pills open.
@Composable
internal fun SetValueDialog(
    set: PhoneState.Workout.UpNext,
    draft: SetDraft,
    controls: PhoneState.Workout.Controls,
    accent: Color,
) {
    Dialog(visible = draft.editing != null, onDismissRequest = { draft.editing = null }) {
        when (draft.editing) {
            Field.Weight -> ValueEditor(
                draft.weight, set.step, set.unit.orEmpty(), accent, last = set.lastWeight, line = set.previous,
            ) { draft.weight = it }
            Field.Reps -> ValueEditor(
                draft.reps, 1.0, controls.reps, accent, last = set.lastReps?.toDouble(), line = set.previous,
            ) { draft.reps = it }
            null -> Unit
        }
    }
}

/// Which of a set's values is open in its editor.
internal enum class Field { Weight, Reps }

/// A value on a set, shown as it will be logged; tapping it opens the editor.
/// Not edited in place: on a scrolling page the rotary input would scroll the
/// page as often as it changed the number.
@Composable
internal fun ValuePill(text: String, unit: String, modifier: Modifier = Modifier, open: () -> Unit) {
    FilledTonalButton(
        onClick = open,
        // half a small watch, and a weight and "Повторы" to fit in it
        contentPadding = PaddingValues(horizontal = 6.dp),
        modifier = modifier.semantics(mergeDescendants = true) {
            contentDescription = unit
            stateDescription = text
        },
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text, style = MaterialTheme.typography.titleMedium, maxLines = 1)
            Text(
                unit,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

/// One value, full screen: − and + a step at a time, the crown or bezel for
/// bigger moves — focused from the start, with nothing else on screen to
/// scroll. Swiping it away puts it away; the set's own Done is what logs it.
///
/// [line] is last time, as the set page shows it; a tap on it sets [last],
/// this value last time (#586) — a range that starts the count at its floor
/// is often far from where it ends.
@Composable
internal fun ValueEditor(
    value: Double,
    step: Double,
    unit: String,
    accent: Color,
    last: Double? = null,
    line: String? = null,
    onChange: (Double) -> Unit,
) {
    val focus = remember { FocusRequester() }
    val haptics = LocalHapticFeedback.current
    var turned by remember { mutableFloatStateOf(0f) }
    // the value as the editor last set it, ahead of the caller's next
    // recomposition: a fast turn delivers several detents in one frame, and
    // each has to step from the one before, not from the frame's old value
    var current by remember(value) { mutableDoubleStateOf(value) }
    fun nudge(steps: Int) {
        current = max(0.0, current + steps * step)
        onChange(current)
        haptics.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick)
    }

    Column(
        Modifier
            .fillMaxSize()
            .padding(horizontal = 12.dp)
            .onRotaryScrollEvent { event ->
                // a detent's worth of turning is a step, whichever way
                turned += event.verticalScrollPixels
                val steps = (turned / DETENT).toInt()
                if (steps != 0) {
                    turned -= steps * DETENT
                    nudge(steps)
                }
                true
            }
            .focusRequester(focus)
            .focusable()
            // the buttons are hidden from TalkBack: this is the control
            .semantics(mergeDescendants = true) {
                contentDescription = unit
                stateDescription = number(current)
                progressBarRangeInfo = ProgressBarRangeInfo(current.toFloat(), 0f..MAX.toFloat())
                setProgress { target ->
                    current = target.toDouble().coerceAtLeast(0.0)
                    onChange(current)
                    true
                }
            },
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(unit, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(number(current), style = MaterialTheme.typography.displayMedium, maxLines = 1)
        // under the value, not beside it: a small watch has no room for all
        // three in a row, and a weight can run to six characters
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Stepper(R.drawable.ic_minus, accent) { nudge(-1) }
            Stepper(R.drawable.ic_plus, accent) { nudge(1) }
        }
        line?.let { line ->
            // one tap to last time's value; already there, it is only said
            val offered = last?.takeIf { it != current }
            Text(
                line,
                style = MaterialTheme.typography.bodySmall,
                color = when (offered) {
                    null -> MaterialTheme.colorScheme.onSurfaceVariant
                    else -> accent
                },
                textAlign = TextAlign.Center,
                maxLines = 2,
                // the same height either way: the steppers do not jump when the
                // value reaches last time's
                modifier = Modifier
                    .minimumInteractiveComponentSize()
                    .then(
                        offered?.let { target ->
                            Modifier.clickable(role = Role.Button) {
                                current = target
                                onChange(target)
                            }
                        } ?: Modifier,
                    ),
            )
        }
    }
    LaunchedEffect(Unit) { focus.requestFocus() }
}

@Composable
private fun Stepper(icon: Int, accent: Color, onClick: () -> Unit) {
    FilledTonalIconButton(
        onClick = onClick,
        colors = IconButtonDefaults.filledTonalIconButtonColors(contentColor = accent),
        // hidden from TalkBack: the value is the control, adjustable itself
        modifier = Modifier.clearAndSetSemantics {},
    ) {
        Icon(painterResource(icon), contentDescription = null)
    }
}

private const val DETENT = 48f
private const val MAX = 1000.0

/// Shorter, longer, or over: the three things the phone's countdown offers.
/// Skip has a row of its own: three to a row leaves too little of a small round
/// screen for "Пропустить" or "Passer" (#502).
@Composable
fun RestControls(workoutId: String, controls: PhoneState.Workout.Controls, send: (Command) -> Unit, modifier: Modifier = Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(
                controls.subtract to Command.AdjustRest(workoutId, -10),
                controls.add to Command.AdjustRest(workoutId, 10),
            ).forEach { (label, command) ->
                FilledTonalButton(onClick = { send(command) }, modifier = Modifier.weight(1f)) {
                    Text(label, Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, maxLines = 1)
                }
            }
        }
        FilledTonalButton(onClick = { send(Command.SkipRest(workoutId)) }, modifier = Modifier.fillMaxWidth()) {
            Text(controls.skip, Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, maxLines = 1)
        }
    }
}

/// Finish, once every set is ticked, behind the phone's own question: it
/// cannot be undone from the wrist. The phone does the finishing — saves,
/// writes Health, shows the summary — and this goes idle when it has.
@Composable
fun TransformingLazyColumnItemScope.FinishControl(
    workoutId: String,
    controls: PhoneState.Workout.Controls,
    accent: Color,
    send: (Command) -> Unit,
    spec: TransformationSpec,
) {
    var confirming by remember { mutableStateOf(false) }
    Button(
        onClick = { confirming = true },
        colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
        transformation = SurfaceTransformation(spec),
        modifier = button(spec),
    ) {
        Text(controls.finish, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
    }
    AlertDialog(
        visible = confirming,
        onDismissRequest = { confirming = false },
        title = { Text(controls.finishTitle) },
    ) {
        item {
            Button(
                onClick = {
                    confirming = false
                    send(Command.Finish(workoutId))
                },
                colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(controls.finishConfirm, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            }
        }
        item {
            FilledTonalButton(onClick = { confirming = false }, modifier = Modifier.fillMaxWidth()) {
                Text(controls.finishCancel, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            }
        }
    }
}

/// The way back from a pause (#134).
@Composable
fun TransformingLazyColumnItemScope.ResumeButton(
    workoutId: String,
    controls: PhoneState.Workout.Controls,
    accent: Color,
    send: (Command) -> Unit,
    spec: TransformationSpec,
) {
    Button(
        onClick = { send(Command.Resume(workoutId)) },
        icon = { Icon(painterResource(R.drawable.ic_play), contentDescription = null) },
        colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
        transformation = SurfaceTransformation(spec),
        modifier = button(spec),
    ) {
        Text(controls.resume)
    }
}

/// Stops the workout's clock (#134), offered only while pausing is on, on the phone.
@Composable
fun PauseButton(workoutId: String, controls: PhoneState.Workout.Controls, send: (Command) -> Unit) {
    FilledTonalIconButton(
        onClick = { send(Command.Pause(workoutId)) },
        modifier = Modifier.semantics { contentDescription = controls.pause },
    ) {
        Icon(painterResource(R.drawable.ic_pause), contentDescription = null)
    }
}

