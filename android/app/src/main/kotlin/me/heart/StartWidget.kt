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

/// The Start widget (#367): one tap from the Home Screen into a workout.
/// Small, the whole widget starts one thing — the template picked in its
/// settings, the first one until then, or an empty workout; wide, "Start a
/// workout" and up to three templates, each its own tap. Every tap opens the
/// links the launcher's shortcuts do (#286), so the app decides what happens;
/// with the Shortcuts feature off, the workout tab instead.
///
/// The templates are what Dart publishes over `heart/shortcuts`, kept in
/// [ShortcutsStore]. Adding the widget is the opt-in: nothing in the app
/// changes either way.
class StartWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        update(context, manager, id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        prefs(context).edit().apply { ids.forEach { remove(choiceKey(it)) } }.apply()
    }

    /// A template as published: its id and the name the user gave it.
    data class Template(val id: String, val name: String)

    companion object {
        private const val WIDE_DP = 250f
        private const val FILE = "heart.widgets.start"

        /// The small widget's pick: a template's id, or [EMPTY] for an empty
        /// workout; absent, the first template.
        const val EMPTY = ""

        fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

        fun choiceKey(id: Int) = "choice.$id"

        fun choice(context: Context, id: Int): String? = prefs(context).getString(choiceKey(id), null)

        /// What Dart last published: the user's own templates, then the samples.
        fun templates(context: Context): List<Template> {
            val list = ShortcutsStore.array(ShortcutsStore.prefs(context), ShortcutsStore.TEMPLATES) ?: return emptyList()
            return (0 until list.length()).mapNotNull { index ->
                val entry = list.optJSONObject(index) ?: return@mapNotNull null
                val id = entry.optString("id").takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                val name = entry.optString("name").takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                Template(id, name)
            }
        }

        /// Whether `heart://app/start` starts anything; off, the feature's link
        /// is an unknown route (#284).
        private fun enabled(context: Context): Boolean {
            return ShortcutsStore.string(ShortcutsStore.prefs(context), ShortcutsStore.ENABLED) == "true"
        }

        /// The small widget's template: the picked one while the app still
        /// publishes it, else the first; null for an empty workout.
        fun picked(choice: String?, templates: List<Template>): Template? = when (choice) {
            EMPTY -> null
            null -> templates.firstOrNull()
            else -> templates.firstOrNull { it.id == choice } ?: templates.firstOrNull()
        }

        /// Where a tap goes: a template's start link, a blank workout's for
        /// none — or, with the feature off, the workout tab, so that the tap
        /// still lands somewhere a workout can be started.
        fun link(enabled: Boolean, template: String?): Uri = when {
            !enabled -> Uri.parse("heart:///workout")
            template == null -> Uri.parse("heart://app/start")
            else -> Uri.parse("heart://app/start").buildUpon().appendQueryParameter("template", template).build()
        }

        /// Redraws every Start widget on the Home Screen; none, nothing.
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            manager.getAppWidgetIds(ComponentName(context, StartWidget::class.java))
                .forEach { update(context, manager, it) }
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val templates = templates(context)
            val enabled = enabled(context)
            val accent = accent(context)
            val small = small(context, id, picked(choice(context, id), templates), enabled, accent)
            val wide = wide(context, id, templates.take(3), enabled, accent)
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

        /// The theme's accent, as the training widget draws it; before the
        /// app has said, the ink.
        private fun accent(context: Context) =
            WidgetColor.accent(TrainingSnapshot.read(TrainingSnapshot.prefs(context)), R.color.widget_text)

        private fun small(context: Context, id: Int, template: Template?, enabled: Boolean, accent: WidgetColor): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_start_small)
            views.setTextViewText(R.id.widget_title, template?.name ?: context.getString(R.string.widget_start_workout))
            // a template's name says what; the caption says it starts
            views.setViewVisibility(R.id.widget_caption, if (template == null) View.GONE else View.VISIBLE)
            badge(context, views, R.id.widget_badge, R.id.widget_icon, template != null, accent)
            views.setOnClickPendingIntent(R.id.widget_root, tap(context, id * 8, link(enabled, template?.id)))
            return views
        }

        private val tiles = listOf(
            Tile(R.id.widget_tile0, R.id.widget_badge0, R.id.widget_icon0, R.id.widget_label0),
            Tile(R.id.widget_tile1, R.id.widget_badge1, R.id.widget_icon1, R.id.widget_label1),
            Tile(R.id.widget_tile2, R.id.widget_badge2, R.id.widget_icon2, R.id.widget_label2),
            Tile(R.id.widget_tile3, R.id.widget_badge3, R.id.widget_icon3, R.id.widget_label3),
        )

        private data class Tile(val root: Int, val badge: Int, val icon: Int, val label: Int)

        /// "Start a workout" first, then the templates; fewer templates, fewer
        /// tiles, and an empty second row is gone.
        private fun wide(context: Context, id: Int, templates: List<Template>, enabled: Boolean, accent: WidgetColor): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_start_wide)
            val entries = listOf<Template?>(null) + templates
            tiles.forEachIndexed { index, tile ->
                val entry = entries.getOrNull(index)
                when {
                    index >= entries.size -> views.setViewVisibility(tile.root, View.GONE)
                    else -> {
                        views.setViewVisibility(tile.root, View.VISIBLE)
                        views.setTextViewText(tile.label, entry?.name ?: context.getString(R.string.widget_start_workout))
                        badge(context, views, tile.badge, tile.icon, entry != null, accent)
                        views.setOnClickPendingIntent(tile.root, tap(context, id * 8 + 1 + index, link(enabled, entry?.id)))
                    }
                }
            }
            views.setViewVisibility(R.id.widget_row1, if (entries.size > 2) View.VISIBLE else View.GONE)
            return views
        }

        private fun badge(context: Context, views: RemoteViews, badge: Int, icon: Int, template: Boolean, accent: WidgetColor) {
            accent.set(context, views, badge, "setColorFilter")
            views.setImageViewResource(icon, if (template) R.drawable.widget_start_dumbbell else R.drawable.widget_start_plus)
        }

        private fun tap(context: Context, request: Int, link: Uri): PendingIntent {
            val open = Intent(Intent.ACTION_VIEW, link, context, MainActivity::class.java)
            return PendingIntent.getActivity(context, request, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }
    }
}
