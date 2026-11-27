package me.heart

import android.app.AlarmManager
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
import java.time.LocalDate
import java.time.ZoneId

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
        scheduleMidnight(context)
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
            scheduleMidnight(context)
        }

        fun update(context: Context, manager: AppWidgetManager, id: Int) {
            val templates = templates(context)
            val enabled = enabled(context)
            val accent = accent(context)
            val small = small(context, id, picked(choice(context, id), templates), enabled, accent)
            val notToday = NotToday.words(ShortcutsStore.prefs(context))
            val wide = wide(context, id, templates, enabled, accent, notToday, NotToday.today())
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

        /// The wide widget's templates: three, or two with "Not today" (#445)
        /// taking the last tile.
        fun room(notToday: Boolean): Int = if (notToday) 2 else 3

        /// "Start a workout" first, then the templates; fewer templates, fewer
        /// tiles, and an empty second row is gone. While "Not today" can be
        /// asked for (#445) the tile after the templates is its: a tap sets
        /// today aside with nothing opened, and once the day is set aside the
        /// tile says so and takes no tap.
        private fun wide(
            context: Context,
            id: Int,
            templates: List<Template>,
            enabled: Boolean,
            accent: WidgetColor,
            notToday: NotToday.Words?,
            today: String,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_start_wide)
            val entries = listOf<Template?>(null) + templates.take(room(notToday != null))
            tiles.forEachIndexed { index, tile ->
                val entry = entries.getOrNull(index)
                when {
                    index < entries.size -> {
                        views.setViewVisibility(tile.root, View.VISIBLE)
                        views.setTextViewText(tile.label, entry?.name ?: context.getString(R.string.widget_start_workout))
                        badge(context, views, tile.badge, tile.icon, entry != null, accent)
                        views.setOnClickPendingIntent(tile.root, tap(context, id * 8 + 1 + index, link(enabled, entry?.id)))
                    }
                    index == entries.size && notToday != null -> {
                        val aside = notToday.day == today
                        views.setViewVisibility(tile.root, View.VISIBLE)
                        views.setTextViewText(tile.label, if (aside) notToday.done else notToday.label)
                        accent.set(context, views, tile.badge, "setColorFilter")
                        views.setImageViewResource(tile.icon, if (aside) R.drawable.widget_done else R.drawable.widget_not_today)
                        // set either way: the launcher lays these views over the ones it
                        // holds, and a tile left alone keeps the last tap it was given
                        views.setOnClickPendingIntent(tile.root, if (aside) null else notTodayTap(context))
                    }
                    else -> views.setViewVisibility(tile.root, View.GONE)
                }
            }
            val shown = entries.size + (if (notToday != null) 1 else 0)
            views.setViewVisibility(R.id.widget_row1, if (shown > 2) View.VISIBLE else View.GONE)
            return views
        }

        private fun notTodayTap(context: Context): PendingIntent {
            val ask = Intent(context, NotTodayReceiver::class.java)
            return PendingIntent.getBroadcast(context, 0, ask, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        /// A day set aside is over at midnight, with the app closed: an
        /// inexact alarm then redraws the widgets, as the training widget's
        /// does, so the tile offers "Not today" again. Set only while a day
        /// is marked, and none with no widget placed.
        private fun scheduleMidnight(context: Context) {
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, StartWidget::class.java))
            val intent = Intent(context, StartWidget::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            val pending = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            val alarms = context.getSystemService(AlarmManager::class.java) ?: return
            val marked = NotToday.words(ShortcutsStore.prefs(context))?.day == NotToday.today()
            if (ids.isEmpty() || !marked) {
                alarms.cancel(pending)
                return
            }
            val midnight = LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
            alarms.set(AlarmManager.RTC, midnight, pending)
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
