package me.heart.wear

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.wear.compose.material3.AppScaffold
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/// The watch's pages on a Wear OS emulator, drawn from what the phone sends
/// (test/fixtures/watch, #466) — the Wear OS counterpart of ios/WatchUITests.
@RunWith(AndroidJUnit4::class)
class PagesTest {
    @get:Rule
    val compose = createComposeRule()

    private val sent = mutableListOf<Command>()

    /// The page's own list, not the pager it sits in, which scrolls too.
    private val page = hasScrollToNodeAction() and SemanticsMatcher.keyIsDefined(SemanticsProperties.VerticalScrollAxisRange)

    private fun fixture(name: String): PhoneState {
        val assets = InstrumentationRegistry.getInstrumentation().context.assets
        return PhoneState.from(JSONObject(assets.open(name).bufferedReader().readText()))!!
    }

    /// The fixture's instants are fixed; a rest is moved to run now.
    private fun resting(): PhoneState.Workout {
        val workout = fixture("workout_resting.json") as PhoneState.Workout
        val now = System.currentTimeMillis()
        return workout.copy(rest = workout.rest!!.copy(start = now, end = now + 90_000))
    }

    private fun show(state: PhoneState, reachable: Boolean = true) {
        compose.setContent { HeartTheme { PhoneStateScreen(state, reachable, { sent += it }) } }
    }

    @Test
    fun theSetUpNextIsTickedWithTheValuesShown() {
        show(resting())
        // the rest's controls lead, so the set sits below them
        compose.onNode(page).performScrollToNode(hasText("Set 2 of 2"))
        compose.onNodeWithText("Bench Press (Barbell)").assertIsDisplayed()
        compose.onNodeWithText("Set 2 of 2").assertIsDisplayed()
        compose.onNode(page).performScrollToNode(hasText("Done"))
        compose.onNodeWithText("Done").performClick()
        assertEquals(listOf(Command.Complete("w1", "b3", 62.5, 5)), sent)
    }

    @Test
    fun restIsSkippedFromTheWrist() {
        show(resting())
        // one element for TalkBack: the label and the time left
        compose.onNodeWithContentDescription("Rest", substring = true).assertIsDisplayed()
        compose.onNodeWithText("Skip").performClick()
        assertEquals(listOf(Command.SkipRest("w1")), sent)
    }

    /// The set up next, offering the stopwatch (#484).
    private fun timed(): PhoneState.Workout {
        val workout = resting().copy(rest = null)
        return workout.copy(exercises = workout.exercises.map { it.copy(timed = true) })
    }

    @Test
    fun aHoldIsTimedAndLogsWhatItTook() {
        show(timed())
        compose.onNode(page).performScrollToNode(hasText("Start"))
        compose.onNodeWithText("Start").performClick()
        compose.waitForIdle()
        compose.mainClock.autoAdvance = true
        Thread.sleep(1100)
        compose.onNode(page).performScrollToNode(hasText("Done"))
        compose.onNodeWithText("Done").performClick()
        val tick = sent.single() as Command.Complete
        assertEquals("b3", tick.setId)
        assertTrue((tick.seconds ?: 0) >= 1)
    }

    @Test
    fun aHoldCanBeTickedAsPrescribed() {
        show(timed())
        compose.onNode(page).performScrollToNode(hasText("Done"))
        compose.onNodeWithText("Done").performClick()
        assertEquals(listOf(Command.Complete("w1", "b3", 62.5, 5)), sent)
    }

    @Test
    fun withEverySetTickedFinishAsksFirst() {
        show(fixture("workout_paused_done.json"))
        compose.onNodeWithText("Paused").assertIsDisplayed()
        compose.onNode(page).performScrollToNode(hasText("Finish"))
        compose.onNodeWithText("Finish").performClick()
        compose.onNodeWithText("Complete your workout?").assertIsDisplayed()
        assertTrue("nothing is sent before the answer", sent.isEmpty())
        compose.onNodeWithText("Yes, I'm done!").performClick()
        assertEquals(listOf(Command.Finish("w1")), sent)
    }

    @Test
    fun awayFromThePhoneTheControlsStayAndSaySo() {
        show(resting(), reachable = false)
        compose.onNode(page).performScrollToNode(hasText("Done"))
        compose.onNodeWithText("Done").assertExists()
        compose.onNode(page).performScrollToNode(hasText("Syncs with your phone when it's back"))
        compose.onNodeWithText("Syncs with your phone when it's back").assertIsDisplayed()
    }

    /// Play's review refused a build for this (Wear OS "watch shapes"): the
    /// first line of a list, a long name, ran past the round edge and under the
    /// time.
    @Test
    fun aListStartsInsideTheRoundScreen() {
        val name = "Triceps Pushdown (Cable)"
        val workout = resting().let { w ->
            w.copy(rest = null, exercise = name, exercises = w.exercises.map { it.copy(name = name) })
        }
        var page by mutableStateOf(0)
        compose.setContent {
            HeartTheme {
                AppScaffold {
                    when (page) {
                        0 -> WorkoutScreen(workout, reachable = true, send = {})
                        else -> WorkoutList(workout, reachable = true, unsynced = emptySet(), send = {})
                    }
                }
            }
        }
        listOf(0, 1).forEach {
            page = it
            compose.waitForIdle()
            assertClearOfTheEdge(compose.onAllNodesWithText(name)[0].fetchSemanticsNode().boundsInRoot)
        }
    }

    private fun assertClearOfTheEdge(bounds: Rect) {
        val radius = compose.onRoot().fetchSemanticsNode().size.width / 2f
        // the time has the top of the screen, about a tenth of it
        assertTrue("$bounds runs under the time", bounds.top >= radius * 2 * 0.13f)
        listOf(bounds.topLeft, bounds.topRight, bounds.bottomLeft, bounds.bottomRight).forEach { corner ->
            val distance = (corner - Offset(radius, radius)).getDistance()
            assertTrue("$bounds runs past the round edge, $distance from the centre of $radius", distance <= radius)
        }
    }

    @Test
    fun noWorkoutPointsAtThePhone() {
        show(fixture("idle.json"))
        compose.onNodeWithText("Start a workout on your phone").assertIsDisplayed()
    }
}
