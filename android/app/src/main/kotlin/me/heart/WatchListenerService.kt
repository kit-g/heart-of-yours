package me.heart

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

/// What the Wear OS app (#250) says, delivered whether or not this app is
/// running: the system starts this service for it, and [WatchChannel] keeps
/// what no Dart is listening for.
class WatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        when (event.path) {
            WatchChannel.EVENT -> WatchChannel.received(this, event.data)
            // already off the main thread: the write is done before this returns
            WatchReadings.PATH -> runBlocking { WatchReadings.received(this@WatchListenerService, event.data) }
        }
    }

    /// What the watch left while the phone was away (#465) arrives as a batch
    /// once it is back, in no promised order: replayed by when each thing was
    /// done, as the phone places a late command at its own time anyway.
    override fun onDataChanged(events: DataEventBuffer) {
        events
            .filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path.orEmpty().startsWith(WatchChannel.EVENTS) }
            .map { it.dataItem.uri to it.dataItem.data }
            .sortedBy { (_, data) -> data?.let { runCatching { JSONObject(String(it)).optLong("at") }.getOrNull() } ?: 0 }
            .forEach { (uri, data) ->
                data?.let { WatchChannel.received(this, it) }
                // the receipt: an item gone from the watch is one the phone has
                WatchChannel.consumed(this, uri)
            }
    }
}
