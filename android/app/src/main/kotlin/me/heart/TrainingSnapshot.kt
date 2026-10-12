package me.heart

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

/// What the training widget (#161) counts: the training, by its index into a
/// day's totals as Dart publishes them, or a health metric (#366), by the key
/// Dart publishes it under.
enum class TrainingMetric(val index: Int?, val health: HealthKind?) {
    VOLUME(0, null),
    WORKOUTS(1, null),
    DURATION(2, null),
    SETS(3, null),
    REPS(4, null),
    RESTING_HEART_RATE(null, HealthKind.RESTING_HEART_RATE),
    SLEEP(null, HealthKind.SLEEP),
    STEPS(null, HealthKind.STEPS),
    BODY_MASS(null, HealthKind.BODY_MASS),
}

/// A health data type the widget can show (#366), by the key Dart publishes it
/// under: a reading a day for resting heart rate and body mass, a night's
/// sleep in minutes, the day's steps. All but steps come to their days'
/// average, not their sum: a week of resting heart rates adds up to nothing.
enum class HealthKind(val key: String, val averaged: Boolean) {
    RESTING_HEART_RATE("restingHeartRate", true),
    SLEEP("sleepAsleep", true),
    STEPS("steps", false),
    BODY_MASS("bodyMass", true),
}

/// The widget's window: the last 7 days, a bar each, or the last 13 weeks
/// from a Monday, a bar each — the app's weeks start on Monday everywhere.
enum class TrainingRange { WEEK, QUARTER }

/// One bar: the day or week it starts on, and its total.
data class TrainingBar(val start: LocalDate, val value: Double)

/// What the training widget draws from: the user's finished workouts per day,
/// as Dart counted them and published over `heart/widgets`. The widget picks
/// its own window from the days and today's date, so the bars roll over at
/// midnight with the app closed. And, while the app's health mirror has them,
/// the health metrics the widget can show instead (#366): device-only, drawn
/// on the Home Screen and never on the lock screen.
data class TrainingSnapshot(
    val imperial: Boolean,
    val accent: Int,
    val accentDark: Int,
    /// `yyyy-MM-dd` => `[volume kg, workouts, seconds, sets, reps]`.
    val days: Map<String, List<Double>>,
    /// [HealthKind.key] => `yyyy-MM-dd` => the day's value; a kind absent,
    /// nothing of it to offer.
    val health: Map<String, Map<String, Double>> = emptyMap(),
) {
    /// Whether the widget may show [metric]: the training always, a health
    /// metric only while the app publishes it.
    fun offers(metric: TrainingMetric): Boolean = metric.health?.let { it.key in health } ?: true

    /// [metric]'s bars over [range] ending [today] and the figure the window
    /// comes to: training and steps summed, the rest averaged over the days
    /// with a reading. Null for a health window without a single reading.
    fun figures(metric: TrainingMetric, range: TrainingRange, today: LocalDate): Pair<List<TrainingBar>, Double?> {
        val kind = metric.health ?: return bars(metric, range, today).let { it to it.sumOf { bar -> bar.value } }
        val readings = health[kind.key].orEmpty()
        fun reading(day: LocalDate) = readings[day.toString()]
        fun combined(values: List<Double>): Double? = when {
            values.isEmpty() -> null
            kind.averaged -> values.average()
            else -> values.sum()
        }
        return when (range) {
            TrainingRange.WEEK -> {
                val days = (6 downTo 0).map { today.minusDays(it.toLong()) }
                days.map { TrainingBar(it, reading(it) ?: 0.0) } to combined(days.mapNotNull(::reading))
            }
            TrainingRange.QUARTER -> {
                val weeks = weeks(today)
                val bars = weeks.map { start -> TrainingBar(start, combined(week(start).mapNotNull(::reading)) ?: 0.0) }
                val days = weeks.flatMap(::week).filter { !it.isAfter(today) }
                bars to combined(days.mapNotNull(::reading))
            }
        }
    }

    /// The bars of [range] ending [today], oldest first, in the stored units.
    fun bars(metric: TrainingMetric, range: TrainingRange, today: LocalDate): List<TrainingBar> {
        return when (range) {
            TrainingRange.WEEK -> (6 downTo 0).map { back ->
                val day = today.minusDays(back.toLong())
                TrainingBar(day, value(metric, day))
            }
            TrainingRange.QUARTER -> weeks(today).map { start ->
                TrainingBar(start, week(start).sumOf { value(metric, it) })
            }
        }
    }

    private fun value(metric: TrainingMetric, day: LocalDate): Double {
        val index = metric.index ?: return 0.0
        return days[day.toString()]?.getOrNull(index) ?: 0.0
    }

    /// The Mondays of the 13 weeks ending with [today]'s, oldest first.
    private fun weeks(today: LocalDate): List<LocalDate> {
        val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
        return (12 downTo 0).map { monday.minusWeeks(it.toLong()) }
    }

    /// The seven days of the week that begins on [start].
    private fun week(start: LocalDate): List<LocalDate> = (0L..6L).map { start.plusDays(it) }

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
                health = json.optJSONObject("health")?.let { health ->
                    health.keys().asSequence().associateWith { kind ->
                        val readings = health.getJSONObject(kind)
                        readings.keys().asSequence().associateWith { readings.getDouble(it) }
                    }
                } ?: emptyMap(),
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
