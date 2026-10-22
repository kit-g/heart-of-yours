package me.heart

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/// What the Wear OS app (#250) says, delivered whether or not this app is
/// running: the system starts this service for it, and [WatchChannel] keeps
/// what no Dart is listening for.
class WatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path == WatchChannel.EVENT) WatchChannel.received(this, event.data)
    }

    override fun onDataChanged(events: DataEventBuffer) {
        events
            .filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path.orEmpty().startsWith(WatchChannel.EVENTS) }
            .forEach { event ->
                event.dataItem.data?.let { WatchChannel.received(this, it) }
                WatchChannel.consumed(this, event.dataItem.uri)
            }
    }
}
