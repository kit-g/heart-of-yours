import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/health/metric.dart';
import 'package:heart/presentation/widgets/redacted.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

/// The full series behind a dashboard card.
///
/// The card's sparkline is a shape, not a reading: no axes, no scale, and
/// bucketed down to 24 points so a quarter's worth of spiky daily data still
/// reads as a trend. That is the right thing on a 96pt card and useless for
/// answering "how much, when". This is where the numbers live — on
/// [TimelineChart], which is the app's own chart with a window you can travel
/// through.
Future<void> showHealthMetricDetail(
  BuildContext context, {
  required HealthMetric metric,
  required List<HealthDailyValue> series,
}) {
  final settings = Preferences.of(context);
  final l = L.of(context);

  return showBrandedDialog(
    context,
    title: Text(metric.label(l), textAlign: .center),
    content: _HealthMetricDetail(metric: metric, series: series, settings: settings, l: l),
    // Tighter than the branded default: the plot wants every point of width it
    // can get, and its own axis labels already sit inside this box.
    padding: const .only(left: 8, right: 8, bottom: 12),
    actions: [
      PrimaryButton.wide(
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        child: Center(child: Text(l.close)),
      ),
    ],
  );
}

class const _HealthMetricDetail({
  required final HealthMetric metric,
  required final List<HealthDailyValue> series,
  required final Preferences settings,
  required final L l,
}) extends StatelessWidget {
  /// Fixed, not an aspect ratio. The content here is a plot and a line of text,
  /// neither of which has anything to do with how wide the window is — and a
  /// ratio inside a dialog already capped at [dialogWidth] is how you get a
  /// chart taller than the screen on an iPad.
  static const _chartHeight = 260.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final latest = series.last;
    final (value, unit) = metric.display(latest.value, settings, l);

    return RedactedInCapture(
      child: SizedBox(
        // An explicit width, and not for looks. `AlertDialog` wraps its column
        // in an `IntrinsicWidth`, and `HistoryChart` contains a `LayoutBuilder`,
        // which refuses to answer an intrinsic query — the dialog throws
        // "LayoutBuilder does not support returning intrinsic dimensions" and
        // renders nothing. A `SizedBox` answers for it without descending.
        //
        // `MediaQuery` is the right measure here for once: a dialog is centred
        // in the window, never inside a pane.
        width: min(dialogWidth, MediaQuery.sizeOf(context).width - 72),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            // The reading the card was showing, kept on screen so opening the
            // detail never looks like it changed the number. It stays the real
            // latest reading however far the chart is zoomed out.
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: value, style: textTheme.headlineSmall),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
              textAlign: .center,
            ),
            Text(
              l.healthLatestReading(DateFormat.MMMd(l.localeName).format(latest.day)),
              textAlign: .center,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TimelineChart(
              height: _chartHeight,
              leftAxisSize: metric.axisWidth,
              yStepCandidates: metric.yStepCandidates,
              getLeftLabel: metric.leftLabel(textTheme.bodySmall, settings, l),
              getTooltip: metric.tooltip(settings, l),
              series: [
                for (final point in series) (at: point.day, value: metric.plot(point.value, settings)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
