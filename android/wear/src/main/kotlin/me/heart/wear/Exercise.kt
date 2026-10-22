package me.heart.wear

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.currentStateAsState

/// Keeps the watch's exercise (#461) in step with what the phone shows: started
/// for a workout while Heart is on screen — never otherwise — paused with it,
/// and ended when the phone has no workout. The twin of the session triggers in
/// ios/Watch/HeartWatchApp.swift.
///
/// The sensors are asked for here, in context: the first time a session would
/// start, after the user already opted in by opening the app. Declined, nothing
/// is measured and everything else works; the system's own sheet is not shown
/// again by Heart.
@Composable
fun ExerciseFollowing(state: PhoneState) {
    val context = LocalContext.current
    val lifecycle by LocalLifecycleOwner.current.lifecycle.currentStateAsState()
    val onScreen = lifecycle.isAtLeast(Lifecycle.State.RESUMED)
    val workout = state as? PhoneState.Workout
    var granted by remember { mutableStateOf(sensors(context)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        granted = sensors(context)
    }

    LaunchedEffect(workout?.workoutId, onScreen, granted) {
        when {
            workout == null -> WorkoutService.end(context)
            !onScreen -> Unit
            granted -> WorkoutService.start(context, workout.workoutId, workout.activity)
            !asked(context) -> {
                markAsked(context)
                ask.launch(permissions())
            }
        }
    }
    LaunchedEffect(workout?.pausedAt != null) {
        if (workout != null) WorkoutService.follow(context, paused = workout.pausedAt != null)
    }
    // the rest's tap is the watch's while it measures (#462)
    val measuring by Measuring.now.collectAsStateWithLifecycle()
    LaunchedEffect(workout?.rest?.end, measuring?.workoutId) {
        WorkoutService.rest(context, workout?.rest?.end ?: 0)
    }
}

/// Heart rate is the one reading that needs the user's grant; the rest of
/// what [permissions] asks only rounds the session out.
private fun sensors(context: Context): Boolean {
    val heartRate = when {
        Build.VERSION.SDK_INT >= 36 -> "android.permission.health.READ_HEART_RATE"
        else -> Manifest.permission.BODY_SENSORS
    }
    return ContextCompat.checkSelfPermission(context, heartRate) == PackageManager.PERMISSION_GRANTED
}

private fun permissions(): Array<String> = listOfNotNull(
    when {
        Build.VERSION.SDK_INT >= 36 -> "android.permission.health.READ_HEART_RATE"
        else -> Manifest.permission.BODY_SENSORS
    },
    Manifest.permission.ACTIVITY_RECOGNITION,
    if (Build.VERSION.SDK_INT >= 33) Manifest.permission.POST_NOTIFICATIONS else null,
).toTypedArray()

private const val PREFS = "exercise"
private const val ASKED = "sensorsAsked"

private fun asked(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(ASKED, false)

private fun markAsked(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ASKED, true).apply()
