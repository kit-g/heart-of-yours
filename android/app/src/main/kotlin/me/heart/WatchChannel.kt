package me.heart

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject

/// The phone's end of the Wear OS app (#250): the `heart/watch` channel that
/// `lib/core/env/watch.dart` speaks to, over the Wearable Data Layer — the
/// twin of ios/Runner/WatchChannel.swift, method for method.
///
/// A pass-through. Dart builds the watch's whole state and this forwards it as
/// JSON: a data item at [STATE], which the latest one replaces and the system
/// delivers even to a watch app that isn't running, plus a message to a watch
/// in reach, which should not wait for that. Nothing here reads the state.
///
/// What the watch says comes back as JSON with an `event`, as on iOS: by
/// message while this app can hear it, as a data item when it must outlast a
/// phone app that isn't running (the opt-in's yes). Either way
/// [WatchListenerService] wakes this process and hands it to [received].
object WatchChannel {
    /// Advertised by the watch app (android/wear/src/main/res/values/wear.xml):
    /// a node that has it is a watch with Heart installed.
    const val WATCH_CAPABILITY = "heart_watch"

    const val STATE = "/state"
    const val EVENT = "/event"

    /// Data items the watch leaves for the phone, one per path below this.
    const val EVENTS = "/events"

    private const val TAG = "Watch"
    private const val PREFS = "watch"

    /// Set when the watch app was opened with no Dart listening, and cleared
    /// when Dart takes it — so the opt-in's yes survives a phone app that was
    /// not running at the time.
    private const val OPENED = "openedUnseen"

    /// Commands from the watch that no Dart was listening for, as JSON.
    private const val PENDING = "pendingCommands"

    /// The workout the watch is measuring (#461), as the watch reported it.
    private const val MEASURING = "measuring"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val main = Handler(Looper.getMainLooper())

    @Volatile
    private var channel: MethodChannel? = null

    private val capabilityListener = CapabilityClient.OnCapabilityChangedListener {
        main.post { channel?.invokeMethod("changed", null) }
    }

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        val channel = MethodChannel(messenger, "heart/watch")
        this.channel = channel
        Wearable.getCapabilityClient(app).addListener(capabilityListener, WATCH_CAPABILITY)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "installed" -> scope.launch { result.success(installed(app)) }
                "takeOpened" -> {
                    val prefs = prefs(app)
                    result.success(prefs.getBoolean(OPENED, false))
                    prefs.edit().remove(OPENED).apply()
                }
                "takeCommands" -> result.success(takeCommands(app))
                // the Data Layer has no count of what is still on its way;
                // the watch says so itself when it is back (#465)
                "contentPending" -> result.success(false)
                "measures" -> {
                    val workoutId = call.argument<String>("workoutId")
                    result.success(workoutId != null && prefs(app).getString(MEASURING, null) == workoutId)
                }
                // a Wear OS watch saves nothing itself: the phone writes the
                // workout, and the watch's readings join it if the user said so (#461)
                "finish" -> {
                    call.argument<String>("workoutId")?.let { workoutId ->
                        scope.launch(Dispatchers.IO) { WatchReadings.finished(app, workoutId) }
                    }
                    result.success(false)
                }
                "send" -> {
                    val state = call.arguments as? Map<*, *>
                    if (state == null) {
                        result.error("bad_arguments", "send needs a state", null)
                    } else {
                        scope.launch {
                            send(app, state)
                            result.success(null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun unregister(context: Context) {
        channel = null
        Wearable.getCapabilityClient(context.applicationContext).removeListener(capabilityListener)
    }

    private suspend fun installed(context: Context): Boolean {
        return runCatching {
            Wearable.getCapabilityClient(context)
                .getCapability(WATCH_CAPABILITY, CapabilityClient.FILTER_ALL)
                .await()
                .nodes
                .isNotEmpty()
        }.getOrElse {
            // no Play services, or no Wear OS app paired at all
            false
        }
    }

    private suspend fun send(context: Context, state: Map<*, *>) {
        // the item is deduplicated by content; a send is a real change by
        // construction (Dart compares first), and the stamp keeps a repeat meant
        // for a reinstalled watch app from being dropped as a duplicate
        val payload = JSONObject(state).put("sentAt", stamp()).toString().toByteArray()
        runCatching {
            val request = PutDataRequest.create(STATE).setData(payload).setUrgent()
            Wearable.getDataClient(context).putDataItem(request).await()
            // the item arrives when the system gets to it; a watch on screen
            // right now should not wait for that
            val reachable = Wearable.getCapabilityClient(context)
                .getCapability(WATCH_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
                .nodes
            reachable.forEach { node ->
                Wearable.getMessageClient(context).sendMessage(node.id, STATE, payload)
            }
        }.onFailure { Log.w(TAG, "Watch state not sent: ${it.message}") }
    }

    private var lastStamp = 0L

    /// When a state was sent, and its order: the watch drops anything older
    /// than what it shows, so two states sent in the same millisecond still
    /// get stamps of their own.
    @Synchronized
    private fun stamp(): Long {
        lastStamp = maxOf(System.currentTimeMillis(), lastStamp + 1)
        return lastStamp
    }

    /// What the watch said, from [WatchListenerService].
    fun received(context: Context, data: ByteArray) {
        val message = runCatching { JSONObject(String(data)) }.getOrNull() ?: return
        val event = message.optString("event").ifEmpty { return }
        val app = context.applicationContext
        main.post {
            when (event) {
                "command" -> forward(app, message)
                // empty when the watch stopped measuring: the rest's tap is the phone's again
                "measuring" -> prefs(app).edit().apply {
                    when (val workoutId = message.optString("workoutId")) {
                        "" -> remove(MEASURING)
                        else -> putString(MEASURING, workoutId)
                    }
                }.apply()
                else -> {
                    // kept until Dart takes it: the channel may not exist yet,
                    // or may belong to an engine that is not listening
                    if (event == "opened") prefs(app).edit().putBoolean(OPENED, true).apply()
                    channel?.invokeMethod(event, null)
                }
            }
        }
    }

    /// Hands a command to Dart, or keeps it if nothing there is listening.
    private fun forward(context: Context, command: JSONObject) {
        val channel = channel ?: return keep(context, command)
        channel.invokeMethod("command", CommandRelay.toMap(command), object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (result != true) keep(context, command)
            }

            override fun error(code: String, message: String?, details: Any?) = keep(context, command)

            override fun notImplemented() = keep(context, command)
        })
    }

    private fun keep(context: Context, command: JSONObject) {
        val prefs = prefs(context)
        val kept = JSONArray(prefs.getString(PENDING, "[]")).put(command)
        prefs.edit().putString(PENDING, kept.toString()).apply()
    }

    private fun takeCommands(context: Context): List<Map<String, Any?>> {
        val prefs = prefs(context)
        val kept = JSONArray(prefs.getString(PENDING, "[]"))
        prefs.edit().remove(PENDING).apply()
        return (0 until kept.length()).map { CommandRelay.toMap(kept.getJSONObject(it)) }
    }

    /// Spent data items under [EVENTS] go once the phone has them, so the
    /// watch's store does not keep every yes it ever said.
    fun consumed(context: Context, uri: Uri) {
        Wearable.getDataClient(context.applicationContext).deleteDataItems(uri)
    }

    private fun prefs(context: Context): SharedPreferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
