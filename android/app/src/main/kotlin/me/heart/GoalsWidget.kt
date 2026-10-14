package me.heart

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/// The Goals widget (#368): the user's active goals and how close each is, as
/// the profile's Goals card shows them. Small, one goal — the one picked in its
/// settings, the closest to done until then; wide, up to three. With no active
/// goal it says what a goal would show, and a tap opens the goals.
///
/// The goals' words are Dart's, published over `heart/widgets` in the app's
/// language. Adding the widget is the opt-in: nothing in the app changes
/// either way.
class GoalsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        prefs(context).edit().apply { ids.forEach { remove(pickKey(it)) } }.apply()
    }

    /// A goal as Dart published it.
    data class Goal(val id: String, val title: String, val status: String, val progress: Double)

    companion object {
        private const val WIDE_DP = 250f
        private const val FILE = "heart.widgets.goals"
        private const val GOALS = "goals"

        fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

        fun pickKey(id: Int) = "pick.$id"

        fun pick(context: Context, id: Int): String? = prefs(context).getString(pickKey(id), null)

        /// Keeps what Dart sent, or forgets it for nobody's goals; answers
        /// whether anything changed.
        fun write(prefs: SharedPreferences, map: Map<*, *>?): Boolean {
            val encoded = map?.let { JSONObject(it).toString() }
            if (encoded == prefs.getString(GOALS, null)) return false
            prefs.edit().apply { if (encoded == null) remove(GOALS) else putString(GOALS, encoded) }.apply()
            return true
        }

        /// The active goals, closest to done first; none when there are
        /// nobody's to show.
        fun goals(context: Context): List<Goal> = parse(prefs(context).getString(GOALS, null))

        fun parse(json: String?): List<Goal> {
            val list = runCatching { JSONObject(json ?: return emptyList()).optJSONArray("goals") }.getOrNull() ?: return emptyList()
            return (0 until list.length()).mapNotNull { index ->
                val entry = list.optJSONObject(index) ?: return@mapNotNull null
                Goal(
                    id = entry.optString("id"),
                    title = entry.optString("title"),
                    status = entry.optString("status"),
                    progress = entry.optDouble("progress", 0.0).coerceIn(0.0, 1.0),
                )
            }
        }

        /// The small widget's goal: the picked one while it is still active,
        /// else the closest to done.
        fun picked(pick: String?, goals: List<Goal>): Goal? = goals.firstOrNull { it.id == pick } ?: goals.firstOrNull()

        /// Redraws every Goals widget on the Home Screen; none, nothing.
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, GoalsWidget::class.java))
                .forEach { update(context, manager, it) }
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val goals = goals(context)
            val small = views(context, listOfNotNull(picked(pick(context, id), goals)), titleLines = 3)
            val wide = views(context, goals.take(3), titleLines = 1)
            val views = when {
                // the launcher picks by the size the widget is drawn at
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> RemoteViews(
                    mapOf(SizeF(110f, 110f) to small, SizeF(WIDE_DP, 110f) to wide),
                )
                else -> when (manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) >= WIDE_DP) {
                    true -> wide
                    false -> small
                }
            }
            manager.updateAppWidget(id, views)
        }

        private val rows = listOf(
            Row(R.id.widget_goal0, R.id.widget_goal_title0, R.id.widget_goal_status0, R.id.widget_goal_bar0),
            Row(R.id.widget_goal1, R.id.widget_goal_title1, R.id.widget_goal_status1, R.id.widget_goal_bar1),
            Row(R.id.widget_goal2, R.id.widget_goal_title2, R.id.widget_goal_status2, R.id.widget_goal_bar2),
        )

        private data class Row(val root: Int, val title: Int, val status: Int, val bar: Int)

        private fun views(context: Context, goals: List<Goal>, titleLines: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_goals)
            val accent = accent(context)
            rows.forEachIndexed { index, row ->
                when (val goal = goals.getOrNull(index)) {
                    null -> views.setViewVisibility(row.root, View.GONE)
                    else -> {
                        views.setViewVisibility(row.root, View.VISIBLE)
                        views.setTextViewText(row.title, goal.title)
                        views.setInt(row.title, "setMaxLines", titleLines)
                        views.setTextViewText(row.status, goal.status)
                        // a sliver even at nothing, so the bar reads as a bar
                        views.setProgressBar(row.bar, 1000, maxOf(20, (goal.progress * 1000).toInt()), false)
                        accent.setList(views, row.bar, "setProgressTintList")
                    }
                }
            }
            // no active goal: what one would show, and the way to add it
            val empty = if (goals.isEmpty()) View.VISIBLE else View.GONE
            views.setViewVisibility(R.id.widget_goals_empty, empty)
            views.setViewVisibility(R.id.widget_add_goal, empty)
            accent.set(context, views, R.id.widget_add_goal, "setTextColor")

            val open = Intent(Intent.ACTION_VIEW, Uri.parse("heart:///profile"), context, MainActivity::class.java)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(context, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )
            return views
        }

        /// The theme's accent, as the training widget draws it; before the
        /// app has said, the ink.
        private fun accent(context: Context) =
            WidgetColor.accent(TrainingSnapshot.read(TrainingSnapshot.prefs(context)), R.color.widget_text)
    }
}
