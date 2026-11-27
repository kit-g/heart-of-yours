package me.heart

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// The app's half of the `heart/sounds` channel (#169): plays one of the
/// sounds in `res/raw`, the files the rest's notification channels play too.
///
/// On the notification stream, so the device's own rules for a notification
/// apply: a silent or vibrating ringer and Do Not Disturb keep it quiet, and
/// its volume is a share of the notification volume. Checked here as well, not
/// left to the mixer, because some devices route a zen-muted notification
/// stream through anyway. A transient focus request that may duck dips the
/// user's music for as long as the sound lasts; it is given back on
/// completion, which brings the music back up.
object SoundsChannel {
    private val attributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "heart/sounds").setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val name = call.argument<String>("name")
                    val volume = call.argument<Double>("volume")
                    if (name == null || volume == null) {
                        result.error("bad_arguments", "play needs a name and a volume", null)
                    } else {
                        result.success(play(app, name, volume.toFloat()))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Whether [name] started: false for a device told to be quiet, a sound
    /// not in the APK, or a player that would not start.
    private fun play(context: Context, name: String, volume: Float): Boolean {
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
        if (notifications.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL) return false

        // named from Dart only: kept from the shrinker by res/raw/keep.xml
        @Suppress("DiscouragedApi")
        val id = context.resources.getIdentifier(name, "raw", context.packageName)
        if (id == 0) return false
        val player = MediaPlayer.create(context, id, attributes, audio.generateAudioSessionId()) ?: return false

        val focus = requestFocus(audio)
        player.setVolume(volume.coerceIn(0f, 1f), volume.coerceIn(0f, 1f))
        player.setOnCompletionListener {
            it.release()
            abandonFocus(audio, focus)
        }
        player.start()
        return true
    }

    // minSdk is 26: the request object is always there to give back
    private fun requestFocus(audio: AudioManager): AudioFocusRequest {
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
            .setAudioAttributes(attributes)
            .build()
        audio.requestAudioFocus(request)
        return request
    }

    private fun abandonFocus(audio: AudioManager, request: AudioFocusRequest) {
        audio.abandonAudioFocusRequest(request)
    }
}
