package me.heart.wear

import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Dialog
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.FilledTonalIconButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.IconButtonDefaults
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import kotlin.math.max

/// The next set's values and its tick (#460). The values start as the phone
/// sent them and the rotary input moves whichever one is open; they only
/// become the set's when Done sends them. The watch moves on at once, and the
/// phone's answer is what stands. The twin of `SetControls` in
/// ios/Watch/WorkoutView.swift.
@Composable
fun SetControls(
    workoutId: String,
    set: PhoneState.Workout.UpNext,
    controls: PhoneState.Workout.Controls,
    accent: Color,
    send: (Command) -> Unit,
) {
    // a new set — or the same set sent again with new values — starts over
    var weight by remember(set) { mutableDoubleStateOf(set.weight ?: 0.0) }
    var reps by remember(set) { mutableDoubleStateOf((set.reps ?: 0).toDouble()) }
    var editing by remember(set) { mutableStateOf<Field?>(null) }

    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (set.weight != null || set.reps != null) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (set.weight != null && set.unit != null) {
                    ValuePill(number(weight), set.unit, Modifier.weight(1f)) { editing = Field.Weight }
                }
                if (set.reps != null) {
                    ValuePill(number(reps), controls.reps, Modifier.weight(1f)) { editing = Field.Reps }
                }
            }
        }
        set.previous?.let { previous ->
            Text(
                previous,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth(),
            )
        }
        Button(
            onClick = {
                send(
                    Command.Complete(
                        workoutId = workoutId,
                        setId = set.setId,
                        // only what this set takes: a reps-only set sends no weight
                        weight = set.weight?.let { weight },
                        reps = set.reps?.let { reps.toInt() },
                    ),
                )
            },
            // a counted set needs a count; the phone would refuse it anyway
            enabled = set.reps == null || reps >= 1,
            colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(controls.done, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
        }
    }

    Dialog(visible = editing != null, onDismissRequest = { editing = null }) {
        when (editing) {
            Field.Weight -> ValueEditor(weight, set.step, set.unit.orEmpty(), accent) { weight = it }
            Field.Reps -> ValueEditor(reps, 1.0, controls.reps, accent) { reps = it }
            null -> Unit
        }
    }
}

/// Which of a set's values is open in its editor.
private enum class Field { Weight, Reps }

/// A value on a set, shown as it will be logged; tapping it opens the editor.
/// Not edited in place: on a scrolling page the rotary input would scroll the
/// page as often as it changed the number.
@Composable
private fun ValuePill(text: String, unit: String, modifier: Modifier = Modifier, open: () -> Unit) {
    FilledTonalButton(
        onClick = open,
        modifier = modifier.semantics(mergeDescendants = true) {
            contentDescription = unit
            stateDescription = text
        },
    ) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(text, style = MaterialTheme.typography.titleMedium)
            Text(unit, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

/// One value, full screen: − and + a step at a time, the crown or bezel for
/// bigger moves — focused from the start, with nothing else on screen to
/// scroll. Swiping it away puts it away; the set's own Done is what logs it.
@Composable
private fun ValueEditor(value: Double, step: Double, unit: String, accent: Color, onChange: (Double) -> Unit) {
    val focus = remember { FocusRequester() }
    val haptics = LocalHapticFeedback.current
    var turned by remember { mutableFloatStateOf(0f) }
    fun nudge(steps: Int) {
        onChange(max(0.0, value + steps * step))
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
                stateDescription = number(value)
                progressBarRangeInfo = ProgressBarRangeInfo(value.toFloat(), 0f..MAX.toFloat())
                setProgress { target ->
                    onChange(target.toDouble().coerceAtLeast(0.0))
                    true
                }
            },
        verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(unit, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Stepper(R.drawable.ic_minus, accent) { nudge(-1) }
            Text(number(value), style = MaterialTheme.typography.displayMedium, maxLines = 1)
            Stepper(R.drawable.ic_plus, accent) { nudge(1) }
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
@Composable
fun RestControls(workoutId: String, controls: PhoneState.Workout.Controls, send: (Command) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf(
            controls.subtract to Command.AdjustRest(workoutId, -10),
            controls.add to Command.AdjustRest(workoutId, 10),
            controls.skip to Command.SkipRest(workoutId),
        ).forEach { (label, command) ->
            FilledTonalButton(onClick = { send(command) }, modifier = Modifier.weight(1f)) {
                Text(label, Modifier.fillMaxWidth(), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelSmall, maxLines = 1)
            }
        }
    }
}

/// Finish, once every set is ticked, behind the phone's own question: it
/// cannot be undone from the wrist. The phone does the finishing — saves,
/// writes Health, shows the summary — and this goes idle when it has.
@Composable
fun FinishControl(workoutId: String, controls: PhoneState.Workout.Controls, accent: Color, send: (Command) -> Unit) {
    var confirming by remember { mutableStateOf(false) }
    Button(
        onClick = { confirming = true },
        colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
        modifier = Modifier.fillMaxWidth(),
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

/// The workout is paused (#134): saying so, and the way back.
@Composable
fun Paused(workoutId: String, controls: PhoneState.Workout.Controls, accent: Color, send: (Command) -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        // it leads the page, where a round screen is narrowest
        Text(
            controls.paused,
            style = MaterialTheme.typography.titleMedium,
            color = accent,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        Button(
            onClick = { send(Command.Resume(workoutId)) },
            icon = { Icon(painterResource(R.drawable.ic_play), contentDescription = null) },
            colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(controls.resume)
        }
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

