package me.heart.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/// What the watch measured during a workout (#461), held for the phone to save
/// into Health Connect — if, and only if, the user said so.
///
/// The phone's answer arrives with every state ([PhoneState] `keepsReadings`):
/// unasked, a finished session's readings wait here, in no-backup storage;
/// yes, they go to the phone; no, they are deleted. They travel only by
/// message to a phone that is *nearby* — connected over Bluetooth or the same
/// Wi-Fi — never as a data item, which the Data Layer may sync through Google's
/// cloud. Handed over or refused, nothing is kept; unclaimed, they go after a
/// week. Never logged. See `docs/2026-09-05.health-data.md`, "On Wear OS".
object Readings {
    private const val PATH = "/readings"
    private const val PREFS = "readings"
    private const val ANSWER = "answer"
    private const val KEEP_MS = 7 * 24 * 60 * 60 * 1000L

    /// One sample per this long at most: a series Health Connect stores, not
    /// every beat the sensor reports.
    const val SAMPLE_MS = 5_000L

    private fun dir(context: Context) = File(context.noBackupFilesDir, "readings").apply { mkdirs() }

    /// The session for [workoutId] is over: keep what it measured.
    fun keep(context: Context, workoutId: String, start: Long, end: Long, heartRate: List<Pair<Long, Double>>, energy: Double?) {
        if (heartRate.isEmpty() && (energy ?: 0.0) <= 0) return
        val json = JSONObject()
            .put("workoutId", workoutId)
            .put("start", start)
            .put("end", end)
            .put("heartRate", JSONArray(heartRate.map { (time, bpm) -> JSONArray().put(time).put(bpm) }))
            .putOpt("energy", energy)
        dir(context).resolve("$workoutId.json").writeText(json.toString())
    }

    /// The user's answer, as the phone last sent it: null until asked.
    suspend fun answer(context: Context, keeps: Boolean?) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().apply {
            if (keeps == null) remove(ANSWER) else putBoolean(ANSWER, keeps)
        }.apply()
        when (keeps) {
            true -> handOver(context)
            false -> dir(context).listFiles().orEmpty().forEach { it.delete() }
            null -> Unit
        }
    }

    /// Sends whatever waits to a nearby phone, if the user said yes, and drops
    /// what the phone has. Safe to call any time: nothing to send, no answer,
    /// or no phone nearby, and it does nothing.
    suspend fun handOver(context: Context) {
        val files = dir(context).listFiles().orEmpty()
        val now = System.currentTimeMillis()
        files.filter { now - it.lastModified() > KEEP_MS }.forEach { it.delete() }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.contains(ANSWER) || !prefs.getBoolean(ANSWER, false)) return
        val waiting = dir(context).listFiles().orEmpty()
        if (waiting.isEmpty()) return

        val phone = runCatching {
            Wearable.getCapabilityClient(context)
                .getCapability(PhoneSession.PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
                .nodes
                // a direct link only, never through the cloud
                .firstOrNull { it.isNearby }
        }.getOrNull() ?: return

        waiting.forEach { file ->
            runCatching { Wearable.getMessageClient(context).sendMessage(phone.id, PATH, file.readBytes()).await() }
                .onSuccess { file.delete() }
                .onFailure { Log.w("Readings", "Not handed over yet: ${it.javaClass.simpleName}") }
        }
    }
}
