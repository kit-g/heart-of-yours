package me.heart.wear

import org.json.JSONArray
import org.json.JSONObject

/// What the phone last told the watch — the twin of `WatchState` in
/// ios/Watch/WatchState.swift, decoded from what `lib/core/env/watch.dart`
/// sends. The phone is the only writer: each state is complete on its own,
/// never a delta against one the watch may not have.
///
/// Every string is finished copy from the phone, which owns localisation and
/// unit formatting. The watch translates nothing.
sealed interface PhoneState {
    /// Nothing from the phone yet.
    data object Awaiting : PhoneState

    /// No workout running.
    data class Idle(val message: String) : PhoneState

    /// Switched off in the phone's Settings.
    data class Off(val message: String) : PhoneState

    data class Workout(
        val workoutId: String,
        /// Instants are epoch milliseconds, as the phone sends them.
        val startedAt: Long,
        val title: String,
        val exercise: String,
        val next: String,
        val rest: Rest?,
        /// ARGB, the dark half of the phone's preset.
        val accent: Int,
        /// The set up next; null when every set is done.
        val set: UpNext?,
        /// The whole workout, for going back to a set already done.
        val exercises: List<Exercise>,
        val controls: Controls?,
        /// `WorkoutActivity`'s name for the session.
        val activity: String?,
        /// Where the elapsed clock counts from: [startedAt] moved on by every
        /// closed pause. Null from a phone that predates pauses.
        val clockStart: Long?,
        /// While paused, when; the clock stands still.
        val pausedAt: Long?,
        /// Whether pausing is on, on the phone: off, there is no control here.
        val pausable: Boolean,
        val pauses: List<LongRange>,
    ) : PhoneState {
        /// What the elapsed clock counts from.
        val clock: Long get() = clockStart ?: startedAt

        data class Rest(val start: Long, val end: Long, val label: String, val over: String)

        data class UpNext(
            val exerciseId: String,
            val setId: String,
            /// In [unit], as the phone shows it; null for a set without weight.
            val weight: Double?,
            /// Null for a set that counts neither — ticked as prescribed.
            val reps: Int?,
            val unit: String?,
            /// One rotary detent of weight.
            val step: Double,
            /// The same set last session, as a finished line ("Last time: …").
            val previous: String?,
            /// "Set 2 of 3".
            val position: String?,
        )

        data class Exercise(
            val id: String,
            val name: String,
            val unit: String?,
            val step: Double,
            val weighted: Boolean,
            val counted: Boolean,
            /// Its rest timer in seconds; null for none.
            val rest: Int?,
            val sets: List<Row>,
        ) {
            data class Row(
                val id: String,
                val weight: Double?,
                val reps: Int?,
                val done: Boolean,
                /// What the set column shows: "1", or "W" for a warm-up.
                val mark: String,
                /// The type spelled out, for TalkBack; null for a plain set.
                val type: String?,
                val position: String,
                val previous: String?,
                val next: String,
            )
        }

        /// The copy for the watch's controls. Present as a whole or not at all,
        /// like the phone sends it.
        data class Controls(
            val done: String,
            val skip: String,
            val add: String,
            val subtract: String,
            val reps: String,
            val unreachable: String,
            val heartRate: String,
            val bpm: String,
            val energy: String,
            val kcal: String,
            val finish: String,
            val finishTitle: String,
            val finishConfirm: String,
            val finishCancel: String,
            val save: String,
            val notDone: String,
            val restLabel: String,
            val restOver: String,
            val allDone: String,
            val idle: String,
            val sending: String,
            val finishedAway: String,
            val pause: String,
            val resume: String,
            val paused: String,
        )
    }

