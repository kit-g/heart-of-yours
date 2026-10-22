package me.heart.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.getValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope

/// Heart on the wrist (#250): a remote for the workout the phone is running,
/// the Wear OS twin of the Apple Watch app (ios/Watch, #175).
///
/// The phone owns the workout; this app holds nothing of its own but the last
/// state the phone sent. Every string it shows arrives from the phone, already
/// localised.
class MainActivity : ComponentActivity() {
    private lateinit var phone: PhoneSession

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        phone = PhoneSession(this, lifecycleScope)
        setContent {
            val state by phone.state.collectAsStateWithLifecycle()
            val reachable by phone.reachable.collectAsStateWithLifecycle()
            HeartTheme {
                PhoneStateScreen(state = state, reachable = reachable, send = phone::send)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        phone.start()
    }

    override fun onStop() {
        phone.stop()
        super.onStop()
    }
}
