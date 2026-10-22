package me.heart.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.IBinder
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.lifecycle.LifecycleService
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import androidx.lifecycle.lifecycleScope
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.tasks.await
import org.json.JSONObject
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/// The watch's exercise for the workout the phone is running (#461): what
/// makes the watch measure heart rate and energy, and keeps Heart running with
/// the wrist down. The twin of `WorkoutSession` in ios/Watch/WorkoutSession.swift.
///
/// Measuring is Health Services' job; Heart only starts and ends it. The
/// readings are shown on the wrist and go nowhere else ([Measuring]).
///
/// **When it starts.** Only one app can run an exercise at a time: starting
/// Heart's ends any other's. So Heart never starts one on its own behalf — not
/// from the phone, not in the background. It starts when the user has Heart
/// open on the watch during a workout, which is a person choosing Heart for
/// this session.
///
/// **How it ends.** With the workout on the phone, finished or not. Unlike the
/// Apple Watch, the watch saves nothing: Wear OS has no Health Connect of its
/// own, so the phone writes the workout to Health Connect as it always has,
/// and the readings, which may not leave the watch, are not in it.
class WorkoutService : LifecycleService() {
    private val exercises by lazy { HealthServices.getClient(this).exerciseClient }
    private var workoutId: String? = null

    /// The tap for the rest that is running (#462). Once the watch measures,
    /// the phone schedules no rest notification of its own — it would reach
    /// the same wrist a second time — so the watch owns the tap.
    private var restAlarm: Job? = null