    companion object {
        /// Decodes a state as the phone sends it; null for anything it doesn't
        /// recognise, which leaves the current state standing.
        fun from(json: JSONObject): PhoneState? {
            return when (json.optString("state")) {
                "idle" -> json.string("message")?.let(::Idle)
                "off" -> json.string("message")?.let(::Off)
                "workout" -> workout(json)
                else -> null
            }
        }

        private fun workout(json: JSONObject): Workout? {
            val workoutId = json.string("workoutId") ?: return null
            val startedAt = json.long("startedAt") ?: return null
            val title = json.string("title") ?: return null
            val exercise = json.string("exercise") ?: return null
            val next = json.string("next") ?: return null

            val restStart = json.long("restStart")
            val restEnd = json.long("restEnd")
            val restLabel = json.string("restLabel")
            val restOver = json.string("restOver")
            val rest = if (restStart != null && restEnd != null && restLabel != null && restOver != null && restStart < restEnd) {
                Workout.Rest(restStart, restEnd, restLabel, restOver)
            } else {
                null
            }

            val exerciseId = json.string("exerciseId")
            val setId = json.string("setId")
            val set = if (exerciseId != null && setId != null) {
                Workout.UpNext(
                    exerciseId = exerciseId,
                    setId = setId,
                    weight = json.double("weight"),
                    reps = json.int("reps"),
                    unit = json.string("unit"),
                    step = json.double("step") ?: 1.0,
                    previous = json.string("previous"),
                    position = json.string("position"),
                )
            } else {
                null
            }

            return Workout(
                workoutId = workoutId,
                startedAt = startedAt,
                title = title,
                exercise = exercise,
                next = next,
                rest = rest,
                accent = (json.long("accent") ?: 0xFFFFFFFF).toInt(),
                set = set,
                exercises = json.objects("exercises").mapNotNull(::exercise),
                controls = controls(json),
                activity = json.string("activity"),
                clockStart = json.long("clockStart"),
                pausedAt = json.long("pausedAt"),
                pausable = json.optBoolean("pausable", false),
                pauses = json.objects("pauses").mapNotNull { pause ->
                    val start = pause.long("start")
                    val end = pause.long("end")
                    if (start != null && end != null && start < end) start..end else null
                },
            )
        }

        private fun exercise(json: JSONObject): Workout.Exercise? {
            return Workout.Exercise(
                id = json.string("id") ?: return null,
                name = json.string("name") ?: return null,
                unit = json.string("unit"),
                step = json.double("step") ?: 1.0,
                weighted = json.optBoolean("weighted", false),
                counted = json.optBoolean("counted", false),
                rest = json.int("rest"),
                sets = json.objects("sets").mapNotNull { row ->
                    Workout.Exercise.Row(
                        id = row.string("id") ?: return@mapNotNull null,
                        weight = row.double("weight"),
                        reps = row.int("reps"),
                        done = row.optBoolean("done", false),
                        mark = row.string("mark") ?: "",
                        type = row.string("type"),
                        position = row.string("position") ?: "",
                        previous = row.string("previous"),
                        next = row.string("next") ?: "",
                    )
                },
            )
        }

        private fun controls(json: JSONObject): Workout.Controls? {
            fun text(key: String): String? = json.string(key)
            return Workout.Controls(
                done = text("done") ?: return null,
                skip = text("skip") ?: return null,
                add = text("add") ?: return null,
                subtract = text("subtract") ?: return null,
                reps = text("repsLabel") ?: return null,
                unreachable = text("unreachable") ?: return null,
                heartRate = text("heartRate") ?: return null,
                bpm = text("bpm") ?: return null,
                energy = text("energy") ?: return null,
                kcal = text("kcal") ?: return null,
                finish = text("finish") ?: return null,
                finishTitle = text("finishTitle") ?: return null,
                finishConfirm = text("finishConfirm") ?: return null,
                finishCancel = text("finishCancel") ?: return null,
                save = text("save") ?: return null,
                notDone = text("notDone") ?: return null,
                restLabel = text("restLabelAway") ?: "",
                restOver = text("restOverAway") ?: "",
                allDone = text("allDone") ?: "",
                idle = text("idle") ?: "",
                sending = text("sending") ?: "",
                finishedAway = text("finishedAway") ?: "",
                pause = text("pause") ?: "",
                resume = text("resume") ?: "",
                paused = text("paused") ?: "",
            )
        }
    }
}

/// org.json's opt* coerce a missing key to "" or 0; these say null instead.
private fun JSONObject.string(key: String): String? = if (isNull(key)) null else opt(key) as? String

private fun JSONObject.long(key: String): Long? = if (isNull(key)) null else (opt(key) as? Number)?.toLong()

private fun JSONObject.int(key: String): Int? = if (isNull(key)) null else (opt(key) as? Number)?.toInt()

private fun JSONObject.double(key: String): Double? = if (isNull(key)) null else (opt(key) as? Number)?.toDouble()

private fun JSONObject.objects(key: String): List<JSONObject> {
    val array = optJSONArray(key) ?: JSONArray()
    return (0 until array.length()).mapNotNull { array.optJSONObject(it) }
}
