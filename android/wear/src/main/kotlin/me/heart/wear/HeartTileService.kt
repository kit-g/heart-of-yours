package me.heart.wear

import android.content.Context
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.TypeBuilders
import androidx.wear.protolayout.expression.DynamicBuilders.DynamicInstant
import androidx.wear.protolayout.expression.DynamicBuilders.DynamicString
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import androidx.concurrent.futures.CallbackToFutureAdapter
import com.google.common.util.concurrent.ListenableFuture
import java.time.Instant

/// Heart's Tile (#463): a swipe from the watch face to the workout — the
/// exercise, and the rest counting down or the set up next — and the Heart
/// mark when no workout runs. A tap opens the app.
///
/// What it shows is the [Snapshot] the app keeps; the countdown is a dynamic
/// value the system ticks, so the Tile is redrawn only when the workout
/// changes. Wear OS's counterpart of the Smart Stack, which the Apple Watch
/// app leaves to the lock screen's Live Activity.
class HeartTileService : TileService() {
    override fun onTileRequest(request: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> {
        val workout = Snapshot.read(this)
        val tile = TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES)
            .setTileTimeline(timeline(this, workout))
            .build()
        return CallbackToFutureAdapter.getFuture { it.set(tile) }
    }

    override fun onTileResourcesRequest(request: RequestBuilders.ResourcesRequest): ListenableFuture<ResourceBuilders.Resources> {
        val mark = ResourceBuilders.ImageResource.Builder()
            .setAndroidResourceByResId(ResourceBuilders.AndroidImageResourceByResId.Builder().setResourceId(R.drawable.ic_heart).build())
            .build()
        val resources = ResourceBuilders.Resources.Builder().setVersion(RESOURCES).addIdToImageMapping(MARK, mark).build()
        return CallbackToFutureAdapter.getFuture { it.set(resources) }
    }

    private companion object {
        const val RESOURCES = "1"
        const val MARK = "mark"
        const val INK = 0xFFF1F2E9.toInt()
        const val MUTED = 0xFF9BA092.toInt()

        /// One entry now, and one from when the rest ends, so a countdown that
        /// runs out gives way to the set up next on its own — the Apple Watch
        /// complication's timeline, for a Tile.
        fun timeline(context: Context, workout: Snapshot?): TimelineBuilders.Timeline {
            val rest = workout?.rest?.takeIf { it.last > System.currentTimeMillis() }
                ?: return TimelineBuilders.Timeline.fromLayoutElement(layout(context, workout, resting = false))
            fun entry(resting: Boolean, validity: TimelineBuilders.TimeInterval) = TimelineBuilders.TimelineEntry.Builder()
                .setLayout(LayoutElementBuilders.Layout.Builder().setRoot(layout(context, workout, resting)).build())
                .setValidity(validity)
                .build()
            return TimelineBuilders.Timeline.Builder()
                .addTimelineEntry(entry(true, TimelineBuilders.TimeInterval.Builder().setEndMillis(rest.last).build()))
                .addTimelineEntry(entry(false, TimelineBuilders.TimeInterval.Builder().setStartMillis(rest.last).build()))
                .build()
        }

        fun layout(context: Context, workout: Snapshot?, resting: Boolean): LayoutElementBuilders.LayoutElement {
            val open = ModifiersBuilders.Modifiers.Builder()
                .setClickable(
                    ModifiersBuilders.Clickable.Builder()
                        .setId("open")
                        .setOnClick(
                            ActionBuilders.LaunchAction.Builder()
                                .setAndroidActivity(
                                    ActionBuilders.AndroidActivity.Builder()
                                        .setPackageName(context.packageName)
                                        .setClassName(MainActivity::class.java.name)
                                        .build(),
                                )
                                .build(),
                        )
                        .build(),
                )
                .build()

            val column = LayoutElementBuilders.Column.Builder()
                .setWidth(expand())
                .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
                .setModifiers(open)
                .addContent(
                    LayoutElementBuilders.Image.Builder()
                        .setResourceId(MARK)
                        .setWidth(dp(24f))
                        .setHeight(dp(24f))
                        .setColorFilter(LayoutElementBuilders.ColorFilter.Builder().setTint(argb(MUTED)).build())
                        .build(),
                )

            if (workout == null) {
                column.addContent(text(context.getString(R.string.app_name), 16f, MUTED))
            } else {
                column.addContent(spacer())
                column.addContent(text(workout.exercise, 16f, INK, lines = 2))
                column.addContent(spacer())
                column.addContent(
                    when (val rest = workout.rest?.takeIf { resting }) {
                        null -> text(workout.next, 14f, MUTED, lines = 2)
                        else -> countdown(rest.last)
                    },
                )
            }

            return LayoutElementBuilders.Box.Builder()
                .setWidth(expand())
                .setHeight(expand())
                .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
                .addContent(column.build())
                .build()
        }

        /// The rest counting down to [end], by the system's clock, not by redraws.
        private fun countdown(end: Long): LayoutElementBuilders.LayoutElement {
            val left = DynamicInstant.platformTimeWithSecondsPrecision()
                .durationUntil(DynamicInstant.withSecondsPrecision(Instant.ofEpochMilli(end)))
            val seconds = left.toIntSeconds()
            val minutes = seconds.div(60)
            val countdown = minutes.format()
                .concat(DynamicString.constant(":"))
                .concat(
                    DynamicString.onCondition(seconds.rem(60).lt(10))
                        .use(DynamicString.constant("0").concat(seconds.rem(60).format()))
                        .elseUse(seconds.rem(60).format()),
                )
            // past the end, until the next entry takes over
            val shown = DynamicString.onCondition(seconds.gt(0))
                .use(countdown)
                .elseUse(DynamicString.constant("0:00"))
            return LayoutElementBuilders.Text.Builder()
                .setText(TypeBuilders.StringProp.Builder("0:00").setDynamicValue(shown).build())
                .setLayoutConstraintsForDynamicText(TypeBuilders.StringLayoutConstraint.Builder("00:00").build())
                .setMaxLines(1)
                .setFontStyle(LayoutElementBuilders.FontStyle.Builder().setSize(sp(28f)).setColor(argb(INK)).build())
                .build()
        }

        private fun text(value: String, size: Float, color: Int, lines: Int = 1) = LayoutElementBuilders.Text.Builder()
            .setText(value)
            .setMaxLines(lines)
            .setFontStyle(LayoutElementBuilders.FontStyle.Builder().setSize(sp(size)).setColor(argb(color)).build())
            .build()

        private fun spacer() = LayoutElementBuilders.Spacer.Builder().setHeight(dp(6f)).build()

    }
}
