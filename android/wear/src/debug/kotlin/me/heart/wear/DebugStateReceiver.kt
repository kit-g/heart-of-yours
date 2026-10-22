package me.heart.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Base64
import org.json.JSONObject

/// Plants a phone state on a watch with no phone (debug builds only), as if
/// the phone had sent it: the app, the Tile and the complication all take it.
///
///     adb shell am broadcast -a me.heart.wear.debug.STATE \
///       -n me.heart.android.dev/me.heart.wear.DebugStateReceiver \
///       --es state "$(base64 < state.json)" [--ez reachable true]
///
/// `reachable` has the watch act as if the phone could hear it, so the
/// controls show; what they send goes nowhere.
class DebugStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        PhoneSession.debugReachable.value = intent.getBooleanExtra("reachable", false)
        val encoded = intent.getStringExtra("state") ?: return
        val json = JSONObject(String(Base64.decode(encoded, Base64.DEFAULT))).put("sentAt", System.currentTimeMillis())
        val bytes = json.toString().toByteArray()
        // the app, if it runs; the Tile and the complication either way
        PhoneSession.planted.tryEmit(bytes)
        PhoneState.from(json)?.let { Snapshot.write(context, Snapshot.of(it)) }
    }
}
