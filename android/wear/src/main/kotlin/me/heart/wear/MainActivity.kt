package me.heart.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

/// Heart on the wrist (#250): a remote for the workout the phone is running,
/// the Wear OS twin of the Apple Watch app (ios/Watch, #175).
///
/// The phone owns the workout; this app holds nothing of its own but the last
/// state the phone sent. Every string it shows arrives from the phone, already
/// localised.
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        setContent {
            HeartTheme {
                PhoneStateScreen(state = PhoneState.Awaiting)
            }
        }
    }
}
