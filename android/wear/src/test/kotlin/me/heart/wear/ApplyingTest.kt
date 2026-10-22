package me.heart.wear

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// What the watch shows before the phone answers: [applying], which has to
/// make the phone's moves the way the phone makes them — above all the set up
/// next, which mirrors `upNextIn` in `lib/core/utils/ongoing_workout.dart`.
/// Case for case the twin of ios/WatchTests/WatchStateTests.swift: when one
/// changes, so does the other.
class ApplyingTest {
    private val now = 1_000_000L

    private val controls = PhoneState.Workout.Controls(
        done = "Done", skip = "Skip", add = "+10s", subtract = "-10s", reps = "Reps", unreachable = "Away",
        heartRate = "", bpm = "", energy = "", kcal = "",
        finish = "Finish", finishTitle = "", finishConfirm = "", finishCancel = "",
        save = "Save", notDone = "Not done",
        restLabel = "Rest", restOver = "Over", allDone = "All done", idle = "Idle",
        sending = "", finishedAway = "Saved on your watch", pause = "", resume = "", paused = "",
    )

    // bench: 3 sets, 90s rest; row: 2 sets, no rest
    private fun workout(done: Set<String> = emptySet(), upNext: String = "b1"): PhoneState {
        fun row(id: String, number: Int, total: Int) = PhoneState.Workout.Exercise.Row(
            id = id, weight = 60.0, reps = 5, done = id in done, mark = "$number", type = null,
            position = "Set $number of $total", previous = "Last time: $id", next = "Next: $id",
        )
        return PhoneState.Workout(
            workoutId = "w", startedAt = now, title = "Push", exercise = "Bench", next = "", rest = null,
            accent = 0, set = PhoneState.Workout.UpNext("bench", upNext, 60.0, 5, "kg", 2.5, null, null),
            exercises = listOf(
                PhoneState.Workout.Exercise("bench", "Bench", "kg", 2.5, true, true, 90, listOf(row("b1", 1, 3), row("b2", 2, 3), row("b3", 3, 3))),
                PhoneState.Workout.Exercise("row", "Row", "kg", 2.5, true, true, null, listOf(row("r1", 1, 2), row("r2", 2, 2))),
            ),
            controls = controls, activity = null, clockStart = null, pausedAt = null, pausable = true, pauses = emptyList(),
        )
    }

    private fun shown(state: PhoneState) = state as PhoneState.Workout

    private fun complete(setId: String, weight: Double? = null, reps: Int? = null) = Command.Complete("w", setId, weight, reps)

    @Test
    fun `a tick moves to the next open set in the same exercise`() {
        val after = shown(workout().applying(complete("b1", 62.5, 6), now, now))
        assertEquals("b2", after.set?.setId)
        assertEquals("Set 2 of 3", after.set?.position)
        assertEquals("Last time: b2", after.set?.previous)
        assertEquals("Next: b2", after.next)
        val ticked = after.exercises[0].sets[0]
        assertEquals(62.5, ticked.weight)
        assertEquals(6, ticked.reps)
        assertTrue(ticked.done)
    }

    @Test
    fun `the last set of an exercise moves to the next exercise's first open set`() {
        val after = shown(workout(setOf("b1", "b2", "r1"), "b3").applying(complete("b3"), now, now))
        assertEquals("r2", after.set?.setId)
        assertEquals("Row", after.exercise)
    }

    @Test
    fun `nothing open afterwards wraps to a set skipped earlier`() {
        val after = shown(workout(setOf("b2", "b3", "r1"), "r2").applying(complete("r2"), now, now))
        assertEquals("b1", after.set?.setId)
    }

    @Test
    fun `the last open set leaves nothing up next`() {
        val after = shown(workout(setOf("b1", "b2", "b3", "r1"), "r2").applying(complete("r2"), now, now))
        assertNull(after.set)
        assertEquals("Row", after.exercise)
        assertEquals("All done", after.next)
    }

    @Test
    fun `a tick starts the exercise's rest`() {
        val after = shown(workout().applying(complete("b1"), now, now))
        assertEquals(PhoneState.Workout.Rest(now, now + 90_000, "Rest", "Over"), after.rest)
    }

    @Test
    fun `a tick older than its rest starts none`() {
        assertNull(shown(workout().applying(complete("b1"), now - 300_000, now)).rest)
    }

    @Test
    fun `a set ticked already is not ticked again`() {
        val state = workout(setOf("b1"), "b2")
        assertEquals(state, state.applying(complete("b1", 99.0, 9), now, now))
    }

    @Test
    fun `an edit keeps the tick and what is up next`() {
        val after = shown(workout(setOf("b1"), "b2").applying(Command.Edit("w", "b1", null, 8), now, now))
        assertEquals(8, after.exercises[0].sets[0].reps)
        assertEquals(60.0, after.exercises[0].sets[0].weight)
        assertTrue(after.exercises[0].sets[0].done)
        assertEquals("b2", after.set?.setId)
    }

    @Test
    fun `an untick keeps what is up next`() {
        val after = shown(workout(setOf("b1"), "b2").applying(Command.Untick("w", "b1"), now, now))
        assertFalse(after.exercises[0].sets[0].done)
        assertEquals("b2", after.set?.setId)
    }

    @Test
    fun `rest is adjusted and skipped`() {
        val resting = workout().applying(complete("b1"), now, now)
        assertEquals(now + 100_000, shown(resting.applying(Command.AdjustRest("w", 10), now, now)).rest?.end)
        assertNull(shown(resting.applying(Command.AdjustRest("w", -120), now, now)).rest)
        assertNull(shown(resting.applying(Command.SkipRest("w"), now, now)).rest)
    }

    @Test
    fun `pausing skips the rest, and a tick while paused resumes at the tick`() {
        val paused = shown(workout().applying(complete("b1"), now, now).applying(Command.Pause("w"), now + 1_000, now))
        assertEquals(now + 1_000, paused.pausedAt)
        assertNull(paused.rest)
        val resumed = shown(paused.applying(complete("b2"), now + 31_000, now + 31_000))
        assertNull(resumed.pausedAt)
        assertEquals(now + 30_000, resumed.clock)
        assertEquals(listOf((now + 1_000)..(now + 31_000)), resumed.pauses)
    }

    @Test
    fun `finish says the workout is safe, not that there is none`() {
        assertEquals(PhoneState.Idle("Saved on your watch"), workout().applying(Command.Finish("w"), now, now))
    }

    @Test
    fun `a command about another workout changes nothing`() {
        val state = workout()
        assertEquals(state, state.applying(Command.Complete("other", "b1", null, null), now, now))
    }

    @Test
    fun `a command reads on the phone as WatchCommand_fromMap expects, and back`() {
        val json = complete("b1", 62.5, 6).json("id-1", now)
        assertEquals(
            mapOf("event" to "command", "action" to "complete", "workoutId" to "w", "setId" to "b1", "weight" to 62.5, "reps" to 6, "id" to "id-1", "at" to now),
            json.toMap(),
        )
        assertFalse("a set without weight sends none", complete("b1", reps = 5).json("id", now).has("weight"))
        listOf(
            complete("b1", 62.5, 6), complete("b1"), Command.Edit("w", "b1", null, 8), Command.Untick("w", "b1"),
            Command.SkipRest("w"), Command.AdjustRest("w", -10), Command.Finish("w"), Command.Pause("w"), Command.Resume("w"),
        ).forEach { command ->
            assertEquals(command, Command.from(command.json("id", now)))
        }
    }
}

private fun JSONObject.toMap(): Map<String, Any?> = keys().asSequence().associateWith { get(it) }
