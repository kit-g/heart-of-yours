package me.heart.wear

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.File

/// What the phone sends, as `test/watch_fixtures_test.dart` writes it to
/// `test/fixtures/watch/` (#466) — the same files ios/WatchTests reads. A
/// change on the phone that this watch cannot read fails here.
class FixturesTest {
    private fun fixture(name: String) = File("../../test/fixtures/watch/$name").readText()

    @Test
    fun `a resting workout reads whole`() {
        val workout = PhoneState.from(JSONObject(fixture("workout_resting.json"))) as PhoneState.Workout
        assertEquals("w1", workout.workoutId)
        assertEquals(90_000L, workout.rest!!.end - workout.rest!!.start)
        assertEquals("b3", workout.set?.setId)
        assertEquals(62.5, workout.set?.weight)
        assertEquals(listOf("bench", "pullup"), workout.exercises.map { it.id })
        assertEquals("W", workout.exercises[0].sets[0].mark)
        assertEquals("Warm-up", workout.exercises[0].sets[0].type)
        assertNull("a reps-only exercise has no unit", workout.exercises[1].unit)
        assertNotNull("every control's copy is there", workout.controls)
        assertEquals("Reps", workout.controls?.reps)
        assertEquals(1, workout.pauses.size)
        assertEquals(workout.startedAt + 30_000, workout.clock)
    }

    @Test
    fun `a paused workout with every set ticked has nothing up next`() {
        val workout = PhoneState.from(JSONObject(fixture("workout_paused_done.json"))) as PhoneState.Workout
        assertNull(workout.set)
        assertNull(workout.rest)
        assertNotNull(workout.pausedAt)
        assertEquals("All done", workout.next)
    }

    @Test
    fun `idle and off`() {
        assertEquals(PhoneState.Idle("Start a workout on your phone"), PhoneState.from(JSONObject(fixture("idle.json"))))
        assertEquals(PhoneState.Off("Turned off in Heart on your phone"), PhoneState.from(JSONObject(fixture("off.json"))))
    }

    @Test
    fun `the commands this watch sends are the ones the phone reads`() {
        val commands = JSONArray(fixture("commands.json"))
        (0 until commands.length()).map { commands.getJSONObject(it) }.forEach { sent ->
            val command = Command.from(sent)
            assertNotNull("${sent.optString("action")} reads", command)
            // what this watch writes for it is the same command, key for key
            val written = command!!.json(sent.getString("id"), sent.getLong("at"))
            assertEquals(sent.keys().asSequence().toSet(), written.keys().asSequence().toSet())
            assertEquals(command, Command.from(written))
        }
    }
}
