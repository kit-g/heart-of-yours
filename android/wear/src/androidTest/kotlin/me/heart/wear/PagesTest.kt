package me.heart.wear

import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.hasScrollToNodeAction
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
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
        compose.onNodeWithText("Done").assertExists()
        compose.onNode(page).performScrollToNode(hasText("Syncs with your phone when it's back"))
        compose.onNodeWithText("Syncs with your phone when it's back").assertIsDisplayed()
    }

    @Test
    fun noWorkoutPointsAtThePhone() {
        show(fixture("idle.json"))
        compose.onNodeWithText("Start a workout on your phone").assertIsDisplayed()
    }
}
