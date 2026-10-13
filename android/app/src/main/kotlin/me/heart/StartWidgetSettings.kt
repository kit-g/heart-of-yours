package me.heart

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.RadioButton
import android.widget.RadioGroup

/// The Start widget's settings (#367): what the small widget starts — a
/// template, or an empty workout. Shown on long-pressing the widget (it is
/// `reconfigurable`), and skipped when the widget is added
/// (`configuration_optional`), which starts the first template until the user
/// picks otherwise.
class StartWidgetSettings : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        // backing out keeps the widget as it was
        setResult(RESULT_CANCELED, result())
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        setContentView(R.layout.widget_start_settings)
        val group = findViewById<RadioGroup>(R.id.widget_choices)
        val templates = StartWidget.templates(this)
        // the templates, then the empty workout, as the iOS edit sheet lists them
        val choices = templates.map { it.id to it.name } + (StartWidget.EMPTY to getString(R.string.widget_empty_workout))
        choices.forEachIndexed { index, (_, name) -> group.addView(choice(CHOICES + index, name)) }
        val picked = StartWidget.picked(StartWidget.choice(this, widgetId), templates)?.id ?: StartWidget.EMPTY
        group.check(CHOICES + choices.indexOfFirst { it.first == picked }.coerceAtLeast(0))

        findViewById<Button>(R.id.widget_done).setOnClickListener {
            val choice = choices.getOrNull(group.checkedRadioButtonId - CHOICES)?.first ?: StartWidget.EMPTY
            StartWidget.prefs(this).edit().putString(StartWidget.choiceKey(widgetId), choice).apply()
            StartWidget.update(this, AppWidgetManager.getInstance(this), widgetId)
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
