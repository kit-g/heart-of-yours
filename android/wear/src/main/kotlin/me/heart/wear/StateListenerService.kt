package me.heart.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

/// The phone's state, heard with the app closed: the Tile and the complication
/// (#463) follow the workout whether or not Heart is on screen. The app, when
/// it runs, hears the same state itself through [PhoneSession].
class StateListenerService : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        events
            .filter { it.type == DataEvent.TYPE_CHANGED && it.dataItem.uri.path == PhoneSession.STATE }
            .mapNotNull { it.dataItem.data }
            .mapNotNull { runCatching { PhoneState.from(JSONObject(String(it))) }.getOrNull() }
            .lastOrNull()
            ?.let { Snapshot.write(this, Snapshot.of(it)) }
    }
}
