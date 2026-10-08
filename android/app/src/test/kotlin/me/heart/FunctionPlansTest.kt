package me.heart

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/// The App Functions' decisions (#289), on the JVM: the same cases the iOS
/// intents' tests hold RestVoice and LogSetVoice to.
class FunctionPlansTest {
    private val now = 1_700_000_000_000L
    private val rest = FunctionPlans.RestContext.of(JSONObject("""{"workoutId":"w1","exerciseId":"e1","seconds":90}"""))

    @Test
    fun `start rest uses the exercise's length unless one is said`() {
        val byDefault = FunctionPlans.startRest(rest, null, now) as FunctionPlans.Rest.Started
        assertEquals(90, byDefault.seconds)
        assertEquals("startRest", byDefault.command.getString("action"))
        assertEquals("w1", byDefault.command.getString("workoutId"))
        assertEquals(90, byDefault.command.getInt("seconds"))
        assertEquals(now, byDefault.command.getLong("at"))

        val said = FunctionPlans.startRest(rest, 120, now) as FunctionPlans.Rest.Started
        assertEquals(120, said.seconds)
    }

    @Test
    fun `start rest with nothing to go on says so`() {
        assertEquals(FunctionPlans.Rest.NoWorkout, FunctionPlans.startRest(null, 60, now))
        val noTimer = FunctionPlans.RestContext.of(JSONObject("""{"workoutId":"w1","exerciseId":"e1"}"""))
        assertEquals(FunctionPlans.Rest.NoTimer, FunctionPlans.startRest(noTimer, null, now))
        assertEquals(FunctionPlans.Rest.NoTimer, FunctionPlans.startRest(rest, 0, now))
    }

    @Test
    fun `extend and skip need a rest that is running`() {
        val over = now - 1_000
        assertEquals(FunctionPlans.Rest.NoRest, FunctionPlans.extendRest(rest, 30, over, now))
        assertEquals(FunctionPlans.Rest.NoRest, FunctionPlans.skipRest(rest, null, now))
        assertEquals(FunctionPlans.Rest.NoWorkout, FunctionPlans.skipRest(null, now + 10_000, now))

        val running = now + 42_000
        val extended = FunctionPlans.extendRest(rest, 30, running, now) as FunctionPlans.Rest.Extended
        assertEquals(72, extended.left)
        assertEquals("adjustRest", extended.command.getString("action"))
        assertEquals(30, extended.command.getInt("seconds"))

        val skipped = FunctionPlans.skipRest(rest, running, now) as FunctionPlans.Rest.Skipped
        assertEquals("skipRest", skipped.command.getString("action"))
        assertTrue(!skipped.command.has("seconds"))
    }

    private val bench = FunctionPlans.NextSet.of(
        JSONObject(
            """{"workoutId":"w1","setId":"s1","exerciseName":"Bench Press","weighted":true,"counted":true,"unit":"kg","weight":100.0,"reps":5}""",
        ),
    )

    @Test
    fun `log a set keeps what was planned and takes what was said`() {
        val planned = FunctionPlans.logSet(bench, true, null, null, now) as FunctionPlans.Log.Logged
        assertEquals("100 kg × 5, Bench Press", planned.description)
        assertEquals("complete", planned.command.getString("action"))
        assertEquals("s1", planned.command.getString("setId"))
        assertTrue("the planned values stay the app's", !planned.command.has("weight") && !planned.command.has("reps"))

        val said = FunctionPlans.logSet(bench, true, 102.5, 4, now) as FunctionPlans.Log.Logged
        assertEquals("102.5 kg × 4, Bench Press", said.description)
        assertEquals(102.5, said.command.getDouble("weight"), 0.0)
        assertEquals(4, said.command.getInt("reps"))
    }

    @Test
    fun `log a set with nothing to log, or nothing to log with`() {
        assertEquals(FunctionPlans.Log.NoWorkout, FunctionPlans.logSet(null, false, 100.0, 5, now))
        assertEquals(FunctionPlans.Log.NothingLeft, FunctionPlans.logSet(null, true, 100.0, 5, now))
        val empty = FunctionPlans.NextSet.of(
            JSONObject("""{"workoutId":"w1","setId":"s1","exerciseName":"Bench Press","weighted":true,"counted":true,"unit":"kg"}"""),
        )
        assertEquals(FunctionPlans.Log.NeedsValues, FunctionPlans.logSet(empty, true, null, 5, now))
        assertEquals(FunctionPlans.Log.NeedsValues, FunctionPlans.logSet(empty, true, 100.0, null, now))
        val plank = FunctionPlans.NextSet.of(
            JSONObject("""{"workoutId":"w1","setId":"s2","exerciseName":"Plank","weighted":false,"counted":false,"unit":"kg"}"""),
        )
        val logged = FunctionPlans.logSet(plank, true, null, null, now) as FunctionPlans.Log.Logged
        assertEquals("Plank", logged.description)
    }

    @Test
    fun `the clock reads like the app's`() {
        assertEquals("1:30", FunctionPlans.clock(90))
        assertEquals("0:05", FunctionPlans.clock(5))
        assertEquals("10:00", FunctionPlans.clock(600))
    }

    @Test
    fun `names are matched whole first, then loosely, accents and case aside`() {
        val list = JSONArray(
            """[{"id":"e1","name":"Bench Press (Barbell)"},{"id":"e2","name":"Press"},{"id":"e3","name":"Développé couché"}]""",
        )
        assertEquals("e2", NameLookup.id(list, "press"))
        assertEquals("e1", NameLookup.id(list, "bench press"))
        assertEquals("e3", NameLookup.id(list, "developpe couche"))
        assertNull(NameLookup.id(list, "deadlift"))
        assertNull(NameLookup.id(list, "   "))
        assertNull(NameLookup.id(null, "press"))
    }

    @Test
    fun `the queue is written the way shared_preferences reads it`() {
        assertEquals(mutableListOf<String>(), CommandRelay.pending(null))
        assertEquals(mutableListOf<String>(), CommandRelay.pending("not a list"))
        val one = CommandRelay.encode(listOf("""{"action":"skipRest"}"""))
        assertTrue(one.startsWith(CommandRelay.LIST_PREFIX))
        assertEquals(listOf("""{"action":"skipRest"}"""), CommandRelay.pending(one))
    }

    @Test
    fun `a command becomes the map a channel carries`() {
        val map = CommandRelay.toMap(JSONObject("""{"action":"complete","workoutId":"w1","reps":5,"weight":null}"""))
        assertEquals("complete", map["action"])
        assertEquals(5, map["reps"])
        assertNull(map["weight"])
    }
}