    private val updates = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val heartRate = update.latestMetrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value
            val energy = update.latestMetrics.getData(DataType.CALORIES_TOTAL)?.total
            Measuring.read(heartRate, energy)
            if (update.exerciseStateInfo.state.isEnded) stop()
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onRegistered() = Unit

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.w(TAG, "Exercise updates refused: ${throwable.message}")
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) = Unit
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        super.onStartCommand(intent, flags, startId)
        when (intent?.action) {
            START -> start(intent.getStringExtra(WORKOUT_ID) ?: return START_NOT_STICKY, intent.getStringExtra(ACTIVITY))
            PAUSE -> lifecycleScope.launch { runCatching { exercises.pauseExerciseAsync().await() } }
            RESUME -> lifecycleScope.launch { runCatching { exercises.resumeExerciseAsync().await() } }
            END -> end()
            REST -> rest(intent.getLongExtra(REST_END, 0))
            DESCRIBE -> {
                summary = Summary(
                    title = intent.getStringExtra(TITLE).orEmpty(),
                    clock = intent.getLongExtra(CLOCK, 0),
                    pausedAt = intent.getLongExtra(PAUSED_AT, 0).takeIf { it > 0 },
                )
                describe()
            }
        }
        return START_NOT_STICKY
    }

    private fun start(workoutId: String, activity: String?) {
        if (this.workoutId == workoutId) return
        this.workoutId = workoutId
        ServiceCompat.startForeground(this, NOTIFICATION, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        describe()
        lifecycleScope.launch {
            runCatching {
                val supported = exercises.getCapabilitiesAsync().await().supportedExerciseTypes
                val type = exerciseType(activity).takeIf { it in supported } ?: ExerciseType.WORKOUT
                exercises.setUpdateCallback(updates)
                exercises.startExerciseAsync(
                    ExerciseConfig.builder(type)
                        .setDataTypes(setOf(DataType.HEART_RATE_BPM, DataType.CALORIES_TOTAL))
                        .setIsAutoPauseAndResumeEnabled(false)
                        .setIsGpsEnabled(false)
                        .build(),
                ).await()
                Measuring.started(workoutId)
                tellPhone(workoutId)
            }.onFailure {
                // declined, or no sensors: nothing is measured, and everything
                // else about the watch app carries on
                Log.w(TAG, "Exercise did not start: ${it.message}")
                stop()
            }
        }
    }

    /// That the watch measures [workoutId] — no reading, only the fact — so the
    /// phone leaves the rest's tap to it (#462). Left as a data item, which
    /// reaches a phone app that isn't running.
    private suspend fun tellPhone(workoutId: String) {
        runCatching {
            val measuring = JSONObject().put("event", "measuring").put("workoutId", workoutId)
            val request = PutDataRequest.create("${PhoneSession.EVENTS}/measuring").setData(measuring.toString().toByteArray()).setUrgent()
            Wearable.getDataClient(this).putDataItem(request).await()
        }.onFailure { Log.w(TAG, "The phone was not told the watch measures: ${it.message}") }
    }

    /// What the Ongoing Activity says: the workout's name and its clock.
    private data class Summary(val title: String, val clock: Long, val pausedAt: Long?)

    private var summary: Summary? = null

    /// The workout as an Ongoing Activity (#462): in the watch face's chip and
    /// the recents, one tap back to Heart, with the workout's name and its
    /// clock ticking — stopped while paused. Every word is the phone's.
    private fun describe() {
        val summary = summary ?: return
        if (workoutId == null) return
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        // the stopwatch counts on the boot clock, not the wall clock
        val now = System.currentTimeMillis()
        val zero = SystemClock.elapsedRealtime() - (now - summary.clock)
        val stopwatch = when (val pausedAt = summary.pausedAt) {
            null -> Status.StopwatchPart(zero)
            else -> Status.StopwatchPart(zero, SystemClock.elapsedRealtime() - (now - pausedAt))
        }
        val status = Status.Builder()
            .addTemplate("#title# · #clock#")
            .addPart("title", Status.TextPart(summary.title))
            .addPart("clock", stopwatch)
            .build()
        val builder = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_heart)
            .setContentTitle(summary.title)
            .setContentIntent(open)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
        OngoingActivity.Builder(this, NOTIFICATION, builder)
            .setStaticIcon(R.drawable.ic_heart)
            .setTouchIntent(open)
            .setStatus(status)
            .build()
            .apply(this)
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION, builder.build())
    }

    private fun rest(end: Long) {
        restAlarm?.cancel()
        if (workoutId == null || end <= System.currentTimeMillis()) return
        restAlarm = lifecycleScope.launch {
            delay(end - System.currentTimeMillis())
            val vibrator = getSystemService(VibratorManager::class.java).defaultVibrator
            vibrator.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 250, 120, 250), -1))
        }
    }

    private fun end() {
        lifecycleScope.launch {
            runCatching { exercises.endExerciseAsync().await() }
            stop()
        }
    }

    private fun stop() {
        restAlarm?.cancel()
        runCatching { exercises.clearUpdateCallbackAsync(updates) }
        workoutId = null
        Measuring.ended()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent): IBinder? {
        super.onBind(intent)
        return null
    }

    /// The foreground notification a running exercise needs. Tapping it brings
    /// the workout back.
    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        // the channel's name is the app's, which is never translated
        manager.createNotificationChannel(NotificationChannel(CHANNEL, getString(R.string.app_name), NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_heart)
            .setContentTitle(getString(R.string.app_name))
            .setContentIntent(open)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()
    }

    companion object {
        private const val TAG = "WorkoutService"
        private const val CHANNEL = "workout"
        private const val NOTIFICATION = 1

        private const val START = "start"
        private const val PAUSE = "pause"
        private const val RESUME = "resume"
        private const val END = "end"
        private const val REST = "rest"
        private const val REST_END = "restEnd"
        private const val DESCRIBE = "describe"
        private const val TITLE = "title"
        private const val CLOCK = "clock"
        private const val PAUSED_AT = "pausedAt"
        private const val WORKOUT_ID = "workoutId"
        private const val ACTIVITY = "activity"

        fun start(context: Context, workoutId: String, activity: String?) {
            val intent = Intent(context, WorkoutService::class.java)
                .setAction(START)
                .putExtra(WORKOUT_ID, workoutId)
                .putExtra(ACTIVITY, activity)
            ContextCompat.startForegroundService(context, intent)
        }

        fun follow(context: Context, paused: Boolean) = send(context, if (paused) PAUSE else RESUME)

        fun end(context: Context) = send(context, END)

        /// What the workout is called and where its clock stands, for the
        /// Ongoing Activity.
        fun describe(context: Context, title: String, clock: Long, pausedAt: Long?) {
            if (Measuring.now.value == null) return
            val intent = Intent(context, WorkoutService::class.java)
                .setAction(DESCRIBE)
                .putExtra(TITLE, title)
                .putExtra(CLOCK, clock)
                .putExtra(PAUSED_AT, pausedAt ?: 0)
            context.startService(intent)
        }

        /// The rest now running ends at [end], epoch milliseconds; 0 for none.
        fun rest(context: Context, end: Long) {
            if (Measuring.now.value == null) return
            context.startService(Intent(context, WorkoutService::class.java).setAction(REST).putExtra(REST_END, end))
        }

        /// Only to a service that is running: a pause or an end with nothing
        /// measuring has nothing to act on, and must not start one.
        private fun send(context: Context, action: String) {
            if (Measuring.now.value == null) return
            context.startService(Intent(context, WorkoutService::class.java).setAction(action))
        }

        /// `WorkoutActivity` names, as the phone sends them, to Health
        /// Services' — `activityType` in ios/Watch/WorkoutSession.swift, for Wear OS.
        fun exerciseType(activity: String?): ExerciseType = when (activity) {
            "strength" -> ExerciseType.STRENGTH_TRAINING
            "crossTraining", "mixedCardio" -> ExerciseType.WORKOUT
            "cycling" -> ExerciseType.BIKING
            "cyclingIndoor" -> ExerciseType.BIKING_STATIONARY
            "elliptical" -> ExerciseType.ELLIPTICAL
            "hiking" -> ExerciseType.HIKING
            "rowing" -> ExerciseType.ROWING_MACHINE
            "running" -> ExerciseType.RUNNING
            "runningTreadmill" -> ExerciseType.RUNNING_TREADMILL
            "skating" -> ExerciseType.SKATING
            "skiing" -> ExerciseType.SKIING
            "snowboarding" -> ExerciseType.SNOWBOARDING
            "swimming" -> ExerciseType.SWIMMING_POOL
            "walking" -> ExerciseType.WALKING
            "climbing" -> ExerciseType.ROCK_CLIMBING
            "coreTraining" -> ExerciseType.CALISTHENICS
            "flexibility" -> ExerciseType.STRETCHING
            "yoga" -> ExerciseType.YOGA
            "cardioDance" -> ExerciseType.DANCING
            "highIntensity" -> ExerciseType.HIGH_INTENSITY_INTERVAL_TRAINING
            "jumpRope" -> ExerciseType.JUMP_ROPE
            else -> ExerciseType.WORKOUT
        }
    }
}
