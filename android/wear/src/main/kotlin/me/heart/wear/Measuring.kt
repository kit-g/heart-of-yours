package me.heart.wear

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/// What the watch is measuring for the workout on the phone (#461), as
/// [WorkoutService] reads it from Health Services, for the page to show.
///
/// These live readings stay on the wrist: never in the Data Layer, logs, or
/// anything the phone shows (`docs/2026-09-05.health-data.md`). *That* the
/// watch measures crosses over — the phone's cue to leave the rest's tap to
/// it — and, after the workout and only with the user's say, the session's
/// readings go to the phone for Health Connect ([Readings]).
object Measuring {
    data class Reading(
        val workoutId: String,
        /// Beats per minute, as the watch last measured it; null before the
        /// first reading.
        val heartRate: Double? = null,
        /// Energy since the session began, in kilocalories.
        val energy: Double? = null,
    )

    private val _now = MutableStateFlow<Reading?>(null)

    /// The session running, with what it read last; null without one.
    val now: StateFlow<Reading?> = _now.asStateFlow()

    internal fun started(workoutId: String) {
        _now.value = Reading(workoutId)
    }

    internal fun read(heartRate: Double?, energy: Double?) {
        val current = _now.value ?: return
        _now.value = current.copy(heartRate = heartRate ?: current.heartRate, energy = energy ?: current.energy)
    }

    internal fun ended() {
        _now.value = null
    }
}
