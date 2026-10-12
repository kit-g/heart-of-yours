package me.heart

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.icu.text.MeasureFormat
import android.icu.util.Measure
import android.icu.util.MeasureUnit
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.widget.RemoteViews
import java.text.NumberFormat
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.roundToLong

/// The training widget (#161): a total and its bars, for what the user picks
/// in its settings — volume, workouts, time, sets or reps, or, while health is
/// on, resting heart rate, sleep, steps or body mass (#366) — over the last 7
/// days or the last 3 months. Small, a tile with the bars under the total;
/// wide, the bars beside it. Tapping opens the profile, where the same
/// training is charted.
///
/// Adding the widget is the opt-in: nothing in the app changes either way.
class TrainingWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
        scheduleMidnight(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val prefs = TrainingSnapshot.prefs(context)
        prefs.edit().apply { ids.forEach { remove(metricKey(it)); remove(rangeKey(it)) } }.apply()
    }

    companion object {
        private const val WIDE_DP = 250f

        fun metricKey(id: Int) = "metric.$id"
        fun rangeKey(id: Int) = "range.$id"

        /// What widget [id] shows of [snapshot]: what was picked, or volume
        /// for a health metric the app no longer publishes (health off, or
        /// forgotten), as if the health types had never been built.
        fun metric(context: Context, id: Int, snapshot: TrainingSnapshot): TrainingMetric {
            val stored = TrainingSnapshot.prefs(context).getString(metricKey(id), null)
            val picked = TrainingMetric.entries.firstOrNull { it.name == stored } ?: TrainingMetric.VOLUME
            return if (snapshot.offers(picked)) picked else TrainingMetric.VOLUME
        }

        fun range(context: Context, id: Int): TrainingRange {
            val stored = TrainingSnapshot.prefs(context).getString(rangeKey(id), null)
            return TrainingRange.entries.firstOrNull { it.name == stored } ?: TrainingRange.WEEK
        }

        /// Redraws every training widget on the Home Screen; none, nothing.
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, TrainingWidget::class.java))
                .forEach { update(context, manager, it) }
            scheduleMidnight(context)
        }

        /// The window moves on a day at midnight, with the app closed: an
        /// inexact alarm then redraws every widget, and the redraw sets the
        /// next. A date-change broadcast would be the natural cue, but it no
        /// longer reaches a receiver declared in the manifest.
        private fun scheduleMidnight(context: Context) {
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, TrainingWidget::class.java))
            val intent = Intent(context, TrainingWidget::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            val pending = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            if (ids.isEmpty()) {
                alarms.cancel(pending)
                return
            }
            val midnight = LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            alarms.set(AlarmManager.RTC, midnight, pending)
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val snapshot = TrainingSnapshot.read(TrainingSnapshot.prefs(context)) ?: TrainingSnapshot.EMPTY
            val metric = metric(context, id, snapshot)
            val range = range(context, id)
            val options = manager.getAppWidgetOptions(id)
            val views = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    // the launcher picks by the size the widget is drawn at
                    val small = SizeF(110f, 110f)
                    val wide = SizeF(WIDE_DP, 110f)
                    RemoteViews(
                        mapOf(
                            small to views(context, snapshot, metric, range, wide = false, size = sizeOf(options, wide = false)),
                            wide to views(context, snapshot, metric, range, wide = true, size = sizeOf(options, wide = true)),
                        ),
                    )
                }
                else -> {
                    val wide = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= WIDE_DP
                    views(context, snapshot, metric, range, wide, sizeOf(options, wide))
                }
            }
            manager.updateAppWidget(id, views)
        }

        /// The widget's size in dp, portrait: the launcher reports a range.
        private fun sizeOf(options: Bundle, wide: Boolean): SizeF {
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).takeIf { it > 0 }
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).takeIf { it > 0 }
            return SizeF(
                (width ?: if (wide) 320 else 160).toFloat().let { if (wide) max(it, WIDE_DP) else it },
                (height ?: 160).toFloat(),
            )
        }

        private fun views(
            context: Context,
            snapshot: TrainingSnapshot,
            metric: TrainingMetric,
            range: TrainingRange,
            wide: Boolean,
            size: SizeF,
        ): RemoteViews {
            val layout = if (wide) R.layout.widget_training_wide else R.layout.widget_training_small
            val views = RemoteViews(context.packageName, layout)
            val (bars, total) = snapshot.figures(metric, range, LocalDate.now())
            val averaged = metric.health?.averaged == true
            val locale = context.resources.configuration.locales[0]
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val accent = when {
                snapshot === TrainingSnapshot.EMPTY -> context.getColor(R.color.widget_secondary)
                night -> snapshot.accentDark
                else -> snapshot.accent
            }

            views.setTextViewText(R.id.widget_title, context.getString(metricTitle(metric)))
            views.setTextViewText(R.id.widget_value, formatted(context, total, metric, snapshot.imperial, locale))
            // 58 bpm is a day's, not the week's: the caption says so
            val caption = when (averaged) {
                true -> "${context.getString(R.string.widget_daily_average)} · ${context.getString(shortRangeTitle(range))}"
                false -> context.getString(rangeTitle(range))
            }
            views.setTextViewText(R.id.widget_caption, caption)

            // the bars take what the text leaves: beside it when wide, under it when not
            val density = context.resources.displayMetrics.density
            val (width, height) = when (wide) {
                true -> size.width - 32 - 140 - 16 to size.height - 32
                false -> size.width - 32 to size.height - 32 - 78
            }
            val chart = chart(
                bars,
                range,
                accent,
                context.getColor(R.color.widget_secondary),
                locale,
                (max(width, 60f) * density).roundToInt(),
                (max(height, 40f) * density).roundToInt(),
                density,
                relative = averaged,
            )
            views.setImageViewBitmap(R.id.widget_chart, chart)

            val open = Intent(Intent.ACTION_VIEW, Uri.parse("heart:///profile"), context, MainActivity::class.java)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )
            return views
        }

        fun metricTitle(metric: TrainingMetric) = when (metric) {
            TrainingMetric.VOLUME -> R.string.widget_volume
            TrainingMetric.WORKOUTS -> R.string.widget_workouts
            TrainingMetric.DURATION -> R.string.widget_duration
            TrainingMetric.SETS -> R.string.widget_sets
            TrainingMetric.REPS -> R.string.widget_reps
            TrainingMetric.RESTING_HEART_RATE -> R.string.widget_resting_heart_rate
            TrainingMetric.SLEEP -> R.string.widget_sleep
            TrainingMetric.STEPS -> R.string.widget_steps
            TrainingMetric.BODY_MASS -> R.string.widget_body_mass
        }

        fun rangeTitle(range: TrainingRange) = when (range) {
            TrainingRange.WEEK -> R.string.widget_last_week
            TrainingRange.QUARTER -> R.string.widget_last_quarter
        }

        private fun shortRangeTitle(range: TrainingRange) = when (range) {
            TrainingRange.WEEK -> R.string.widget_short_week
            TrainingRange.QUARTER -> R.string.widget_short_quarter
        }

        /// 617 lbs, 12, 3h 20m, 58 bpm, 81.4 kg: in the user's unit and
        /// locale; a dash for a health window without a reading.
        private fun formatted(context: Context, total: Double?, metric: TrainingMetric, imperial: Boolean, locale: Locale): String {
            val value = total ?: return "–"
            val numbers = NumberFormat.getIntegerInstance(locale)
            return when (metric) {
                TrainingMetric.VOLUME -> when (imperial) {
                    true -> "${numbers.format((value * 2.20462262).roundToLong())} ${context.getString(R.string.widget_lbs)}"
                    false -> "${numbers.format(value.roundToLong())} ${context.getString(R.string.widget_kg)}"
                }
                TrainingMetric.RESTING_HEART_RATE -> "${numbers.format(value.roundToLong())} ${context.getString(R.string.widget_bpm)}"
                TrainingMetric.STEPS -> numbers.format(value.roundToLong())
                TrainingMetric.BODY_MASS -> {
                    val tenths = NumberFormat.getNumberInstance(locale).apply {
                        minimumFractionDigits = 1
                        maximumFractionDigits = 1
                    }
                    when (imperial) {
                        true -> "${tenths.format(value * 2.20462262)} ${context.getString(R.string.widget_lbs)}"
                        false -> "${tenths.format(value)} ${context.getString(R.string.widget_kg)}"
                    }
                }
                TrainingMetric.DURATION, TrainingMetric.SLEEP -> {
                    // a night's sleep comes in minutes, a workout's time in seconds
                    val minutes = when (metric) {
                        TrainingMetric.SLEEP -> value.roundToLong()
                        else -> (value / 60).roundToLong()
                    }
                    val format = MeasureFormat.getInstance(locale, MeasureFormat.FormatWidth.NARROW)
                    when {
                        minutes >= 60 -> format.formatMeasures(
                            Measure(minutes / 60, MeasureUnit.HOUR),
                            Measure(minutes % 60, MeasureUnit.MINUTE),
                        )
                        else -> format.formatMeasures(Measure(minutes, MeasureUnit.MINUTE))
                    }
                }
                TrainingMetric.WORKOUTS, TrainingMetric.SETS, TrainingMetric.REPS -> numbers.format(value.roundToLong())
            }
        }

        /// The bars and their labels, drawn: a weekday under each day, or a
        /// month's initial under the week it begins in. An empty window draws
        /// a flat baseline.
        private fun chart(
            bars: List<TrainingBar>,
            range: TrainingRange,
            accent: Int,
            secondary: Int,
            locale: Locale,
            width: Int,
            height: Int,
            density: Float,
            /// Readings around a level (resting heart rate, body mass) are
            /// drawn from below the lowest, not from zero, where they'd all
            /// look the same height.
            relative: Boolean = false,
        ): Bitmap {
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = secondary
                textSize = 11 * density
                textAlign = Paint.Align.CENTER
            }
            val fill = Paint(Paint.ANTI_ALIAS_FLAG)
            val labels = 16 * density
            val gap = (if (range == TrainingRange.WEEK) 6 else 3) * density
            val slot = (width - gap * (bars.size - 1)) / bars.size
            val highest = bars.maxOf { it.value }
            val lowest = bars.map { it.value }.filter { it > 0 }.minOrNull() ?: 0.0
            val floor = if (relative) max(0.0, lowest - (highest - lowest)) else 0.0
            val area = height - labels
            bars.forEachIndexed { index, bar ->
                val left = index * (slot + gap)
                val share = when {
                    bar.value <= 0 -> 0.0
                    highest > floor -> (bar.value - floor) / (highest - floor)
                    else -> 1.0
                }
                val top = height - labels - max(3 * density, (area * share).toFloat())
                fill.color = if (bar.value > 0) accent else (secondary and 0x00FFFFFF) or 0x40000000
                canvas.drawRoundRect(RectF(left, top, left + slot, area), 3 * density, 3 * density, fill)
                label(bar, range, locale)?.let { canvas.drawText(it, left + slot / 2, height - 3 * density, text) }
            }
            return bitmap
        }

        private fun label(bar: TrainingBar, range: TrainingRange, locale: Locale): String? = when (range) {
            TrainingRange.WEEK -> bar.start.dayOfWeek.getDisplayName(TextStyle.NARROW, locale)
            TrainingRange.QUARTER -> (0L..6L).map { bar.start.plusDays(it) }
                .firstOrNull { it.dayOfMonth == 1 }
                ?.month?.getDisplayName(TextStyle.NARROW, locale)
        }
    }
}
