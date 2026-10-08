package me.heart

import org.json.JSONObject

/// What each App Function decides, as pure data: the command to hand the app
/// and what to tell the assistant. Mirrors the iOS intents (RestVoice,
/// LogSetVoice) so the two assistants say the same things. Nothing here
/// touches Android; the tests run it on the JVM.
object FunctionPlans {
    /// A command for Dart (#141's wire shape), with a moment attached.
    fun command(action: String, workoutId: String, now: Long, vararg fields: Pair<String, Any?>): JSONObject {
        val json = JSONObject().put("action", action).put("workoutId", workoutId).put("at", now)
        for ((key, value) in fields) if (value != null) json.put(key, value)
        return json
    }

    sealed interface Rest {
        data class Started(val seconds: Int, val command: JSONObject) : Rest
        data class Extended(val by: Int, val left: Int, val command: JSONObject) : Rest
        data class Skipped(val command: JSONObject) : Rest
        object NoWorkout : Rest
        object NoRest : Rest
        object NoTimer : Rest
    }

    /// The rest Dart published: the workout and exercise the user is on, and
    /// the exercise's rest length when it has one.
    data class RestContext(val workoutId: String, val exerciseId: String, val seconds: Int?) {
        companion object {
            fun of(json: JSONObject?): RestContext? {
                val workoutId = json?.optString("workoutId")?.takeIf { it.isNotEmpty() } ?: return null
                val exerciseId = json.optString("exerciseId").takeIf { it.isNotEmpty() } ?: return null
                return RestContext(workoutId, exerciseId, if (json.has("seconds")) json.optInt("seconds") else null)
            }
        }
    }

    /// The rest running now, from the keys Dart's rest store writes
    /// (`flutter.rest.end`, milliseconds since the epoch).
    fun runningRestEnd(end: Long?, now: Long): Long? = end?.takeIf { it > now }

    fun startRest(context: RestContext?, seconds: Int?, now: Long): Rest {
        context ?: return Rest.NoWorkout
        val length = seconds ?: context.seconds
        if (length == null || length <= 0) return Rest.NoTimer
        return Rest.Started(length, command("startRest", context.workoutId, now, "seconds" to length))
    }

    fun extendRest(context: RestContext?, by: Int, restEnd: Long?, now: Long): Rest {
        context ?: return Rest.NoWorkout
        val end = runningRestEnd(restEnd, now) ?: return Rest.NoRest
        val left = ((end - now) / 1000).toInt() + by
        return Rest.Extended(by, maxOf(0, left), command("adjustRest", context.workoutId, now, "seconds" to by))
    }

    fun skipRest(context: RestContext?, restEnd: Long?, now: Long): Rest {
        context ?: return Rest.NoWorkout
        runningRestEnd(restEnd, now) ?: return Rest.NoRest
        return Rest.Skipped(command("skipRest", context.workoutId, now))
    }

    sealed interface Log {
        data class Logged(val description: String, val command: JSONObject) : Log
        object NoWorkout : Log
        object NothingLeft : Log
        object NeedsValues : Log
    }

    /// The set Dart published as up next (#287).
    data class NextSet(
        val workoutId: String,
        val setId: String,
        val exerciseName: String,
        val weighted: Boolean,
        val counted: Boolean,
        val unit: String,
        val weight: Double?,
        val reps: Int?,
    ) {
        companion object {
            fun of(json: JSONObject?): NextSet? {
                json ?: return null
                return NextSet(
                    workoutId = json.optString("workoutId").takeIf { it.isNotEmpty() } ?: return null,
                    setId = json.optString("setId").takeIf { it.isNotEmpty() } ?: return null,
                    exerciseName = json.optString("exerciseName"),
                    weighted = json.optBoolean("weighted"),
                    counted = json.optBoolean("counted"),
                    unit = json.optString("unit"),
                    weight = if (json.has("weight")) json.optDouble("weight") else null,
                    reps = if (json.has("reps")) json.optInt("reps") else null,
                )
            }
        }
    }

    /// [set] null means nothing is up next: with a workout running, every set
    /// is done; without one, there is no workout.
    fun logSet(set: NextSet?, workoutRunning: Boolean, weight: Double?, reps: Int?, now: Long): Log {
        if (set == null) return if (workoutRunning) Log.NothingLeft else Log.NoWorkout
        val finalWeight = weight ?: set.weight
        val finalReps = reps ?: set.reps
        if ((set.weighted && finalWeight == null) || (set.counted && finalReps == null)) return Log.NeedsValues
        val command = command(
            "complete", set.workoutId, now,
            "setId" to set.setId,
            "weight" to weight,
            "reps" to reps,
        )
        return Log.Logged(describe(set, finalWeight, finalReps), command)
    }

    /// "100 kg × 5, Bench Press", by what the set measures.
    fun describe(set: NextSet, weight: Double?, reps: Int?): String {
        val parts = listOfNotNull(
            weight?.takeIf { set.weighted }?.let { "${trim(it)} ${set.unit}" },
            reps?.takeIf { set.counted }?.toString(),
        )
        val values = parts.joinToString(" × ")
        return if (values.isEmpty()) set.exerciseName else "$values, ${set.exerciseName}"
    }

    fun trim(value: Double): String = if (value == Math.floor(value)) value.toLong().toString() else value.toString()

    /// m:ss, as the app's rest clock reads.
    fun clock(seconds: Int): String = "%d:%02d".format(seconds / 60, seconds % 60)
}
