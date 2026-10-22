package me.heart.wear

import android.content.ComponentName
import android.content.Context
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import org.json.JSONObject

/// What the Tile and the watch-face complication show (#463) — the twin of
/// ios/Watch/ComplicationSnapshot.swift: where the workout is, never what the
/// body is doing. Nothing health-related is ever in it.
///
/// Written by the app whenever what it shows changes something these draw, and
/// by [StateListenerService] when the phone's state arrives with the app closed.
data class Snapshot(
    val exercise: String,
    val next: String,
    val restStart: Long?,
    val restEnd: Long?,
    val restLabel: String?,
) {
    /// The rest, while one is set; when it is over is the reader's to check.
    val rest: LongRange? get() = if (restStart != null && restEnd != null && restStart < restEnd) restStart..restEnd else null

    companion object {
        private const val PREFS = "complication"
        private const val KEY = "snapshot"

        /// What [state] gives the watch face: the workout in progress, or
        /// nothing — idle, switched off, or never set up.
        fun of(state: PhoneState): Snapshot? = (state as? PhoneState.Workout)?.let {
            Snapshot(it.exercise, it.next, it.rest?.start, it.rest?.end, it.rest?.label)
        }

        fun read(context: Context): Snapshot? {
            val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null) ?: return null
            val json = runCatching { JSONObject(stored) }.getOrNull() ?: return null
            return Snapshot(
                exercise = json.optString("exercise"),
                next = json.optString("next"),
                restStart = json.optLong("restStart").takeIf { it > 0 },
                restEnd = json.optLong("restEnd").takeIf { it > 0 },
                restLabel = json.optString("restLabel").ifEmpty { null },
            )
        }

        /// Stores [snapshot], or clears it, and has the Tile and the
        /// complication redrawn only when that changed anything: the system
        /// budgets their updates.
        fun write(context: Context, snapshot: Snapshot?) {
            // the updaters bind to the services, which a receiver's own context may not
            val context = context.applicationContext
            if (read(context) == snapshot) return
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            when (snapshot) {
                null -> prefs.remove(KEY)
                else -> prefs.putString(
                    KEY,
                    JSONObject()
                        .put("exercise", snapshot.exercise)
                        .put("next", snapshot.next)
                        .putOpt("restStart", snapshot.restStart)
                        .putOpt("restEnd", snapshot.restEnd)
                        .putOpt("restLabel", snapshot.restLabel)
                        .toString(),
                )
            }
            prefs.apply()
            TileService.getUpdater(context).requestUpdate(HeartTileService::class.java)
            ComplicationDataSourceUpdateRequester
                .create(context, ComponentName(context, HeartComplicationService::class.java))
                .requestUpdateAll()
        }
    }
}
