import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/feedback_button.dart';
import 'package:heart/presentation/widgets/health/detail.dart';
import 'package:heart/presentation/widgets/health/metric.dart';
import 'package:heart/presentation/widgets/health/permissions.dart';
import 'package:heart/presentation/widgets/redacted.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart/presentation/widgets/responsive/columns.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

/// Widest a health card gets before the grid adds a column instead.
///
/// Wider than a chart card because the card is a row, not a plot: a label and a
/// value on the left, a sparkline on the right. On a phone this lands on one
/// column, which is the point — two columns of 170pt leave a sparkline too
/// narrow to read a three-month trend off.
const _maxHealthCardWidth = 420.0;

/// Fixed rather than derived from an aspect ratio, because the card's content is
/// three lines of text whose height has nothing to do with how wide the window
/// is. A ratio here is how you end up with a 900pt square holding two lines.
const _healthCardHeight = 96.0;

/// Health metrics read from the device's store, below the workout charts.
///
/// Deliberately not part of [Charts] and not a [ChartPreferenceType]. That
/// vocabulary is per-exercise by construction — every preference names an
/// exercise — while these six are global, fixed, and not something the user adds
/// one at a time. They share the card language and nothing else.
///
/// Four states — absent, an invitation, a dormant header, the cards — and which
/// one shows is driven by [Health.hasData] rather than by any permission check.
/// iOS will not disclose whether read access was granted, so "connected" is not
/// a thing this app can know; see [HealthAccess.unknown].
///
/// Only one of them asks the user for anything, and it asks once. Everything
/// after that is the header alone: the two situations behind an empty section —
/// declined, and granted but no watch — are indistinguishable to us and neither
/// is fixable from this page, so a card that reappears every launch to report
/// one of them is pure nagging.
class const HealthSection({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final health = Health.watch(context);
    final settings = Preferences.watch(context);
    final l = L.of(context);

    // Web and desktop have no health store. The feature is absent there, not
    // empty — an empty section invites a user to fix something they can't.
    if (!health.isSupported) return const SliverToBoxAdapter(child: SizedBox.shrink());

    // Android reports a missing or outdated Health Connect here. Until Tier 2
    // ships the permissions to go with it, staying silent is the honest move.
    if (health.status != HealthStoreStatus.available) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (!health.initialized) return const SliverToBoxAdapter(child: SizedBox.shrink());

    final metrics = health.available.toList();
    final userId = health.userId;

    // Every visible state wears the same header, so the section reads as one
    // thing whether it is offering, dormant or showing data — and "On this
    // device" is on screen from the first moment, not only once there is
    // something to hide.
    Widget headed(Widget sliver) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _HealthHeader(l: l)),
          sliver,
        ],
      );
    }

    if (metrics.isEmpty) {
      // Waved away, so it stays away — a card that returns every launch is the
      // definition of nagging. The way back in is [HealthSettings], which is
      // why that block is the feature's only permanent home.
      if (settings.healthInviteDismissed(userId) && !settings.healthAsked(userId)) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      // Asked, and nothing came back. Once the question has been put, the
      // section stops asking it: no card, no button, just a greyed header and
      // an explanation for whoever goes looking. A user who declined has said
      // so, and one who granted but owns no watch never had an answer to give
      // — neither is served by a card that reappears every launch to report a
      // state they cannot change from here.
      if (settings.healthAsked(userId)) {
        return SliverToBoxAdapter(
          child: _HealthHeader(l: l, off: true, busy: health.syncing),
        );
      }

      return headed(
        _HealthNotice(
          body: l.healthInviteBody,
          action: l.healthInviteAction,
          onAction: () async {
            await health.connect();
            if (context.mounted) Preferences.of(context).setHealthAsked(userId);
          },
          onDismiss: () => settings.dismissHealthInvite(userId),
          dismissTooltip: l.healthInviteDismiss,
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _HealthHeader(l: l)),
        SliverPadding(
          padding: const .only(left: 16, right: 16, bottom: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  // The width this grid was handed, not the window's — inside a
                  // two-pane layout those are wildly different numbers.
                  crossAxisCount: columnsFor(constraints.crossAxisExtent, maxExtent: _maxHealthCardWidth),
                  mainAxisExtent: _healthCardHeight,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: metrics.length,
                  (context, index) {
                    final metric = metrics[index];
                    return _HealthCard(
                      metric: metric,
                      series: health[metric],
                      settings: settings,
                      l: l,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// What marks these cards as a different *kind* of data from the workout charts
/// above them. The subtitle is the whole device-only promise, stated once and
/// without ceremony.
class const _HealthHeader({
  required final L l,

  /// Asked, and reading nothing. The header is all that is left of the section,
  /// so it carries the state itself rather than a card underneath it.
  final bool off = false,
  final bool busy = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :disabledColor) = Theme.of(context);
    final subdued = off ? disabledColor : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const .only(left: 16, right: 16, top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  l.health,
                  style: switch (off) {
                    true => textTheme.titleLarge?.copyWith(color: disabledColor),
                    false => textTheme.titleLarge,
                  },
                ),
                Text(l.healthOnThisDevice, style: textTheme.bodySmall?.copyWith(color: subdued)),
              ],
            ),
          ),
          switch ((off, busy)) {
            // A read really is in flight — the seconds after coming back from
            // granting access. Without this the header looks identical whether
            // or not anything is happening, which is what the trip out was
            // supposed to fix.
            (true, true) => Tooltip(
              message: l.healthChecking,
              triggerMode: .tap,
              child: SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: subdued),
              ),
            ),
            // A button, not a tooltip: the explanation is the smaller half of
            // this. What the user actually needs is the trip out, and only a
            // dialog can carry both.
            (true, false) => IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              iconSize: 20,
              color: subdued,
              tooltip: l.healthOffTitle,
              // Square and explicit. Left to the M3 defaults this button
              // inherits a 40pt minimum inside a 48pt tap target and lands as
              // an oval splash sitting off the text's centre line — a
              // `visualDensity` away from being right, which is exactly the
              // kind of thing only a screenshot catches.
              padding: .zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              onPressed: () => showHealthOffDialog(context, Health.of(context), l),
            ),
            _ => const SizedBox.shrink(),
          },
        ],
      ),
    );
  }
}

