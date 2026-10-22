package me.heart.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.os.VibrationEffect
import android.os.Vibrator
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
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.ProcessLifecycleOwner
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
/// readings are shown on the wrist ([Measuring]), and reach Health Connect
/// only if the user said so ([Readings]).
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
/// and the readings join it there only with the user's say ([Readings]).
class WorkoutService : LifecycleService() {
    private val exercises by lazy { HealthServices.getClient(this).exerciseClient }
    private var workoutId: String? = null

    /// Which session this is. A start bumps it; anything that ends a session
    /// says which one it means, so an end or an "ended" update that arrives
    /// late can never stop the next one.
    private var generation = 0

    /// What this session measured, for the phone to save if the user said so
    /// (#461): one heart-rate sample per [Readings.SAMPLE_MS], and the energy
    /// total. Held in memory, and in [Readings] once the session is over.
    private var started = 0L
    private val heartRate = mutableListOf<Pair<Long, Double>>()
    private var energy: Double? = null

    /// The tap for the rest that is running (#462). Once the watch measures,
    /// the phone schedules no rest notification of its own — it would reach
    /// the same wrist a second time — so the watch owns the tap.
    private var restAlarm: Job? = null

    /// Keeps the CPU counting through a rest with the wrist down: a coroutine's
    /// delay runs on uptime, which stops while the watch sleeps.
    private val restWake by lazy {
        getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "heart:rest").apply {
            setReferenceCounted(false)
        }
    }

    private fun updates(generation: Int) = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            if (generation != this@WorkoutService.generation) return
            val boot = System.currentTimeMillis() - SystemClock.elapsedRealtime()
            val beats = update.latestMetrics.getData(DataType.HEART_RATE_BPM)
            beats.forEach { point ->
                val time = boot + point.timeDurationFromBoot.toMillis()
                if (heartRate.lastOrNull()?.let { time - it.first >= Readings.SAMPLE_MS } != false) heartRate += time to point.value
            }
            val total = update.latestMetrics.getData(DataType.CALORIES_TOTAL)?.total
            if (total != null) energy = total
            Measuring.read(beats.lastOrNull()?.value, total)
            // another app's exercise took over, or the system ended this one
            if (update.exerciseStateInfo.state.isEnded) stop(generation)
        }

        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) = Unit

        override fun onRegistered() = Unit

        override fun onRegistrationFailed(throwable: Throwable) {
            Log.w(TAG, "Exercise updates refused: ${throwable.message}")
        }

        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) = Unit
    }

    private var callback: ExerciseUpdateCallback? = null

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
        val previous = this.workoutId
        val generation = ++generation
        this.workoutId = workoutId
        started = System.currentTimeMillis()
        heartRate.clear()
        energy = null
        ServiceCompat.startForeground(this, NOTIFICATION, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        describe()
        lifecycleScope.launch {
            runCatching {
                // a workout before this one ends first, measured and kept as its own
                if (previous != null) {
                    keep(previous)
                    runCatching { exercises.endExerciseAsync().await() }
                }
                val callback = updates(generation).also { callback = it }
                // this process died mid-workout, and Health Services kept its
                // exercise: take it up again rather than start over
                val info = exercises.getCurrentExerciseInfoAsync().await()
                val resumed = info.exerciseTrackedStatus == ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS &&
                    prefs().getString(CURRENT, null) == workoutId
                exercises.setUpdateCallback(callback)
                if (!resumed) {
                    val capabilities = exercises.getCapabilitiesAsync().await()
                    val type = exerciseType(activity).takeIf { it in capabilities.supportedExerciseTypes } ?: ExerciseType.WORKOUT
                    // only what this exercise can measure: asking for more is refused whole
                    val dataTypes = setOf(DataType.HEART_RATE_BPM, DataType.CALORIES_TOTAL)
                        .intersect(capabilities.getExerciseTypeCapabilities(type).supportedDataTypes)
                    check(dataTypes.isNotEmpty()) { "Nothing to measure for $type" }
                    exercises.startExerciseAsync(
                        ExerciseConfig.builder(type)
                            .setDataTypes(dataTypes)
                            .setIsAutoPauseAndResumeEnabled(false)
                            .setIsGpsEnabled(false)
                            .build(),
                    ).await()
                }
                if (generation != this@WorkoutService.generation) return@launch
                prefs().edit().putString(CURRENT, workoutId).apply()
                Measuring.started(workoutId)
                tellPhone(workoutId)
            }.onFailure {
                // declined, or no sensors: nothing is measured, and everything
                // else about the watch app carries on
                Log.w(TAG, "Exercise did not start: ${it.message}")
                stop(generation)
            }
        }
    }

    /// Whether the watch measures [workoutId] — no reading, only the fact — so
    /// the phone leaves the rest's tap to it while it does (#462); empty when
    /// it stopped. Left as a data item, which reaches a phone app that isn't
    /// running.
    private suspend fun tellPhone(workoutId: String) {
        runCatching {
            val measuring = JSONObject().put("event", "measuring").put("workoutId", workoutId).put("at", System.currentTimeMillis())
            val request = PutDataRequest.create("${PhoneSession.EVENTS}/measuring").setData(measuring.toString().toByteArray()).setUrgent()
            Wearable.getDataClient(this).putDataItem(request).await()
        }.onFailure { Log.w(TAG, "The phone was not told whether the watch measures: ${it.message}") }
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
        if (restWake.isHeld) restWake.release()
        val left = end - System.currentTimeMillis()
        if (workoutId == null || left <= 0) return
        restWake.acquire(left + WAKE_SLACK_MS)
        restAlarm = lifecycleScope.launch {
            delay(left)
            vibrator().vibrate(VibrationEffect.createWaveform(longArrayOf(0, 250, 120, 250), -1))
            if (restWake.isHeld) restWake.release()
        }
    }

    /// The default vibrator: [VibratorManager] from Wear OS 4 (API 31), the
    /// old service before it.
    private fun vibrator(): Vibrator = when {
        Build.VERSION.SDK_INT >= 31 -> getSystemService(VibratorManager::class.java).defaultVibrator
        else -> @Suppress("DEPRECATION") getSystemService(Vibrator::class.java)
    }

    private fun end() {
        val generation = generation
        lifecycleScope.launch {
            runCatching { exercises.endExerciseAsync().await() }
            stop(generation)
        }
    }

    /// What [workoutId]'s session measured, kept for the phone (#461).
    private fun keep(workoutId: String) {
        Readings.keep(this, workoutId, started, System.currentTimeMillis(), heartRate.toList(), energy)
        heartRate.clear()
        energy = null
    }

    private fun stop(generation: Int) {
        if (generation != this.generation) return
        restAlarm?.cancel()
        if (restWake.isHeld) restWake.release()
        workoutId?.let { id ->
            keep(id)
            // coroutines of the app's own: this service is on its way out
            ProcessLifecycleOwner.get().lifecycleScope.launch {
                Readings.handOver(applicationContext)
                tellPhone("")
            }
        }
        callback?.let { runCatching { exercises.clearUpdateCallbackAsync(it) } }
        callback = null
        workoutId = null
        prefs().edit().remove(CURRENT).apply()
        Measuring.ended()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        if (restWake.isHeld) restWake.release()
        super.onDestroy()
    }

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

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
        private const val PREFS = "exercise"
        /// The workout an exercise was started for, kept past a process death.
        private const val CURRENT = "currentWorkout"
        private const val WAKE_SLACK_MS = 5_000L
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

        /// Ends the exercise. Running here, the service ends it; with this
        /// process gone and Health Services still holding the exercise it
        /// started, it is ended directly, so none is left running.
        fun end(context: Context) {
            if (Measuring.now.value != null) return send(context, END)
            val app = context.applicationContext
            val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.getString(CURRENT, null) == null) return
            ProcessLifecycleOwner.get().lifecycleScope.launch {
                runCatching {
                    val client = HealthServices.getClient(app).exerciseClient
                    val info = client.getCurrentExerciseInfoAsync().await()
                    if (info.exerciseTrackedStatus == ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) client.endExerciseAsync().await()
                }
                prefs.edit().remove(CURRENT).apply()
            }
        }

        /// Keeps a running exercise in step with what the phone now says — its
        /// rest, its pause, its name and clock, or its end — whether or not
        /// Heart is on screen: called by the app and by [StateListenerService].
        /// Never starts one; only the app on screen does.
        fun follow(context: Context, state: PhoneState) {
            val running = Measuring.now.value?.workoutId
            when {
                state is PhoneState.Awaiting -> Unit
                state !is PhoneState.Workout -> end(context)
                running == null -> Unit
                state.workoutId != running -> end(context)
                else -> {
                    rest(context, state.rest?.end ?: 0)
                    follow(context, paused = state.pausedAt != null)
                    describe(context, state.title, state.clock, state.pausedAt)
                }
            }
        }

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
