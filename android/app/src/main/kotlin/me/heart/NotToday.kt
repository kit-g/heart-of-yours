package me.heart

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/// "Not today" asked for outside the app (#445): from the Start widget's
/// tile and from the launcher's item, without the app coming to the front.
///
/// Nothing here writes a skip: Dart is the only writer, as for every second
/// actor (#141). This keeps the moment it was asked, in [ShortcutsStore],
/// until Dart takes it — at once while the app's engine is up to be told,
/// else when the app next comes to the front — and marks the day in what
/// Dart published meanwhile, so the widget and a second ask already say the
/// day is set aside.
///
/// There is something to ask only while Dart publishes the words for it:
/// with the feature on (`Feature.notToday`), someone signed in and no workout
/// running. Otherwise the tile and the launcher's item are not there.
object NotToday {
    /// What Dart publishes: the tile's and the item's label, what they say
    /// once the day is set aside, and the device's day ("2026-11-26") that
    /// already is, if one is.
    data class Words(val label: String, val done: String, val day: String?)

    enum class Outcome { SET_ASIDE, ALREADY, OFF }

    /// What an ask came to: the outcome, the words as they now stand, and
    /// the moments still waiting for Dart.
    data class Asked(val outcome: Outcome, val words: Words?, val pending: List<Long>)

    @Volatile
    private var live: MethodChannel? = null

    /// The running engine's `heart/shortcuts` channel, while it runs.
    fun attach(channel: MethodChannel) {
        live = channel
    }

    fun detach(channel: MethodChannel) {
        if (live === channel) live = null
    }

    fun today(): String = LocalDate.now().toString()

    fun dayOf(millis: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate().toString()

    fun words(stored: JSONObject?): Words? {
        val label = stored?.optString("label")?.takeIf { it.isNotEmpty() } ?: return null
        val done = stored.optString("done").takeIf { it.isNotEmpty() } ?: return null
        return Words(label, done, stored.optString("day").takeIf { it.isNotEmpty() })
    }

    fun words(prefs: SharedPreferences): Words? = words(ShortcutsStore.obj(prefs, ShortcutsStore.NOT_TODAY))

    fun pending(stored: JSONArray?): List<Long> {
        if (stored == null) return emptyList()
        return (0 until stored.length()).map { stored.optLong(it) }.filter { it > 0 }
    }

    /// One ask, on its own: with nothing published it is off; on a day
    /// already set aside it changes nothing; otherwise the moment joins
    /// [pending] and [today] is marked.
    fun ask(words: Words?, pending: List<Long>, now: Long, today: String): Asked = when {
        words == null -> Asked(Outcome.OFF, null, pending)
        words.day == today -> Asked(Outcome.ALREADY, words, pending)
        else -> Asked(Outcome.SET_ASIDE, words.copy(day = today), pending + now)
    }

    /// What Dart published, as it is kept: a moment asked for and not yet
    /// taken is one Dart does not know of, so its day stays marked until
    /// Dart, having recorded it, says so itself.
    fun published(published: Map<*, *>?, pending: List<Long>, today: String, dayOf: (Long) -> String): Words? {
        val label = published?.get("label") as? String ?: return null
        val done = published["done"] as? String ?: return null
        val day = published["day"] as? String
        return Words(label, done, day ?: today.takeIf { pending.any { moment -> dayOf(moment) == today } })
    }

    fun store(prefs: SharedPreferences, words: Words?) {
        ShortcutsStore.put(
            prefs,
            ShortcutsStore.NOT_TODAY,
            words?.let { mapOf("label" to it.label, "done" to it.done) + (it.day?.let { day -> mapOf("day" to day) } ?: emptyMap()) },
        )
    }

    /// Keeps what Dart published and redraws what shows it.
    fun publish(context: Context, published: Map<*, *>?) {
        val prefs = ShortcutsStore.prefs(context)
        val waiting = pending(ShortcutsStore.array(prefs, ShortcutsStore.PENDING_SKIPS))
        store(prefs, published(published, waiting, today(), ::dayOf))
        StartWidget.updateAll(context)
    }

    /// The moments kept, oldest first, in milliseconds since 1970; asking
    /// clears them.
    fun take(context: Context): List<Long> {
        val prefs = ShortcutsStore.prefs(context)
        val kept = pending(ShortcutsStore.array(prefs, ShortcutsStore.PENDING_SKIPS))
        ShortcutsStore.put(prefs, ShortcutsStore.PENDING_SKIPS, null)
        return kept
    }

    /// Sets today aside, as far as this side goes: keeps the moment, marks
    /// the day, redraws the widget, and tells Dart if it is there to hear.
    fun ask(context: Context): Asked {
        val prefs = ShortcutsStore.prefs(context)
        val asked = ask(
            words(prefs),
            pending(ShortcutsStore.array(prefs, ShortcutsStore.PENDING_SKIPS)),
            System.currentTimeMillis(),
            today(),
        )
        if (asked.outcome == Outcome.SET_ASIDE) {
            ShortcutsStore.put(prefs, ShortcutsStore.PENDING_SKIPS, asked.pending)
            store(prefs, asked.words)
            StartWidget.updateAll(context)
            live?.let { channel -> Handler(Looper.getMainLooper()).post { channel.invokeMethod("skips", null) } }
        }
        return asked
    }
}

/// The Start widget's "Not today" tile (#445): a broadcast, so nothing opens.
class NotTodayReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NotToday.ask(context.applicationContext)
    }
}

/// The launcher's "Not today" item (#445). A launcher shortcut can only start
/// an activity, so this one has no window: it sets the day aside, says so in
/// a toast over wherever the user is, and is gone before anything is drawn.
class NotTodayActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotToday.ask(applicationContext).words?.let { words ->
            Toast.makeText(applicationContext, words.done, Toast.LENGTH_SHORT).show()
        }
        finish()
    }
}
