package me.heart

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioButton
import android.widget.RadioGroup

/// The Goals widget's settings (#368): which goal the small widget shows.
/// Shown on long-pressing the widget (it is `reconfigurable`), and skipped
/// when the widget is added (`configuration_optional`), which shows the goal
/// closest to done until the user picks otherwise.
class GoalsWidgetSettings : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // backing out keeps the widget as it was
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        setContentView(R.layout.widget_goals_settings)
        val group = findViewById<RadioGroup>(R.id.widget_choices)
        val goals = GoalsWidget.goals(this)
        goals.forEachIndexed { index, goal -> group.addView(choice(CHOICES + index, goal.title)) }
        val picked = GoalsWidget.picked(GoalsWidget.pick(this, widgetId), goals)
        group.check(CHOICES + goals.indexOf(picked).coerceAtLeast(0))

        findViewById<Button>(R.id.widget_done).setOnClickListener {
            goals.getOrNull(group.checkedRadioButtonId - CHOICES)?.let { goal ->
                GoalsWidget.prefs(this).edit().putString(GoalsWidget.pickKey(widgetId), goal.id).apply()
            }
            GoalsWidget.update(this, AppWidgetManager.getInstance(this), widgetId)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun choice(viewId: Int, title: String): RadioButton {
        return RadioButton(this).apply {
            id = viewId
            text = title
            textSize = 16f
            minHeight = (48 * resources.displayMetrics.density).toInt()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

    private companion object {
        /// View ids of the choices: an offset plus the index.
        const val CHOICES = 0x1000
    }
}
