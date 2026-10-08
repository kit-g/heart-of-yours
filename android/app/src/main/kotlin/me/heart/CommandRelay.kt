package me.heart

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.suspendCancellableCoroutine
import org.json.JSONArray
import org.json.JSONObject
import kotlin.coroutines.resume

/// Hands a workout command — the same JSON the lock screen's buttons and the
/// watch send (#141) — to the app. With the app's engine up, over the
/// `heart/ongoing_workout` channel, applied on the spot; without it, into the
/// queue Dart drains on its next launch, which is the lock screen's own queue
/// (`lockScreen.pendingCommands`, a shared_preferences string list).
object CommandRelay {
    enum class Delivery { APPLIED, REJECTED, QUEUED }

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val PENDING = "flutter.lockScreen.pendingCommands"

    /// shared_preferences' own encoding of a string list: a marker, then JSON.
    const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"

    @Volatile
    private var live: MethodChannel? = null

    /// The running engine's channel, while it runs.
    fun attach(channel: MethodChannel) {
        live = channel
    }

    fun detach(channel: MethodChannel) {
        if (live === channel) live = null
    }

    fun flutterPrefs(context: Context): SharedPreferences = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)

    suspend fun deliver(context: Context, command: JSONObject): Delivery {
        val channel = live
        if (channel == null) {
            queue(flutterPrefs(context), command)
            return Delivery.QUEUED
        }
        return suspendCancellableCoroutine { continuation ->
            Handler(Looper.getMainLooper()).post {
                channel.invokeMethod("command", toMap(command), object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        continuation.resume(if (result == true) Delivery.APPLIED else Delivery.REJECTED)
                    }

                    override fun error(code: String, message: String?, details: Any?) {
                        continuation.resume(Delivery.REJECTED)
                    }

                    override fun notImplemented() {
                        // an engine without the handler: the queue is the sure path
                        queue(flutterPrefs(context), command)
                        continuation.resume(Delivery.QUEUED)
                    }
                })
            }
        }
    }

    fun queue(prefs: SharedPreferences, command: JSONObject) {
        val kept = pending(prefs.getString(PENDING, null))
        kept.add(command.toString())
        prefs.edit().putString(PENDING, encode(kept)).apply()
    }

    /// The queue as stored, or empty for nothing — or for the older
    /// Java-serialized shape this app never wrote.
    fun pending(stored: String?): MutableList<String> {
        if (stored == null || !stored.startsWith(LIST_PREFIX)) return mutableListOf()
        val array = runCatching { JSONArray(stored.removePrefix(LIST_PREFIX)) }.getOrNull() ?: return mutableListOf()
        return (0 until array.length()).map { array.getString(it) }.toMutableList()
    }

    fun encode(list: List<String>): String = LIST_PREFIX + JSONArray(list).toString()

    /// A channel takes maps, not JSON.
    fun toMap(json: JSONObject): Map<String, Any?> {
        return json.keys().asSequence().associateWith { key ->
            when (val value = json.get(key)) {
                JSONObject.NULL -> null
                is JSONObject -> toMap(value)
                is JSONArray -> (0 until value.length()).map { value.get(it) }
                else -> value
            }
        }
    }
}
