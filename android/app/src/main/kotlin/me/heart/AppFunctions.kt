package me.heart

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunctionDeclaration
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/// The same actions for Gemini that Siri has (#289, #261): start and finish a
/// workout, start, extend and skip the rest, log a set, and the four questions.
/// Each function builds the command Dart already understands — the lock
/// screen's (#141) or the questions' (#288) — hands it over, and says what
/// happened in the device's language. Training data only: nothing here reads
/// Health Connect. Android 16 binds the generated service; below it the class
/// is never loaded.
@RequiresApi(36)
@AppFunctionServiceEntryPoint(serviceName = "HeartAppFunctionService", appFunctionXmlFileName = "heart_app_functions")
abstract class BaseHeartAppFunctionService : AppFunctionService() {
    private val functions by lazy { HeartFunctions(applicationContext) }

    /**
     * Starts a workout in Heart: an empty one, or one from a saved template
     * when a template name is given. Opens the app on the new workout.
     *
     * @param template The name of the user's workout template to start from, as they call it ("Push day"). Omit for an empty workout.
     * @return What happened, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun startWorkout(template: String?): String = withContext(Dispatchers.Default) { functions.startWorkout(template) }

    /**
     * Finishes the workout in progress: opens Heart on the finish step, where
     * the user confirms.
     *
     * @return What happened, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun finishWorkout(): String = withContext(Dispatchers.Default) { functions.finishWorkout() }

    /**
     * Starts the rest timer for the exercise the user is on, in the workout in
     * progress. Uses the exercise's own rest length unless seconds are given.
     *
     * @param seconds How long to rest, in seconds, when the user said a length (90 for a minute and a half). Omit to use the exercise's setting.
     * @return What happened, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun startRest(seconds: Int?): String = withContext(Dispatchers.Default) { functions.startRest(seconds) }

    /**
     * Adds time to the rest timer running now.
     *
     * @param seconds How many seconds to add (30 for half a minute).
     * @return What happened, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun extendRest(seconds: Int): String = withContext(Dispatchers.Default) { functions.extendRest(seconds) }

    /**
     * Ends the rest timer running now, so the user can go on with the next set.
     *
     * @return What happened, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun skipRest(): String = withContext(Dispatchers.Default) { functions.skipRest() }

    /**
     * Logs the set up next in the workout in progress as done, with the weight
     * and repetitions the user said, or the ones already planned for it.
     *
     * @param weight The weight lifted, in the user's own unit (kilograms or pounds, as the app shows them). Omit to keep the planned weight.
     * @param reps How many repetitions were done. Omit to keep the planned count.
     * @return What was logged, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun logSet(weight: Double?, reps: Int?): String = withContext(Dispatchers.Default) { functions.logSet(weight, reps) }

    /**
     * The user's personal record for an exercise: the heaviest set, the longest
     * distance or the most repetitions, with the day it was set.
     *
     * @param exercise The exercise's name, as the user says it ("bench press").
     * @return The record, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun personalRecord(exercise: String): String = functions.ask("record", exercise = exercise)

    /**
     * When the user last did an exercise, and in which workout.
     *
     * @param exercise The exercise's name, as the user says it ("squat").
     * @return The answer, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun lastTimeForExercise(exercise: String): String = functions.ask("lastExercise", exercise = exercise)

    /**
     * When the user last did a workout from one of their templates, by its name.
     *
     * @param template The template's name, as the user calls it ("Push day").
     * @return The answer, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun lastTimeForTemplate(template: String): String = functions.ask("lastTemplate", template = template)

    /**
     * How many workouts the user has finished this week.
     *
     * @return The count, as a sentence for the user.
     */
    @AppFunctionDeclaration(isDescribedByKDoc = true)
    suspend fun workoutsThisWeek(): String = functions.ask("weekly")
}

/// The functions' bodies, off the service so they read in one place: what
/// Dart published, the plan, the hand-over, the sentence.
class HeartFunctions(private val context: Context) {
    private val store get() = ShortcutsStore.prefs(context)
    private val flutter get() = CommandRelay.flutterPrefs(context)

