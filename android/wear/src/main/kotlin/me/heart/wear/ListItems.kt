package me.heart.wear

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumnItemScope
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.ListHeaderDefaults
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.Text
import androidx.wear.compose.material3.lazy.TransformationSpec
import androidx.wear.compose.material3.lazy.transformedHeight

// What keeps a list inside a round screen. Wear's lists do not do this by
// themselves: an item has to say how it shrinks as it nears the top and bottom
// edges, where the screen is narrow, and how far the first and last stay from
// them, which is what leaves the time its place.
//
// One item per thing on the page: an item shrinks as one, so a tall one reaches
// the edge at full width.

/// A list's padding: Wear's margin at the sides, the scaffold's at the ends.
@Composable
internal fun listPadding(scaffold: PaddingValues): PaddingValues {
    val margin = (LocalConfiguration.current.screenWidthDp * 0.052f).dp
    return PaddingValues(
        start = margin,
        end = margin,
        top = scaffold.calculateTopPadding(),
        // and the pager's dots, which sit over a list's last line otherwise
        bottom = scaffold.calculateBottomPadding() + 12.dp,
    )
}

/// For anything in a list that is not itself a button: text, or a row of things.
@Composable
internal fun TransformingLazyColumnItemScope.line(spec: TransformationSpec): Modifier =
    Modifier
        .fillMaxWidth()
        .transformedHeight(this, spec)
        // the content's fade too, not only the shape's: text scrolling up under
        // the clock went there at full strength
        .graphicsLayer {
            with(spec) {
                applyContainerTransformation(scrollProgress)
                applyContentTransformation(scrollProgress)
            }
        }
        .minimumVerticalContentPadding(
            top = ListHeaderDefaults.minimumTopListContentPadding,
            bottom = ListHeaderDefaults.minimumBottomListContentPadding,
        )

/// For a button in a list. It also takes a `SurfaceTransformation`, which narrows
/// its shape while its label stays put.
@Composable
internal fun TransformingLazyColumnItemScope.button(spec: TransformationSpec): Modifier =
    Modifier
        .fillMaxWidth()
        .transformedHeight(this, spec)
        .minimumVerticalContentPadding(ButtonDefaults.minimumVerticalListContentPadding)

/// An exercise's name, heading what follows. Its padding is what fits two lines
/// where a list begins, under the time.
@Composable
internal fun TransformingLazyColumnItemScope.ExerciseHeader(
    name: String,
    accent: Color,
    spec: TransformationSpec,
    large: Boolean = false,
) {
    ListHeader(
        // not a surface but a line of text, which has to shrink along with its
        // shape: two lines of a long name are as wide as the list
        modifier = line(spec),
        contentColor = accent,
    ) {
        Text(
            name,
            style = when (large) {
                true -> MaterialTheme.typography.titleMedium
                false -> MaterialTheme.typography.titleSmall
            },
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
    }
}
