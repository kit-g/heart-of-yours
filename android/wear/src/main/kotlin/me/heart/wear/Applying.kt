package me.heart.wear

/// The phone's last state with what the user did since, before the phone has
/// answered: the same moves the phone would make, so the watch carries on as
/// if it had. The phone is still the only writer — this is only what to show
/// until its answer comes back, and its answer replaces it. The twin of
/// `WatchState.applying` in ios/Watch/WatchState.swift.
fun PhoneState.applying(command: Command, at: Long, now: Long = System.currentTimeMillis()): PhoneState {
    val workout = this as? PhoneState.Workout ?: return this
    if (workout.workoutId != command.workoutId) return this

    return when (command) {
        is Command.Complete -> {
            val (e, r) = workout.locate(command.setId) ?: return this
            val row = workout.exercises[e].sets[r]
            // ticked already: the phone ignores it, and so does this
            if (row.done) return this
            val ticked = workout.withRow(e, r, row.copy(weight = command.weight ?: row.weight, reps = command.reps ?: row.reps, done = true))
                // a tick is getting back to work: paused, the clock runs again
                .resumed(at)
                .movedOn(e, r)
            // the rest the tick starts, as the phone would start it — gone
            // already if the tick is older than the rest
            val seconds = ticked.exercises[e].rest
            val controls = ticked.controls
            if (seconds != null && seconds > 0 && controls != null) {
                val end = at + seconds * 1000L
                ticked.copy(rest = if (end > now) PhoneState.Workout.Rest(at, end, controls.restLabel, controls.restOver) else null)
            } else {
                ticked
            }
        }
        is Command.Edit -> {
            val (e, r) = workout.locate(command.setId) ?: return this
            val row = workout.exercises[e].sets[r]
            workout.withRow(e, r, row.copy(weight = command.weight ?: row.weight, reps = command.reps ?: row.reps))
        }
        is Command.Untick -> {
            // the phone keeps the set up next where it is, and so does this
            val (e, r) = workout.locate(command.setId) ?: return this
            workout.withRow(e, r, workout.exercises[e].sets[r].copy(done = false))
        }
        is Command.SkipRest -> workout.copy(rest = null)
        // pausing skips the rest, as on the phone
        is Command.Pause -> if (workout.pausedAt == null) workout.copy(pausedAt = at, rest = null) else workout
        is Command.Resume -> workout.resumed(at)
        is Command.AdjustRest -> {
            val rest = workout.rest ?: return workout
            val end = rest.end + command.seconds * 1000L
            workout.copy(rest = if (end > maxOf(rest.start, now)) rest.copy(end = end) else null)
        }
        // finished here, with the phone away: say the workout is safe, not that
        // there is none — the phone's own idle line replaces it once it has saved it
        is Command.Finish -> PhoneState.Idle(workout.controls?.let { it.finishedAway.ifEmpty { it.idle } } ?: "")
    }
}

/// Ends the pause, if there is one and [at] comes after it, by the phone's rule
/// (`Workouts.resume`): the clock moves on by the time it stood still.
private fun PhoneState.Workout.resumed(at: Long): PhoneState.Workout {
    val pausedAt = pausedAt ?: return this
    if (at <= pausedAt) return this
    return copy(clockStart = clock + (at - pausedAt), pauses = pauses + listOf(pausedAt..at), pausedAt = null)
}

/// Where [setId] is: its exercise's index and its own.
private fun PhoneState.Workout.locate(setId: String): Pair<Int, Int>? {
    exercises.forEachIndexed { e, exercise ->
        val r = exercise.sets.indexOfFirst { it.id == setId }
        if (r >= 0) return e to r
    }
    return null
}

private fun PhoneState.Workout.withRow(e: Int, r: Int, row: PhoneState.Workout.Exercise.Row): PhoneState.Workout {
    val exercise = exercises[e]
    val sets = exercise.sets.toMutableList().also { it[r] = row }
    return copy(exercises = exercises.toMutableList().also { it[e] = exercise.copy(sets = sets) })
}

/// The set up next once the set at ([e], [r]) is done, by the phone's rule
/// (`upNextIn` in `lib/core/utils/ongoing_workout.dart`): the next open set in
/// the same exercise, else the first open set of a later one, else the first
/// open set anywhere. Nothing open: every set is ticked.
private fun PhoneState.Workout.movedOn(e: Int, r: Int): PhoneState.Workout {
    fun open(e: Int, from: Int = 0): Pair<Int, Int>? {
        val sets = exercises[e].sets
        return (from until sets.size).firstOrNull { !sets[it].done }?.let { e to it }
    }

    val upcoming = open(e, from = r + 1)
        ?: (e + 1 until exercises.size).firstNotNullOfOrNull { open(it) }
        ?: exercises.indices.firstNotNullOfOrNull { open(it) }
        ?: return copy(set = null, exercise = exercises[e].name, next = controls?.allDone ?: "")

    val (ne, nr) = upcoming
    val target = exercises[ne]
    val row = target.sets[nr]
    return copy(
        exercise = target.name,
        next = row.next,
        set = PhoneState.Workout.UpNext(
            exerciseId = target.id,
            setId = row.id,
            weight = row.weight,
            reps = row.reps,
            unit = target.unit,
            step = target.step,
            previous = row.previous,
            position = row.position,
        ),
    )
}
