package me.heart

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioButton
import android.widget.RadioGroup

/// The training widget's settings (#161): what it counts and over what
/// window. Shown on long-pressing the widget (it is `reconfigurable`), and
/// skipped when the widget is added (`configuration_optional`), which draws
/// the last 7 days' volume until the user picks otherwise.
class TrainingWidgetSettings : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // backing out keeps the widget as it was
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        setContentView(R.layout.widget_training_settings)
        val metrics = findViewById<RadioGroup>(R.id.widget_metrics)
        val ranges = findViewById<RadioGroup>(R.id.widget_ranges)
        TrainingMetric.entries.forEach { metric ->
            metrics.addView(choice(METRICS + metric.ordinal, TrainingWidget.metricTitle(metric)))
        }
        TrainingRange.entries.forEach { range ->
            ranges.addView(choice(RANGES + range.ordinal, TrainingWidget.rangeTitle(range)))
        }
        metrics.check(TrainingWidget.metric(this, widgetId).ordinal + METRICS)
        ranges.check(TrainingWidget.range(this, widgetId).ordinal + RANGES)

        findViewById<Button>(R.id.widget_done).setOnClickListener {
            val metric = TrainingMetric.entries[metrics.checkedRadioButtonId - METRICS]
            val range = TrainingRange.entries[ranges.checkedRadioButtonId - RANGES]
            TrainingSnapshot.prefs(this).edit()
                .putString(TrainingWidget.metricKey(widgetId), metric.name)
                .putString(TrainingWidget.rangeKey(widgetId), range.name)
                .apply()
            TrainingWidget.update(this, AppWidgetManager.getInstance(this), widgetId)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun choice(viewId: Int, title: Int): RadioButton {
        return RadioButton(this).apply {
            id = viewId
            setText(title)
            textSize = 16f
            minHeight = (48 * resources.displayMetrics.density).toInt()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    private companion object {
        /// View ids of the choices: an offset per group, plus the ordinal.
        const val METRICS = 0x1000
        const val RANGES = 0x2000
    }
}
