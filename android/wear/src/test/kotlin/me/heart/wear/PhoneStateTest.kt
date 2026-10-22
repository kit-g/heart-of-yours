package me.heart.wear

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// The phone's state as `lib/core/env/watch.dart` sends it, decoded as
/// ios/WatchTests reads it on the Apple Watch.
class PhoneStateTest {
    private val workout = JSONObject(
        """
        {
          "state": "workout", "workoutId": "w1", "startedAt": 1000, "clockStart": 2000,
          "title": "Push day", "exercise": "Bench Press (Barbell)", "next": "Next: 60 kg × 5",
          "restStart": 5000, "restEnd": 95000, "restLabel": "Rest", "restOver": "Rest's up",
          "exerciseId": "e1", "setId": "s2", "weight": 60, "reps": 5, "unit": "kg", "step": 2.5,
          "previous": "Last time: 57.5 kg × 5", "position": "Set 2 of 3",
          "accent": 4292146503, "pausable": true,
          "pauses": [{"start": 1500, "end": 2500}, {"start": 9, "end": 3}],
          "exercises": [{"id": "e1", "name": "Bench Press (Barbell)", "unit": "kg", "step": 2.5,
            "weighted": true, "counted": true, "rest": 90,
            "sets": [{"id": "s1", "mark": "1", "weight": 57.5, "reps": 5, "done": true, "position": "Set 1 of 3", "next": "Next: 60 kg × 5"},
                     {"mark": "2"}]}],
          "sentAt": 42
        }
        """,
    )

    @Test
    fun `a workout decodes whole`() {
        val state = PhoneState.from(workout) as PhoneState.Workout
        assertEquals("w1", state.workoutId)
        assertEquals(2000L, state.clock)
        assertEquals(PhoneState.Workout.Rest(5000, 95000, "Rest", "Rest's up"), state.rest)
        assertEquals(60.0, state.set?.weight)
        assertEquals(5, state.set?.reps)
        assertEquals("Set 2 of 3", state.set?.position)
        // ARGB past Int.MAX_VALUE, as Dart's toARGB32 writes it
        assertEquals(0xFFD4F547.toInt(), state.accent)
        assertEquals(listOf(1500L..2500L), state.pauses)
        // a row without an id is dropped, not the exercise
        assertEquals(listOf("s1"), state.exercises.single().sets.map { it.id })
        assertNull(state.controls)
    }

    @Test
    fun `no set up next once every set is done`() {
        workout.remove("setId")
        assertNull((PhoneState.from(workout) as PhoneState.Workout).set)
    }

    @Test
    fun `a rest that has no length is no rest`() {
        workout.put("restEnd", 5000)
        assertNull((PhoneState.from(workout) as PhoneState.Workout).rest)
    }

    @Test
    fun `controls come whole or not at all`() {
        listOf(
            "done", "skip", "add", "subtract", "repsLabel", "unreachable", "heartRate", "bpm", "energy", "kcal",
            "finish", "finishTitle", "finishConfirm", "finishCancel", "save", "notDone",
        ).forEach { workout.put(it, it) }
        assertEquals("repsLabel", (PhoneState.from(workout) as PhoneState.Workout).controls?.reps)
        workout.remove("save")
        assertNull((PhoneState.from(workout) as PhoneState.Workout).controls)
    }

    @Test
    fun `idle and off carry their line`() {
        assertEquals(PhoneState.Idle("Start a workout on your phone"), PhoneState.from(JSONObject("""{"state":"idle","message":"Start a workout on your phone"}""")))
        assertEquals(PhoneState.Off("Off"), PhoneState.from(JSONObject("""{"state":"off","message":"Off"}""")))
    }

    @Test
    fun `anything unrecognised leaves the current state standing`() {
        assertNull(PhoneState.from(JSONObject("""{"state":"somethingNew"}""")))
        assertNull(PhoneState.from(JSONObject("""{"state":"idle"}""")))
        workout.remove("title")
        assertNull(PhoneState.from(workout))
    }

    @Test
    fun `values read as the phone writes them`() {
        val set = (PhoneState.from(workout) as PhoneState.Workout).set!!
        assertEquals("60 kg × 5", values(set))
        assertEquals("57.5 kg", values(set.copy(weight = 57.5, reps = null)))
        assertEquals("× 12", values(set.copy(weight = null, reps = 12)))
        assertNull(values(set.copy(weight = null, reps = null)))
    }

    @Test
    fun `clocks count up whole seconds and down rounded up`() {
        assertEquals("1:05", clock(65_400, up = true))
        assertEquals("1:02:03", clock(3_723_000, up = true))
        assertEquals("0:01", clock(200, up = false))
        assertEquals("0:00", clock(-5, up = false))
        assertTrue(clock(59_999, up = false) == "1:00")
    }

    @Test
    fun `the dimmed page's clock is true to the minute`() {
        assertEquals("0:12", minutes(12 * 60_000L + 59_000))
        assertEquals("1:05", minutes(65 * 60_000L))
        assertEquals("0:00", minutes(-1))
    }
}