/// The invitation and the empty state — the same card with different copy, since
/// they occupy the same slot and differ only in what they can honestly say.
///
/// Untitled by design: the section header sits above it, the way the goals card
/// next door is titled. Repeating "Health data" inside the card as well made the
/// two neighbours look like different kinds of thing.
class const _HealthNotice({
  required final String body,
  required final String action,
  required final VoidCallback onAction,
  final VoidCallback? onDismiss,
  final String? dismissTooltip,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const .only(left: 16, right: 16, bottom: 16),
        child: Align(
          alignment: .centerLeft,
          // Prose, so it gets a measure rather than the full width of an iPad.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: Container(
              decoration: BoxDecoration(
                border: .all(color: dividerColor, width: .5),
                borderRadius: const .all(.circular(12)),
              ),
              padding: const .all(16),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Expanded(child: Text(body, style: textTheme.bodyMedium)),
                      // Beside the copy rather than above it: with the title
                      // gone there is no header row left to hang it on.
                      if (onDismiss case VoidCallback dismiss) ...[
                        const SizedBox(width: 8),
                        FeedbackButton.circular(
                          tooltip: dismissTooltip,
                          onPressed: dismiss,
                          child: Icon(Icons.close_rounded, size: 20, color: dividerColor),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: .centerRight,
                    child: PrimaryButton.shrunk(
                      onPressed: onAction,
                      child: Text(action),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _HealthCard({
  required final HealthMetric metric,
  required final List<HealthDailyValue> series,
  required final Preferences settings,
  required final L l,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final latest = series.last;
    final (value, unit) = metric.display(latest.value, settings, l);

    return Material(
      color: Colors.transparent,
      clipBehavior: .antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: InkWell(
        // A single reading has no trend to open, and the sparkline beside it is
        // already blank for the same reason. An inert card is honest; one that
        // opens onto a lone dot is not.
        onTap: switch (series.length) {
          < 2 => null,
          _ => () => showHealthMetricDetail(context, metric: metric, series: series),
        },
        child: _content(textTheme, colorScheme, value, unit, latest),
      ),
    );
  }

  /// The window the sparkline draws, and the one its detail opens on.
  ///
  /// Not the whole series: the mirror reaches as far back as the platform does,
  /// and a thumbnail showing three years beside a detail showing three months
  /// cannot agree about the shape of anything. Not a fixed window either —
  /// [TimelineChart.openingRange] widens it for a metric recorded every few
  /// weeks, because three months of body mass can be a single weigh-in and one
  /// point draws nothing at all.
  List<HealthDailyValue> get _recent {
    final points = [for (final point in series) (at: point.day, value: point.value)];
    final days = TimelineChart.openingRange(points).days;
    if (days == null) return series;

    final from = series.last.day.subtract(Duration(days: days));
    final start = series.indexWhere((point) => !point.day.isBefore(from));
    return switch (start) {
      <= 0 => series,
      _ => series.sublist(start),
    };
  }

  Widget _content(
    TextTheme textTheme,
    ColorScheme colorScheme,
    String value,
    String unit,
    HealthDailyValue latest,
  ) {
    final plotted = _recent;

    return Padding(
      padding: const .all(12),
      child: Row(
        children: [
          Expanded(
            // A reading with no trend behind it gets the whole card. Reserving
            // the plot's share of the width and putting a lone mark in it reads
            // as a chart that failed, not as a metric with one day of history —
            // and an empty right-hand third reads worse still.
            flex: switch (plotted.length) {
              < 2 => 9,
              _ => 5,
            },
            child: Column(
              crossAxisAlignment: .start,
              mainAxisAlignment: .center,
              children: [
                Text(
                  metric.label(l),
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
                const SizedBox(height: 2),
                RedactedInCapture(
                  child: Row(
                    crossAxisAlignment: .baseline,
                    textBaseline: .alphabetic,
                    children: [
                      Text(value, style: textTheme.headlineSmall),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 3),
                        Text(unit, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                // A reading is only as current as the day it was taken. Without
                // this, three-week-old resting HR reads as today's.
                Text(
                  DateFormat.MMMd().format(latest.day),
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (plotted.length >= 2)
            Expanded(
              flex: 4,
              child: RedactedInCapture(
                child: _Sparkline(series: plotted, color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The dashboard chart language stripped to its line: no axes, no grid, no
/// touch. The card already says what the number is; this only has to show which
/// way it has been going.
class const _Sparkline({required final List<HealthDailyValue> series, required final Color color})
    extends StatelessWidget {
  /// Beyond this the line stops being a trend and becomes a comb.
  ///
  /// Ninety daily readings across the ~180pt this gets is half a point each, and
  /// health data is genuinely spiky day to day — a rest day next to a hike, a
  /// bad night next to a good one. Averaging into buckets keeps the shape and
  /// drops the noise that was burying it. The card's big number is still the
  /// real latest reading; only the line is smoothed.
  static const _maxPoints = 24;

  List<double> get _plotted {
    if (series.length <= _maxPoints) return [for (final point in series) point.value];

    final bucket = series.length / _maxPoints;
    return [
      for (var i = 0; i < _maxPoints; i++)
        () {
          final from = (i * bucket).floor();
          final to = min(series.length, ((i + 1) * bucket).ceil());
          final slice = series.sublist(from, max(to, from + 1));
          return slice.map((point) => point.value).reduce((a, b) => a + b) / slice.length;
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // One reading is not a trend. The card no longer reserves space for a plot
    // it cannot draw — see [_HealthCard] — so there is nothing to fill here and
    // nothing to apologise for.
    if (series.length < 2) return const SizedBox.shrink();

    final values = _plotted;
    final lo = values.reduce(min);
    final hi = values.reduce(max);
    // A flat series would otherwise be drawn along the floor of the box, which
    // reads as missing data rather than as a steady number.
    final padding = switch (hi - lo) {
      0 => 1.0,
      final span => span * .15,
    };

    return LineChart(
      LineChartData(
        minY: lo - padding,
        maxY: hi + padding,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, value) in values.indexed) FlSpot(index.toDouble(), value),
            ],
            isCurved: true,
            curveSmoothness: .2,
            barWidth: 2,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: .topCenter,
                end: .bottomCenter,
                colors: [color.withValues(alpha: .25), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
