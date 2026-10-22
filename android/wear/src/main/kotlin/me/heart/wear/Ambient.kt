package me.heart.wear

import androidx.activity.ComponentActivity
import androidx.compose.runtime.compositionLocalOf
import androidx.wear.ambient.AmbientLifecycleObserver
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/// The wrist down with Heart on screen (#462): the system keeps the app
/// showing, dimmed, and wakes it once a minute. The twin of watchOS's
/// `isLuminanceReduced`, which the Apple Watch page reads.
///
/// While ambient the page drops its controls — nothing can be tapped until the
/// wrist comes up — draws no fills, and shows no seconds: what it shows has to
/// stay true for a minute at a time.
class Ambient(activity: ComponentActivity) {
    private val _state = MutableStateFlow(State())

    val state: StateFlow<State> = _state.asStateFlow()

    /// Whether the screen is dimmed, and the last minute the system woke the
    /// app to redraw.
    data class State(val dimmed: Boolean = false, val tick: Long = 0)

    private val observer = AmbientLifecycleObserver(
        activity,
        object : AmbientLifecycleObserver.AmbientLifecycleCallback {
            override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
                _state.value = State(dimmed = true, tick = System.currentTimeMillis())
            }

            override fun onUpdateAmbient() {
                _state.value = _state.value.copy(tick = System.currentTimeMillis())
            }

            override fun onExitAmbient() {
                _state.value = State()
            }
        },
    )

    init {
        activity.lifecycle.addObserver(observer)
    }
}

/// Whether the page is drawn for the wrist down.
val LocalDimmed = compositionLocalOf { false }

/// When the system last woke the dimmed page to redraw it, once a minute.
val LocalAmbientTick = compositionLocalOf { 0L }