    suspend fun startWorkout(template: String?): String {
        val link = Uri.parse("heart://app/start").buildUpon()
        if (!template.isNullOrBlank()) {
            val id = NameLookup.id(ShortcutsStore.array(store, ShortcutsStore.TEMPLATES), template)
                ?: return context.getString(R.string.function_unknown_template)
            link.appendQueryParameter("template", id)
        }
        return open(link.build())
    }

    suspend fun finishWorkout(): String = open(Uri.parse("heart://app/finish"))

    suspend fun startRest(seconds: Int?): String {
        return say(FunctionPlans.startRest(restContext(), seconds, now()))
    }

    suspend fun extendRest(seconds: Int): String {
        return say(FunctionPlans.extendRest(restContext(), seconds, restEnd(), now()))
    }

    suspend fun skipRest(): String = say(FunctionPlans.skipRest(restContext(), restEnd(), now()))

    suspend fun logSet(weight: Double?, reps: Int?): String {
        val set = FunctionPlans.NextSet.of(ShortcutsStore.obj(store, ShortcutsStore.NEXT_SET))
        val plan = FunctionPlans.logSet(set, workoutRunning = restContext() != null, weight, reps, now())
        return when (plan) {
            is FunctionPlans.Log.Logged -> deliver(plan.command, context.getString(R.string.function_logged, plan.description))
            FunctionPlans.Log.NoWorkout -> context.getString(R.string.function_no_workout)
            FunctionPlans.Log.NothingLeft -> context.getString(R.string.function_nothing_left)
            FunctionPlans.Log.NeedsValues -> context.getString(R.string.function_say_values)
        }
    }

    suspend fun ask(question: String, exercise: String? = null, template: String? = null): String {
        val exerciseId = exercise?.let {
            NameLookup.id(ShortcutsStore.array(store, ShortcutsStore.EXERCISES), it)
                ?: return context.getString(R.string.function_unknown_exercise)
        }
        val userId = ShortcutsStore.string(store, ShortcutsStore.USER_ID)
        return QuestionsEngine.ask(context, question, userId, exerciseId = exerciseId, template = template)
            ?: context.getString(R.string.function_could_not_answer)
    }

    private fun restContext() = FunctionPlans.RestContext.of(ShortcutsStore.obj(store, ShortcutsStore.REST))

    private fun restEnd(): Long? = if (flutter.contains(REST_END)) flutter.getLong(REST_END, 0) else null

    private fun now() = System.currentTimeMillis()

    private suspend fun say(plan: FunctionPlans.Rest): String = when (plan) {
        is FunctionPlans.Rest.Started -> deliver(
            plan.command,
            context.getString(R.string.function_resting, FunctionPlans.clock(plan.seconds)),
        )
        is FunctionPlans.Rest.Extended -> deliver(
            plan.command,
            context.getString(R.string.function_rest_extended, FunctionPlans.clock(plan.left)),
        )
        is FunctionPlans.Rest.Skipped -> deliver(plan.command, context.getString(R.string.function_rest_skipped))
        FunctionPlans.Rest.NoWorkout -> context.getString(R.string.function_no_workout)
        FunctionPlans.Rest.NoRest -> context.getString(R.string.function_no_rest)
        FunctionPlans.Rest.NoTimer -> context.getString(R.string.function_no_timer)
    }

    /// Applied by the running app, [done] is the answer; queued for the next
    /// launch, the user is told so; refused by the app — a stale set, a rest
    /// already over — the app knows better than the plan.
    private suspend fun deliver(command: org.json.JSONObject, done: String): String {
        return when (CommandRelay.deliver(context, command)) {
            CommandRelay.Delivery.APPLIED -> done
            CommandRelay.Delivery.QUEUED -> context.getString(R.string.function_app_closed)
            CommandRelay.Delivery.REJECTED -> context.getString(R.string.function_no_workout)
        }
    }

    /// Opens the app on [link]. A service may not always start an activity from
    /// the background; the attempt is logged, never fatal, and the link stands
    /// as a pending intent the system can fire.
    private fun open(link: Uri): String {
        val intent = Intent(Intent.ACTION_VIEW, link, context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT).send()
        } catch (error: Exception) {
            Log.w(TAG, "Could not open $link", error)
            runCatching { context.startActivity(intent) }
        }
        return context.getString(R.string.function_opening)
    }

    companion object {
        private const val TAG = "HeartFunctions"
        private const val REST_END = "flutter.rest.end"
    }
}
