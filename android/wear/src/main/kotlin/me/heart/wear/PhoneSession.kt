package me.heart.wear

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

/// The watch's end of the link to the phone — the twin of
/// ios/Watch/PhoneSession.swift, over the Wearable Data Layer: holds the last
/// state the phone sent (#459).
///
/// The phone's state arrives as a data item at [STATE], which the latest one
/// replaces and which is there to read on launch even if it was written while
/// this app was closed, and as a message while the phone can reach the watch.
/// Both carry the phone's `sentAt`, and the older of the two is dropped.
///
/// Opening is both the opt-in's yes (`docs/opt-in.md`) and a request for the
/// current state. The yes goes as a data item — kept by the system and
/// delivered even if the phone app isn't running — and once only; the request
/// goes as a message, which only means anything while the phone can answer.
class PhoneSession(context: Context, private val scope: CoroutineScope) :
    DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener,
    CapabilityClient.OnCapabilityChangedListener {

    private val context = context.applicationContext
    private val data = Wearable.getDataClient(this.context)
    private val messages = Wearable.getMessageClient(this.context)
    private val capabilities = Wearable.getCapabilityClient(this.context)

    private val _state = MutableStateFlow<PhoneState>(PhoneState.Awaiting)

    /// What to show: the phone's last state.
    val state: StateFlow<PhoneState> = _state.asStateFlow()

    private val _reachable = MutableStateFlow(false)

    /// Whether the phone can hear a message right now.
    val reachable: StateFlow<Boolean> = _reachable.asStateFlow()

    /// The `sentAt` of what [state] came from.
    private var sentAt = 0L

    fun start() {
        data.addListener(this)
        messages.addListener(this)
        capabilities.addListener(this, PHONE_CAPABILITY)
        scope.launch {
            restore()
            announce()
        }
    }

    fun stop() {
        data.removeListener(this)
        messages.removeListener(this)
        capabilities.removeListener(this)
    }

    /// What the phone last said, even if it said it while this app was closed.
    private suspend fun restore() {
        runCatching {
            val uri = Uri.Builder().scheme("wear").authority("*").path(STATE).build()
            val items = data.getDataItems(uri).await()
            items.mapNotNull { it.data }.forEach(::apply)
            items.release()
        }.onFailure { Log.w(TAG, "No state to restore: ${it.message}") }
    }

    private suspend fun announce() {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(ANNOUNCED, false)) {
            runCatching {
                val opened = event("opened").put("at", System.currentTimeMillis())
                val request = PutDataRequest.create("$EVENTS/opened").setData(opened.toString().toByteArray()).setUrgent()
                data.putDataItem(request).await()
                prefs.edit().putBoolean(ANNOUNCED, true).apply()
            }.onFailure { Log.w(TAG, "The yes was not left for the phone: ${it.message}") }
        }
        requestState()
    }

    /// Every launch asks for the current state, and so does the phone coming
    /// back within reach, in case what the item holds predates the last change.
    private suspend fun requestState() {
        val phones = runCatching {
            capabilities.getCapability(PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE).await().nodes
        }.getOrDefault(emptySet())
        _reachable.value = phones.isNotEmpty()
        val opened = event("opened").toString().toByteArray()
        phones.forEach { messages.sendMessage(it.id, EVENT, opened) }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events
            .filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path == STATE }
            .mapNotNull { it.dataItem.data }
            .forEach(::apply)
    }

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path == STATE) apply(event.data)
    }

    override fun onCapabilityChanged(info: CapabilityInfo) {
        // the listener hears the phones that are connected now
        val reachable = info.nodes.isNotEmpty()
        val back = reachable && !_reachable.value
        _reachable.value = reachable
        if (back) scope.launch { requestState() }
    }

    private fun apply(bytes: ByteArray) {
        val json = runCatching { JSONObject(String(bytes)) }.getOrNull() ?: return
        val stamp = json.optLong("sentAt", 0)
        // the message and the item carry the same state; whichever lands
        // second, and anything older, changes nothing
        if (stamp != 0L && stamp <= sentAt) return
        val state = PhoneState.from(json) ?: return
        sentAt = stamp
        _state.value = state
    }

    private fun event(name: String) = JSONObject().put("event", name)

    companion object {
        /// Advertised by the phone app (android/app/src/main/res/values/wear.xml).
        const val PHONE_CAPABILITY = "heart_phone"

        /// The paths `android/app/src/main/kotlin/me/heart/WatchChannel.kt`
        /// uses: the phone's state, what the watch says to the phone, and the
        /// data items it leaves for it.
        const val STATE = "/state"
        const val EVENT = "/event"
        const val EVENTS = "/events"

        private const val TAG = "PhoneSession"
        private const val PREFS = "phone"
        private const val ANNOUNCED = "openedAnnounced"
    }
}
