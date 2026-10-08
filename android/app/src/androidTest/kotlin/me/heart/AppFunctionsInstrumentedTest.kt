package me.heart

import android.os.Build
import androidx.appfunctions.AppFunctionData
import androidx.appfunctions.AppFunctionManager
import androidx.appfunctions.AppFunctionSearchSpec
import androidx.appfunctions.metadata.AppFunctionMetadata
import androidx.appfunctions.ExecuteAppFunctionRequest
import androidx.appfunctions.ExecuteAppFunctionResponse
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.time.Duration.Companion.seconds

/// The App Functions (#289) called the way an assistant calls them: through
/// the platform, into the generated service, with the app's UI never up. An
/// Android 16 emulator; below it the platform has no manager and the test is
/// skipped. A package may call its own functions without a permission.
@RunWith(AndroidJUnit4::class)
class AppFunctionsInstrumentedTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private lateinit var manager: AppFunctionManager

    @Before
    fun setUp() {
        assumeTrue("App Functions need Android 16", Build.VERSION.SDK_INT >= 36)
        manager = AppFunctionManager.getInstance(context) ?: throw AssertionError("no AppFunctionManager on this device")
        // nothing published: no session, no workout, no templates
        ShortcutsStore.prefs(context).edit().clear().commit()
    }

    /// The function's metadata as the platform indexed it — what an assistant
    /// reads before calling — which is also what its parameters are built from.
    private suspend fun metadata(id: String): AppFunctionMetadata {
        val found = manager.searchAppFunctions(AppFunctionSearchSpec(packageNames = setOf(context.packageName)))
        return found.firstOrNull { it.id == id } ?: throw AssertionError("$id is not indexed; indexed: ${found.map { it.id }}")
    }

    private suspend fun call(id: String, fill: AppFunctionData.Builder.() -> Unit = {}): String {
        val metadata = metadata(id)
        val parameters = AppFunctionData.Builder(metadata.parameters, metadata.components).apply(fill).build()
        val response = manager.executeAppFunction(ExecuteAppFunctionRequest(context.packageName, id, parameters))
        return when (response) {
            is ExecuteAppFunctionResponse.Success -> response.returnValue.getString(ExecuteAppFunctionResponse.Success.PROPERTY_RETURN_VALUE)
                ?: throw AssertionError("no return value for $id")
            is ExecuteAppFunctionResponse.Error -> throw AssertionError("$id failed: ${response.error}")
        }
    }

    @Test
    fun theTenFunctionsAreIndexed() = runTest(timeout = 30.seconds) {
        val found = manager.searchAppFunctions(AppFunctionSearchSpec(packageNames = setOf(context.packageName)))
        val ids = found.map { it.id }.toSet()
        assertTrue("indexed: $ids", ids.contains(HeartAppFunctionService.FUNCTION_ID_START_WORKOUT))
        assertEquals(10, ids.size)
        assertTrue(found.all { it.description.isNotBlank() })
    }

    @Test
    fun aQuestionIsAnsweredByTheHeadlessEngine() = runTest(timeout = 60.seconds) {
        // Dart's own sentence for a device without a session, in the device's language
        val answer = call(HeartAppFunctionService.FUNCTION_ID_WORKOUTS_THIS_WEEK)
        assertEquals("No workouts yet", answer)
        // the second question rides the running engine
        val again = call(HeartAppFunctionService.FUNCTION_ID_WORKOUTS_THIS_WEEK)
        assertEquals("No workouts yet", again)
    }

    @Test
    fun aRestCommandWithNoWorkoutSaysSo() = runTest(timeout = 30.seconds) {
        val answer = call(HeartAppFunctionService.FUNCTION_ID_START_REST) { setInt("seconds", 60) }
        assertEquals(context.getString(R.string.function_no_workout), answer)
        assertEquals(context.getString(R.string.function_no_workout), call(HeartAppFunctionService.FUNCTION_ID_SKIP_REST))
        // a workout, but no rest running
        ShortcutsStore.put(ShortcutsStore.prefs(context), ShortcutsStore.REST, mapOf("workoutId" to "w1", "exerciseId" to "e1", "seconds" to 90))
        CommandRelay.flutterPrefs(context).edit().remove("flutter.rest.end").commit()
        assertEquals(context.getString(R.string.function_no_rest), call(HeartAppFunctionService.FUNCTION_ID_SKIP_REST))
    }

    @Test
    fun anUnknownTemplateOrExerciseIsNamedAsSuch() = runTest(timeout = 60.seconds) {
        val template = call(HeartAppFunctionService.FUNCTION_ID_START_WORKOUT) { setString("template", "nope") }
        assertEquals(context.getString(R.string.function_unknown_template), template)
        val exercise = call(HeartAppFunctionService.FUNCTION_ID_PERSONAL_RECORD) { setString("exercise", "nope") }
        assertEquals(context.getString(R.string.function_unknown_exercise), exercise)
    }

    @Test
    fun aSetLoggedWithTheAppClosedWaitsInTheQueue() = runTest(timeout = 30.seconds) {
        val flutter = CommandRelay.flutterPrefs(context)
        flutter.edit().remove("flutter.lockScreen.pendingCommands").commit()
        ShortcutsStore.put(ShortcutsStore.prefs(context), ShortcutsStore.REST, mapOf("workoutId" to "w1", "exerciseId" to "e1", "seconds" to 90))
        ShortcutsStore.put(
            ShortcutsStore.prefs(context),
            ShortcutsStore.NEXT_SET,
            mapOf("workoutId" to "w1", "setId" to "s1", "exerciseName" to "Bench Press", "weighted" to true, "counted" to true, "unit" to "kg"),
        )
        val answer = call(HeartAppFunctionService.FUNCTION_ID_LOG_SET) {
            setDouble("weight", 100.0)
            setInt("reps", 5)
        }
        assertEquals(context.getString(R.string.function_app_closed), answer)
        val queued = CommandRelay.pending(flutter.getString("flutter.lockScreen.pendingCommands", null))
        assertEquals(1, queued.size)
        assertTrue(queued.single().contains("\"action\":\"complete\"") && queued.single().contains("\"setId\":\"s1\""))
    }
}
