package me.heart

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/// What the training widget (#161) counts. The ordinal is the index into a
/// day's totals as Dart publishes them.
enum class TrainingMetric { VOLUME, WORKOUTS, DURATION, SETS, REPS }

/// The widget's window: the last 7 days, a bar each, or the last 13 weeks
/// from a Monday, a bar each — the app's weeks start on Monday everywhere.
enum class TrainingRange { WEEK, QUARTER }

/// One bar: the day or week it starts on, and its total.
data class TrainingBar(val start: LocalDate, val value: Double)

/// What the training widget draws from: the user's finished workouts per day,
/// as Dart counted them and published over `heart/widgets`. The widget picks
/// its own window from the days and today's date, so the bars roll over at
/// midnight with the app closed. Training totals only: nothing read from
/// Health Connect.
data class TrainingSnapshot(
    val imperial: Boolean,
    val accent: Int,
    val accentDark: Int,
    /// `yyyy-MM-dd` => `[volume kg, workouts, seconds, sets, reps]`.
    val days: Map<String, List<Double>>,
) {
    /// The bars of [range] ending [today], oldest first, in the stored units.
    fun bars(metric: TrainingMetric, range: TrainingRange, today: LocalDate): List<TrainingBar> {
        return when (range) {
            TrainingRange.WEEK -> (6 downTo 0).map { back ->
                val day = today.minusDays(back.toLong())
                TrainingBar(day, value(metric, day))
            }
            TrainingRange.QUARTER -> {
                val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                (12 downTo 0).map { back ->
                    val start = monday.minusWeeks(back.toLong())
                    TrainingBar(start, (0L..6L).sumOf { value(metric, start.plusDays(it)) })
                }
            }
        }
    }

    private fun value(metric: TrainingMetric, day: LocalDate): Double {
        return days[day.toString()]?.getOrNull(metric.ordinal) ?: 0.0
    }

    companion object {
        private const val FILE = "heart.widgets"
        private const val KEY = "training"

        /// Nobody's training: zeros.
        val EMPTY = TrainingSnapshot(imperial = false, accent = 0, accentDark = 0, days = emptyMap())

        fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

        /// From what Dart sends; null for anything it doesn't recognise.
        fun parse(json: JSONObject): TrainingSnapshot? = runCatching {
            val days = json.getJSONObject("days")
            TrainingSnapshot(
                imperial = when (json.getString("unit")) {
                    "imperial" -> true
                    "metric" -> false
                    else -> return null
                },
                accent = json.getLong("accent").toInt(),
                accentDark = json.getLong("accentDark").toInt(),
                days = days.keys().asSequence().associateWith { day ->
                    val totals = days.getJSONArray(day)
                    (0 until totals.length()).map { totals.getDouble(it) }
                },
            )
        }.getOrNull()

        fun read(prefs: SharedPreferences): TrainingSnapshot? {
            val stored = prefs.getString(KEY, null) ?: return null
            return runCatching { parse(JSONObject(stored)) }.getOrNull()
        }

        /// Keeps what Dart sent as JSON, or forgets it; answers whether
        /// anything changed, so the widgets redraw only when there is
        /// something to redraw.
        fun write(prefs: SharedPreferences, map: Map<*, *>?): Boolean {
            val encoded = map?.let { JSONObject(it) }?.takeIf { parse(it) != null }?.toString()
            if (encoded == prefs.getString(KEY, null)) return false
            prefs.edit().apply {
                if (encoded == null) remove(KEY) else putString(KEY, encoded)
            }.apply()
            return true
        }
    }
}
