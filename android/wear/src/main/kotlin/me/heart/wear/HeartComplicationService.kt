package me.heart.wear

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.CountDownTimeReference
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.MonochromaticImageComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.data.TimeDifferenceComplicationText
import androidx.wear.watchface.complications.data.TimeDifferenceStyle
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import java.time.Instant

/// Heart on the watch face (#463): the workout at a glance while one is
/// running — the rest counting down, or the exercise — and the Heart mark
/// otherwise; a tap opens the app either way. The twin of
/// ios/WatchWidgets/HeartComplication.swift.
///
/// The countdown runs on the watch face itself, so nothing is redrawn per
/// second; once the rest is over it stops at zero until the next state.
class HeartComplicationService : SuspendingComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? =
        data(request.complicationType, Snapshot.read(this))

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val now = System.currentTimeMillis()
        return data(type, Snapshot("Bench Press", "Next: 60 kg × 5", now, now + 75_000, "Rest"))
    }

    private fun data(type: ComplicationType, workout: Snapshot?): ComplicationData? {
        val mark = MonochromaticImage.Builder(Icon.createWithResource(this, R.drawable.ic_heart)).build()
        val name = PlainComplicationText.Builder(getString(R.string.app_name)).build()
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val rest = workout?.rest?.takeIf { it.last > System.currentTimeMillis() }
        val countdown = rest?.let {
            TimeDifferenceComplicationText.Builder(TimeDifferenceStyle.STOPWATCH, CountDownTimeReference(Instant.ofEpochMilli(it.last)))
                .build()
        }
        val exercise = workout?.let { PlainComplicationText.Builder(it.exercise).build() }

        return when (type) {
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(countdown ?: exercise ?: name, exercise ?: name)
                .setMonochromaticImage(mark)
                .setTapAction(open)
                .build()
            ComplicationType.LONG_TEXT -> {
                val text = countdown ?: workout?.let { PlainComplicationText.Builder(it.next).build() } ?: name
                LongTextComplicationData.Builder(text, exercise ?: name)
                    .setTitle(exercise)
                    .setMonochromaticImage(mark)
                    .setTapAction(open)
                    .build()
            }
            ComplicationType.MONOCHROMATIC_IMAGE -> MonochromaticImageComplicationData.Builder(mark, name)
                .setTapAction(open)
                .build()
            else -> null
        }
    }
}
