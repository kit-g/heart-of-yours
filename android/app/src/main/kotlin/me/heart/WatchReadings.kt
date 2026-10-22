package me.heart

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.units.Energy
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant

/// What a Wear OS watch measured during a workout (#461) — heart rate and
/// active energy — written into Health Connect beside the workout the phone
/// already wrote, and only with the user's say: their answer
/// (`Preferences.watchReadings`) and Health Connect's own grant. Never sent
/// anywhere else; see `docs/2026-09-05.health-data.md`.
///
/// The watch hands them over by message, phone to watch directly, once the
/// workout is over. They are written only for a workout this phone *finished*
/// — told by `heart/watch`'s `finish` — never for one cancelled. Readings that
/// arrive before their finish wait, in no-backup storage, for a day at most;
/// written or expired, they are gone.
object WatchReadings {
    const val PATH = "/readings"

    private const val TAG = "WatchReadings"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val ANSWER = "flutter.watchReadings"
    private const val PREFS = "watch"
    private const val FINISHED = "finishedWorkouts"
    private const val KEEP_MS = 24 * 60 * 60 * 1000L

    /// From [WatchListenerService], off the main thread.
    suspend fun received(context: Context, data: ByteArray) {
        val readings = runCatching { JSONObject(String(data)) }.getOrNull() ?: return
        val workoutId = readings.optString("workoutId").ifEmpty { return }
        if (!allowed(context)) return
        when (workoutId in finished(context)) {
            true -> write(context, readings)
            false -> pending(context).resolve("$workoutId.json").writeText(readings.toString())
        }
    }

    /// The phone finished [workoutId]: readings that arrived ahead of it are
    /// written now, and later ones will be.
    suspend fun finished(context: Context, workoutId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val kept = JSONObject(prefs.getString(FINISHED, "{}") ?: "{}")
        // a day is long enough for a phone left in a locker
        kept.keys().asSequence().toList().filter { now - kept.getLong(it) > KEEP_MS }.forEach(kept::remove)
        kept.put(workoutId, now)
        prefs.edit().putString(FINISHED, kept.toString()).apply()

        val waiting = pending(context)
        waiting.listFiles().orEmpty().forEach { file ->
            when {
                file.name == "$workoutId.json" -> {
                    if (allowed(context)) runCatching { write(context, JSONObject(file.readText())) }
                    file.delete()
                }
                now - file.lastModified() > KEEP_MS -> file.delete()
            }
        }
    }

    private fun finished(context: Context): Set<String> {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(FINISHED, "{}") ?: "{}"
        return JSONObject(stored).keys().asSequence().toSet()
    }

    private fun pending(context: Context) = File(context.noBackupFilesDir, "watch-readings").apply { mkdirs() }

    /// The user's answer, and Health Connect's grant: both, or nothing is written.
    private suspend fun allowed(context: Context): Boolean {
        val answer = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE).getBoolean(ANSWER, false)
        if (!answer) return false
        if (HealthConnectClient.getSdkStatus(context) != HealthConnectClient.SDK_AVAILABLE) return false
        val granted = runCatching {
            HealthConnectClient.getOrCreate(context).permissionController.getGrantedPermissions()
        }.getOrDefault(emptySet())
        return PERMISSIONS.all { it in granted }
    }

    private val PERMISSIONS = setOf(
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
    )

    /// One heart-rate series and one energy total, spanning what the watch
    /// measured. Ids of their own per workout, so a second hand-over of the
    /// same readings replaces rather than doubles them.
    private suspend fun write(context: Context, readings: JSONObject) {
        val workoutId = readings.getString("workoutId")
        val start = Instant.ofEpochMilli(readings.getLong("start"))
        val end = Instant.ofEpochMilli(readings.getLong("end"))
        if (!end.isAfter(start)) return
        val device = Device(type = Device.TYPE_WATCH)

        val samples = (readings.optJSONArray("heartRate") ?: JSONArray()).let { array ->
            (0 until array.length()).mapNotNull { i ->
                val sample = array.optJSONArray(i) ?: return@mapNotNull null
                val time = Instant.ofEpochMilli(sample.getLong(0))
                val bpm = sample.getDouble(1).toLong()
                if (time.isBefore(start) || time.isAfter(end) || bpm !in 1..300) null else HeartRateRecord.Sample(time, bpm)
            }
        }
        val records = buildList {
            if (samples.isNotEmpty()) {
                add(
                    HeartRateRecord(
                        startTime = start,
                        startZoneOffset = null,
                        endTime = end,
                        endZoneOffset = null,
                        samples = samples,
                        metadata = Metadata.autoRecorded(device, clientRecordId = "heart-heart-rate-$workoutId", clientRecordVersion = 1),
                    ),
                )
            }
            val energy = readings.optDouble("energy", 0.0)
            if (energy > 0) {
                add(
                    ActiveCaloriesBurnedRecord(
                        startTime = start,
                        startZoneOffset = null,
                        endTime = end,
                        endZoneOffset = null,
                        energy = Energy.kilocalories(energy),
                        metadata = Metadata.autoRecorded(device, clientRecordId = "heart-energy-$workoutId", clientRecordVersion = 1),
                    ),
                )
            }
        }
        if (records.isEmpty()) return
        runCatching { HealthConnectClient.getOrCreate(context).insertRecords(records) }
            // the readings never go into the message: health data stays out of logs
            .onFailure { Log.w(TAG, "Watch readings not written: ${it.javaClass.simpleName}") }
    }
}
