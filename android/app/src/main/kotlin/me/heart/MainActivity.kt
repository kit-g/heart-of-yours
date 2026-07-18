package me.heart

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "me.heart/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isFirebaseTestLab" -> result.success(isFirebaseTestLab())
                else -> result.notImplemented()
            }
        }
    }

    // Google's documented signal: the system setting is "true" whenever the app
    // runs under Firebase Test Lab / Play pre-launch report (virtual or physical).
    private fun isFirebaseTestLab(): Boolean {
        return "true" == Settings.System.getString(contentResolver, "firebase.test.lab")
    }
}
