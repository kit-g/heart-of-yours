package me.heart.wear

import org.json.JSONObject

/// Something the user did on the watch (#460): a request, never an edit — the
/// twin of `PhoneSession.Command` in ios/Watch/PhoneSession.swift, read on the
/// phone by `WatchCommand.fromMap` in `lib/core/env/watch.dart`.
sealed interface Command {
    val workoutId: String

    /// The set it is about, for those that are about one.
    val setId: String? get() = null

    data class Complete(override val workoutId: String, override val setId: String, val weight: Double?, val reps: Int?) : Command

    data class SkipRest(override val workoutId: String) : Command

    data class AdjustRest(override val workoutId: String, val seconds: Int) : Command

    data class Finish(override val workoutId: String) : Command

    /// New values for a set already done; it stays ticked.
    data class Edit(override val workoutId: String, override val setId: String, val weight: Double?, val reps: Int?) : Command

    /// A set ticked by mistake.
    data class Untick(override val workoutId: String, override val setId: String) : Command

    /// Stop the workout's clock, and start it again (#134).
    data class Pause(override val workoutId: String) : Command

    data class Resume(override val workoutId: String) : Command

    /// The command as the phone reads it, stamped with when it happened —
    /// which is not when a late one arrives — and an id of its own.
    fun json(id: String, at: Long): JSONObject {
        val json = JSONObject()
            .put("event", "command")
            .put("workoutId", workoutId)
            .put("id", id)
            .put("at", at)
        when (this) {
            is Complete -> json.put("action", "complete").put("setId", setId).putOpt("weight", weight).putOpt("reps", reps)
            is Edit -> json.put("action", "edit").put("setId", setId).putOpt("weight", weight).putOpt("reps", reps)
            is Untick -> json.put("action", "untick").put("setId", setId)
            is SkipRest -> json.put("action", "skipRest")
            is AdjustRest -> json.put("action", "adjustRest").put("seconds", seconds)
            is Finish -> json.put("action", "finish")
            is Pause -> json.put("action", "pause")
            is Resume -> json.put("action", "resume")
        }
        return json
    }

    companion object {
        /// Read back from what [json] wrote; null for anything else.
        fun from(json: JSONObject): Command? {
            val workoutId = json.optString("workoutId").ifEmpty { return null }
            val setId = json.optString("setId").ifEmpty { null }
            val weight = if (json.isNull("weight")) null else json.optDouble("weight")
            val reps = if (json.isNull("reps")) null else json.optInt("reps")
            return when (json.optString("action")) {
                "complete" -> setId?.let { Complete(workoutId, it, weight, reps) }
                "edit" -> setId?.let { Edit(workoutId, it, weight, reps) }
                "untick" -> setId?.let { Untick(workoutId, it) }
                "skipRest" -> SkipRest(workoutId)
                "adjustRest" -> if (json.has("seconds")) AdjustRest(workoutId, json.getInt("seconds")) else null
                "finish" -> Finish(workoutId)
                "pause" -> Pause(workoutId)
                "resume" -> Resume(workoutId)
                else -> null
            }
        }
    }
}
