package me.heart

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// `FlutterFragmentActivity`, not `FlutterActivity`, and not by preference: the
// health plugin registers an `ActivityResultLauncher` for the Health Connect
// permission sheets, and `registerForActivityResult` requires a host with the
// fragment lifecycle. On a plain `FlutterActivity` the plugin logs "Permission
// launcher not found" and every request fails silently — which reads exactly
// like a declined permission.
class MainActivity : FlutterFragmentActivity() {
    private val channel = "me.heart/device"

    /// Declared by the `heart_health` package, which has no native side of its
    /// own. Keep the name in sync with `healthPlatformChannel`.
    private val healthChannel = "heart_health/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isFirebaseTestLab" -> result.success(isFirebaseTestLab())
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, healthChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "openHealthConnectSettings" -> result.success(openHealthConnectSettings())
                else -> result.notImplemented()
            }
        }
    }

    // Google's documented signal: the system setting is "true" whenever the app
    // runs under Firebase Test Lab / Play pre-launch report (virtual or physical).
    private fun isFirebaseTestLab(): Boolean {
        return "true" == Settings.System.getString(contentResolver, "firebase.test.lab")
    }

    // Where Health Connect keeps what this app may read. An implicit intent
    // rather than a URL, which is the whole reason this method exists: neither
    // `url_launcher` nor the health plugin can fire one.
    //
    // Two actions, newest first, because Health Connect has moved. It began as a
    // separate app answering an androidx action; Android 14 absorbed it into the
    // platform under `android.health.connect`, and by Android 16 the androidx
    // action resolves to nothing at all — verified on a Pixel 7 running 16.
    //
    // `MANAGE_HEALTH_PERMISSIONS` is not on the list, though it is the one that
    // would land on *this app's* permissions rather than Health Connect's home.
    // It is barred to normal apps: starting it throws
    //   SecurityException: … requires android.permission.GRANT_RUNTIME_PERMISSIONS
    // which is signature-level. There is no version of this app that can use it.
    private fun openHealthConnectSettings(): Boolean {
        val attempts = listOf(
            Intent(HEALTH_HOME_SETTINGS),
            Intent(LEGACY_HEALTH_CONNECT_SETTINGS),
        )

        for (intent in attempts) {
            try {
                startActivity(intent)
                return true
            } catch (error: Exception) {
                // Next rung. An unresolvable implicit intent is the normal answer
                // on any given Android version — only all three failing is news,
                // and the reason differs per rung, so say which.
                android.util.Log.w("HeartHealth", "Could not open ${intent.action}", error)
            }
        }

        return false
    }

    private companion object {
        // Platform constants, inlined rather than taking a dependency on the
        // Health Connect client just to name two strings — the platform's
        // HealthConnectManager.ACTION_HEALTH_HOME_SETTINGS and, for Android 13
        // and earlier, androidx's HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS.
        const val HEALTH_HOME_SETTINGS = "android.health.connect.action.HEALTH_HOME_SETTINGS"
        const val LEGACY_HEALTH_CONNECT_SETTINGS = "androidx.health.connect.action.HEALTH_CONNECT_SETTINGS"
    }
}
