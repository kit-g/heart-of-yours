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
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import java.util.UUID

/// The watch's end of the link to the phone — the twin of
/// ios/Watch/PhoneSession.swift, over the Wearable Data Layer: holds the last
/// state the phone sent (#459).
///
/// The phone's state arrives as a data item at [STATE], which the latest one
/// replaces and which is there to read on launch even if it was written while
/// this app was closed, and as a message while the phone can reach the watch.
/// Both carry the phone's `sentAt`, and the older of the two is dropped.
///
/// Commands are requests, never edits (#460). The watch shows each one applied
/// to the phone's last state at once ([applying]), and the phone's answer
/// replaces that: the phone is still the only writer. In reach, a command goes
/// as a message. Out of reach (#465) — the phone in a locker — or when a
/// message fails, it goes as a data item of its own under [COMMANDS], which
/// the system keeps (through the app being killed, and the watch rebooting)
/// and delivers once the phone is back. The phone deletes each one it has
/// applied: an item still here is a command the phone does not have yet.
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

    /// What to show: the phone's last state, with [queued] applied on top.
    val state: StateFlow<PhoneState> = _state.asStateFlow()

    /// What the phone last said.
    private var phoneState: PhoneState = PhoneState.Awaiting

    /// Commands the phone has not answered, oldest first.
    private val queued = mutableListOf<Queued>()

    private data class Queued(
        val id: String,
        val command: Command,
        val at: Long,
        /// Left as a data item, waiting for the phone to be back, rather than
        /// a message in flight.
        val transferred: Boolean = false,
        /// Handed to the phone, which has not sent a state since.
        val delivered: Boolean = false,
    )

    private val _waiting = MutableStateFlow(false)

    /// Something waits for the phone to be back.
    val waiting: StateFlow<Boolean> = _waiting.asStateFlow()

    private val _unsynced = MutableStateFlow(emptySet<String>())

    /// The sets a waiting command is about: on the watch, not yet on the phone.
    val unsynced: StateFlow<Set<String>> = _unsynced.asStateFlow()

    private val _reachable = MutableStateFlow(false)

    /// Whether the phone can hear a message right now.
    val reachable: StateFlow<Boolean> = combine(_reachable, debugReachable) { real, debug -> real || debug }
        .stateIn(scope, SharingStarted.Eagerly, false)

    /// The `sentAt` of what [state] came from.
    private var sentAt = 0L

    fun start() {
        data.addListener(this)
        messages.addListener(this)
        capabilities.addListener(this, PHONE_CAPABILITY)
        scope.launch {
            restoreQueue()
            restore()
            announce()
        }
        // debug builds only (DebugStateReceiver): a state planted on a watch with
        // no phone, whose Data Layer stays silent until it is paired
        scope.launch { planted.collect(::apply) }
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

    /// What the system still holds for the phone, after a relaunch: the queue
    /// outlives the app, the list of it does not.
    private suspend fun restoreQueue() {
        runCatching {
            val local = Wearable.getNodeClient(context).localNode.await().id
            val uri = Uri.Builder().scheme("wear").authority(local).path(COMMANDS).build()
            val items = data.getDataItems(uri, DataClient.FILTER_PREFIX).await()
            val kept = items.mapNotNull { item ->
                val json = item.data?.let { runCatching { JSONObject(String(it)) }.getOrNull() } ?: return@mapNotNull null
                val command = Command.from(json) ?: return@mapNotNull null
                Queued(json.optString("id"), command, json.optLong("at", System.currentTimeMillis()), transferred = true)
            }
            items.release()
            queued.removeAll { it.transferred }
            queued.addAll(0, kept.sortedBy { it.at })
            show()
        }.onFailure { Log.w(TAG, "No queue to restore: ${it.message}") }
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
        announceQueue(phones)
    }

    /// Back in reach with a queue: tell the phone now. The queue itself goes
    /// when the system gets to it, seconds later, and without this the phone
    /// sits there saying nothing.
    private fun announceQueue(phones: Collection<Node>) {
        if (!_waiting.value) return
        val catchingUp = event("catchingUp").toString().toByteArray()
        phones.forEach { messages.sendMessage(it.id, EVENT, catchingUp) }
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events.forEach { event ->
            val path = event.dataItem.uri.path.orEmpty()
            when {
                event.type == DataEvent.TYPE_CHANGED && path == STATE -> event.dataItem.data?.let(::apply)
                // the phone took a queued command: the receipt
                event.type == DataEvent.TYPE_DELETED && path.startsWith("$COMMANDS/") -> delivered(path.substringAfterLast('/'))
            }
        }
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

    fun send(command: Command) {
        val at = System.currentTimeMillis()
        val id = UUID.randomUUID().toString()
        val message = command.json(id, at).toString().toByteArray()
        // while anything waits for the phone, this waits behind it: a message
        // would overtake the queue, and the phone would apply them out of order
        val queue = _waiting.value || !reachable.value
        queued += Queued(id, command, at)
        show()
        scope.launch {
            if (queue) return@launch transfer(id, message)
            val phone = runCatching {
                capabilities.getCapability(PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE).await().nodes.firstOrNull()
            }.getOrNull()
            val sent = phone != null && runCatching { messages.sendMessage(phone.id, EVENT, message).await() }.isSuccess
            when {
                sent || debugReachable.value -> delivered(id)
                // never reached the phone — the reach went as it was sent
                else -> {
                    _reachable.value = false
                    transfer(id, message)
                }
            }
        }
    }

    /// Leaves [id] for the system to deliver once the phone is back.
    private suspend fun transfer(id: String, message: ByteArray) {
        val index = queued.indexOfFirst { it.id == id }
        if (index < 0) return
        runCatching {
            val request = PutDataRequest.create("$COMMANDS/$id").setData(message).setUrgent()
            data.putDataItem(request).await()
        }.onFailure { Log.w(TAG, "A command could not be queued: ${it.message}") }
        queued[index] = queued[index].copy(transferred = true)
        show()
    }

    /// The phone has the command: it counts as answered at the next state the
    /// phone sends.
    private fun delivered(id: String) {
        val index = queued.indexOfFirst { it.id == id }
        if (index < 0) return
        queued[index] = queued[index].copy(delivered = true)
        show()
    }

    /// The phone's state with what it has not answered applied. A Finish counts
    /// only once it is queued: in reach, the phone may still refuse it (a set
    /// added there since), and the watch must not say the workout is over
    /// before it does.
    private fun show() {
        val shown = queued
            .filter { it.command !is Command.Finish || it.transferred }
            .fold(phoneState) { state, entry -> state.applying(entry.command, entry.at) }
        _state.value = shown
        val waiting = queued.filter { it.transferred && !it.delivered }
        _waiting.value = waiting.isNotEmpty()
        _unsynced.value = waiting.mapNotNull { it.command.setId }.toSet()
        // the watch face follows what the wrist shows (#463)
        Snapshot.write(context, Snapshot.of(shown))
    }

    private fun apply(bytes: ByteArray) {
        val json = runCatching { JSONObject(String(bytes)) }.getOrNull() ?: return
        val stamp = json.optLong("sentAt", 0)
        // the message and the item carry the same state; whichever lands
        // second, and anything older, changes nothing
        if (stamp != 0L && stamp <= sentAt) return
        val state = PhoneState.from(json) ?: return
        sentAt = stamp
        phoneState = state
        // what the phone has heard is in what it sent; the rest still applies
        queued.removeAll { it.delivered }
        show()
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
        const val COMMANDS = "$EVENTS/commands"

        /// Debug builds only (DebugStateReceiver): act as if the phone could hear.
        internal val debugReachable = MutableStateFlow(false)
        internal val planted = MutableSharedFlow<ByteArray>(replay = 1)

        private const val TAG = "PhoneSession"
        private const val PREFS = "phone"
        private const val ANNOUNCED = "openedAnnounced"
    }
}
