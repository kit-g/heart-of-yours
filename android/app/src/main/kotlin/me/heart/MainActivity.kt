package me.heart

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.activity.OnBackPressedCallback
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

    // Back with nothing left to pop: background the task rather than destroy it.
    //
    // Flutter's default ends at `finish()`, so the next launch is a cold start —
    // engine, plugins, database and the account's history all over again.
    // Android users press back constantly and iOS has no equivalent gesture, so
    // the cost lands on one platform only. Backgrounding is what the platform's
    // own apps do, and it is what the user means: leave, not quit.
    //
    // Why a dispatcher callback and not an override. `FlutterActivity` exposes
    // `popSystemNavigator()` for exactly this, but `FlutterFragmentActivity`
    // does not — it delegates to the `FlutterFragment` it hosts, and we are on
    // the fragment variant for the Health Connect reason above. The fragment's
    // own `popSystemNavigator` disables its `OnBackPressedCallback` and
    // re-dispatches through the activity, which is what falls through to
    // `finish()`. Registering here catches precisely that fall-through.
    //
    // Order is the whole trick, and it is why this is added without a
    // `LifecycleOwner`: a bare `addCallback` enters the dispatcher immediately,
    // before `super.onCreate` creates the Flutter fragment, so Flutter's
    // callback lands *above* ours. The dispatcher runs the topmost enabled
    // callback, so Flutter still sees every back first and every in-app back —
    // a route, a sheet, a dialog — behaves exactly as before. Ours runs only on
    // the re-dispatch, once Dart has said there is nothing to pop.
    private val backgroundInsteadOfFinishing = object : OnBackPressedCallback(true) {
        override fun handleOnBackPressed() {
            moveTaskToBack(true)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        onBackPressedDispatcher.addCallback(backgroundInsteadOfFinishing)
        super.onCreate(savedInstanceState)
    }

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
