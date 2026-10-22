package me.heart.wear

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.Dialog
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text

/// The second page (#464): every set of the workout, done or not. A set is a
/// way in to its editor while the phone can hear; out of reach it is only a
/// line. The twin of `WorkoutList` in ios/Watch/WorkoutView.swift.
@Composable
fun WorkoutList(workout: PhoneState.Workout, reachable: Boolean, unsynced: Set<String>, send: (Command) -> Unit) {
    val accent = Color(workout.accent)
    val controls = workout.controls?.takeIf { reachable && !LocalDimmed.current }
    var editing by remember { mutableStateOf<Pair<PhoneState.Workout.Exercise, PhoneState.Workout.Exercise.Row>?>(null) }
    // the set changed under the editor — ticked or edited on the phone — and
    // what it would save is no longer what the user saw
    LaunchedEffect(workout.exercises) { editing = null }

    val list = rememberTransformingLazyColumnState()
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
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            workout.exercises.forEach { exercise ->
                item(key = "h-${exercise.id}") {
                    Text(
                        exercise.name,
                        style = MaterialTheme.typography.titleSmall,
                        color = accent,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 4.dp),
                    )
                }
                exercise.sets.forEachIndexed { index, row ->
                    item(key = row.id) {
                        val line = @Composable { Line(index, row, exercise, workout, accent, row.id in unsynced) }
                        when (controls) {
                            // a button's own padding, for a line that is not one
                            null -> Column(Modifier.padding(horizontal = 18.dp)) { line() }
                            else -> FilledTonalButton(
                                onClick = { editing = exercise to row },
                                modifier = Modifier.fillMaxWidth(),
                            ) { line() }
                        }
                    }
                }
            }
        }
    }

    Dialog(visible = editing != null && controls != null, onDismissRequest = { editing = null }) {
        val (exercise, row) = editing ?: return@Dialog
        controls ?: return@Dialog
        SetEditor(workout.workoutId, exercise, row, controls, accent, send) { editing = null }
    }
}

/// One set as the list shows it: the phone's set column — W, 1, 2, F (#236) —
/// marked in the accent while it is up next, its values, and a tick once done.
@Composable
private fun Line(
    index: Int,
    row: PhoneState.Workout.Exercise.Row,
    exercise: PhoneState.Workout.Exercise,
    workout: PhoneState.Workout,
    accent: Color,
    /// On the watch, not yet on the phone (#465).
    unsynced: Boolean,
) {
    val mark = row.mark.ifEmpty { "${index + 1}" }
    val values = rowValues(row.weight, row.reps, exercise, workout.controls?.reps.orEmpty())
    Row(
        Modifier
            .fillMaxWidth()
            .semantics(mergeDescendants = true) {
                contentDescription = listOfNotNull(
                    row.type ?: mark,
                    values,
                    workout.controls?.done?.takeIf { row.done },
                    workout.controls?.unreachable?.takeIf { unsynced },
                ).joinToString(", ")
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            mark,
            style = MaterialTheme.typography.labelSmall,
            color = if (row.id == workout.set?.setId) accent else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.widthIn(min = 14.dp),
        )
        Text(
            values,
            style = MaterialTheme.typography.bodyMedium,
            color = if (row.done) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        if (unsynced) {
            Icon(
                painterResource(R.drawable.ic_phone),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(14.dp),
            )
        }
        if (row.done) {
            Icon(painterResource(R.drawable.ic_check), contentDescription = null, tint = accent, modifier = Modifier.size(18.dp))
        }
    }
}

/// A set gone back to from the workout page. Done, it can take new values or
/// lose its tick; not done yet, it can be done from here, as the set up next
/// would be. Every button sends and closes: the list shows what the phone
/// makes of it.
@Composable
private fun SetEditor(
    workoutId: String,
    exercise: PhoneState.Workout.Exercise,
    row: PhoneState.Workout.Exercise.Row,
    controls: PhoneState.Workout.Controls,
    accent: Color,
    send: (Command) -> Unit,
    close: () -> Unit,
) {
    var weight by remember(row) { mutableDoubleStateOf(row.weight ?: 0.0) }
    var reps by remember(row) { mutableDoubleStateOf((row.reps ?: 0).toDouble()) }
    var field by remember(row) { mutableStateOf<Field?>(null) }
    // only what the set takes: a reps-only set sends no weight
    val sentWeight = weight.takeIf { exercise.weighted }
    val sentReps = reps.toInt().takeIf { exercise.counted }
    val counts = !exercise.counted || reps >= 1

    when (field) {
        Field.Weight -> return ValueEditor(weight, exercise.step, exercise.unit.orEmpty(), accent) { weight = it }
        Field.Reps -> return ValueEditor(reps, 1.0, controls.reps, accent) { reps = it }
        null -> Unit
    }

    val list = rememberTransformingLazyColumnState()
    ScreenScaffold(scrollState = list) { padding ->
        TransformingLazyColumn(state = list, contentPadding = padding, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            item {
                Text(
                    exercise.name,
                    style = MaterialTheme.typography.titleSmall,
                    color = accent,
                    maxLines = 2,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp),
                )
            }
            if (exercise.weighted || exercise.counted) {
                item {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        if (exercise.weighted && exercise.unit != null) {
                            ValuePill(number(weight), exercise.unit, Modifier.weight(1f)) { field = Field.Weight }
                        }
                        if (exercise.counted) {
                            ValuePill(number(reps), controls.reps, Modifier.weight(1f)) { field = Field.Reps }
                        }
                    }
                }
            }
            if (row.done) {
                item {
                    Prominent(controls.save, accent, enabled = counts) {
                        if (sentWeight != row.weight || sentReps != row.reps) {
                            send(Command.Edit(workoutId, row.id, sentWeight, sentReps))
                        }
                        close()
                    }
                }
                item {
                    Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
                        FilledTonalButton(
                            onClick = {
                                send(Command.Untick(workoutId, row.id))
                                close()
                            },
                            colors = ButtonDefaults.filledTonalButtonColors(contentColor = MaterialTheme.colorScheme.error),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(controls.notDone, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                        }
                    }
                }
            } else {
                item {
                    Prominent(controls.done, accent, enabled = counts) {
                        send(Command.Complete(workoutId, row.id, sentWeight, sentReps))
                        close()
                    }
                }
            }
        }
    }
}

@Composable
private fun Prominent(label: String, accent: Color, enabled: Boolean, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
        Button(
            onClick = onClick,
            enabled = enabled,
            colors = ButtonDefaults.buttonColors(containerColor = accent, contentColor = Color.Black),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(label, Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
        }
    }
}

/// A set's values on one line, as the workout page lists them: "60 kg × 5",
/// "60 kg", "12 Reps", or nothing for a set that takes neither.
internal fun rowValues(weight: Double?, reps: Int?, exercise: PhoneState.Workout.Exercise, repsLabel: String): String {
    val w = weight?.takeIf { exercise.weighted }
    val r = reps?.takeIf { exercise.counted }
    return when {
        w != null && r != null -> "${number(w)} ${exercise.unit.orEmpty()} × $r"
        w != null -> "${number(w)} ${exercise.unit.orEmpty()}"
        r != null -> "$r $repsLabel"
        else -> ""
    }.trim()
}
