import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/setting_picker.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_language/heart_language.dart';
import 'package:intl/intl.dart';

/// One reading at a point in time. Oldest first.
typedef TimelinePoint = ({DateTime at, double value});

/// How much time one plotted point covers.
///
/// Not a user setting — it is derived from how much history is on screen, so
/// the number of points stays readable whether the window is a fortnight or a
/// decade. See [TimelineChart.grainFor].
enum TimelineGrain { day, week, month, year }

/// A named window a chip can jump to. `all` means the whole series, however
/// long that turns out to be.
enum TimelineRange {
  month(31),
  quarter(92),
  year(366),
  all(null);

  new(this.days);

  final int? days;
}

/// A [HistoryChart] you can travel through.
///
/// Two controls over the same value — how many days are on screen. Chips jump
/// to a named window; dragging left widens it and dragging right narrows it,
/// continuously. Granularity is never chosen, only derived: as the window grows
/// the points coarsen from days to weeks to months to years, so the plot holds
/// roughly the same number of points at every scale.
///
/// That derivation is the whole idea. A year of daily readings drawn faithfully
/// is 365 points across a couple of hundred logical pixels — two thirds of a
/// point each, at which a line stops being a line and becomes a filled block.
/// More data, less information. Coarsening as you zoom out keeps the shape
/// legible, and the caption says which scale you are looking at so a smoothed
/// point is never mistaken for a reading.
class TimelineChart extends StatefulWidget {
  /// Oldest first. Points may be irregularly spaced — workout sessions are —
  /// and gaps are left as gaps rather than interpolated.
  final List<TimelinePoint> series;
  final double height;
  final Color? color;
  final double leftAxisSize;
  final List<double>? yStepCandidates;
  final Widget Function(double y)? getLeftLabel;
  final String Function(double y)? getTooltip;

  /// Where the window starts. Null lets [openingRange] pick one that actually
  /// holds readings, which is what a caller almost always wants.
  final TimelineRange? initialRange;

  /// Values to mark across the plot — a goal's rungs, say. Passed through to
  /// [HistoryChart], which widens the axis to keep them in view.
  final List<ChartThreshold> thresholds;

  /// Drawn above the plot, inset by [leftAxisSize] so it centres over the plot
  /// rather than over the chart's whole width.
  final Widget? topLabel;

  /// What the plot measures, for the accessibility summary — a screen reader
  /// cannot perceive a painted line, so it is given the same thing as a
  /// sentence. Falls back to a generic word when the caller has no name for it.
  final String? semanticName;

  const new({
    super.key,
    required this.series,
    this.height = 280,
    this.color,
    this.leftAxisSize = historyChartLeftAxisSize,
    this.yStepCandidates,
    this.getLeftLabel,
    this.getTooltip,
    this.initialRange,
    this.thresholds = const [],
    this.topLabel,
    this.semanticName,
  });

  /// Fewest points worth calling a line. Below this a window is a dot or two
  /// with a lot of empty chart around them.
  static const _readable = 5;

  /// The window a chart should open on for [series].
  ///
  /// [TimelineRange.quarter] whenever it holds enough readings, widening only
  /// when it does not. A fixed window suits a metric recorded daily and strands
  /// one recorded every few weeks: three months of body mass can be a single
  /// weigh-in, and one point is not a line on any surface.
  ///
  /// Public because the thumbnail beside a chart has to open on the same window
  /// the chart does, and computing it twice is how they drift apart.
  static TimelineRange openingRange(List<TimelinePoint> series, {int atLeast = _readable}) {
    if (series.isEmpty) return .all;

    for (final range in const [TimelineRange.quarter, TimelineRange.year]) {
      final from = series.last.at.subtract(Duration(days: range.days!));
      final held = series.where((point) => !point.at.isBefore(from)).length;
      if (held >= atLeast) return range;
    }

    return .all;
  }

  /// The scale that keeps a window of [days] to a readable number of points.
  ///
  /// The thresholds are chosen so every rung lands between roughly 25 and 65
  /// points — enough to show a shape, few enough to tell apart.
  static TimelineGrain grainFor(double days) {
    return switch (days) {
      <= 100 => .day,
      <= 400 => .week,
      <= 1600 => .month,
      _ => .year,
    };
  }

  @override
  State<TimelineChart> createState() => _TimelineChartState();
}

class _TimelineChartState extends State<TimelineChart> {
  /// Days of history on screen. The single piece of state here: chips set it,
  /// drags scale it, and everything else — window, grain, labels — is derived.
  late final ValueNotifier<double> _days = ValueNotifier(_initial);

  /// Never fewer than a fortnight. Below that the chart is two points and a
  /// gesture that feels broken because there is nothing left to zoom into.
  static const _minDays = 14.0;

  /// Logical pixels of drag per e-fold of the window. Tuned so a full-width
  /// swipe on a phone is roughly a factor of five, which lands a year-long
  /// window in about two swipes from a month.
  static const _dragScale = 170.0;

  double get _span {
    if (widget.series.length < 2) return _minDays;
    return widget.series.last.at.difference(widget.series.first.at).inDays.toDouble() + 1;
  }

  double get _initial {
    final range = widget.initialRange ?? TimelineChart.openingRange(widget.series);
    return switch (range.days) {
      int days => min(days.toDouble(), _span),
      null => _span,
    }.clamp(_minDays, max(_minDays, _span));
  }

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  void _zoom(double dx) {
    // Left is back: dragging the plot leftwards pulls more history into view.
    final scaled = _days.value * exp(-dx / _dragScale);
    _days.value = scaled.clamp(_minDays, max(_minDays, _span));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);

    if (widget.series.length < 2) return SizedBox(height: widget.height);

    return ValueListenableBuilder<double>(
      valueListenable: _days,
      builder: (context, days, _) {
        final grain = TimelineChart.grainFor(days);
        final points = _bucketed(_window(days), grain);
        final labelled = _labelled(points.length, grain);
        // "Aug — Feb — Aug — Feb — Aug" is three different Augusts wearing the
        // same label. Once the window covers more than one calendar year the
        // month has to carry it.
        final years = points.isEmpty || points.first.at.year != points.last.at.year;

        return Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            _ranges(l, days),
            const SizedBox(height: 8),
            // Summary-level, not per-point: what it measures, over what span,
            // where it ended up and which way it went. `docs/a11y.md`.
            Semantics(
              label: _summary(points, l),
              child: SizedBox(
                height: widget.height,
                // Room for the rotated date at each end. `fitInside` nudges a
                // label back towards the plot but cannot invent space, so the
                // last one hangs over whatever the chart is sitting in — which in
                // a dialog means over the edge of the card.
                child: Padding(
                  padding: const .symmetric(horizontal: 14),
                  child: GestureDetector(
                    // Horizontal only, so the chart keeps its own tap-to-pin and a
                    // vertical scroll still belongs to whatever is scrolling.
                    onHorizontalDragUpdate: (details) => _zoom(details.delta.dx),
                    child: HistoryChart(
                      color: widget.color ?? colorScheme.primary,
                      indicatorStrokeColor: colorScheme.surface,
                      bottomAxisLabelStyle: textTheme.bodySmall,
                      yStepCandidates: widget.yStepCandidates,
                      leftAxisSize: widget.leftAxisSize,
                      thresholds: widget.thresholds,
                      topLabel: switch (widget.topLabel) {
                        Widget label => Padding(
                          padding: .only(left: widget.leftAxisSize),
                          child: label,
                        ),
                        null => null,
                      },
                      showDots: points.length <= 45,
                      barWidth: points.length <= 45 ? 4 : 2,
                      series: [
                        for (final (index, point) in points.indexed) Dot(index.toDouble(), point.value),
                      ],
                      getBottomLabel: (x) {
                        return switch (labelled.contains(x)) {
                          true => _axisLabel(points[x].at, grain, l, years: years),
                          false => '',
                        };
                      },
                      getLeftLabel: widget.getLeftLabel,
                      getTooltip: switch (widget.getTooltip) {
                        String Function(double) tooltip => (_, y) => tooltip(y),
                        null => null,
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Said, not assumed. A chart quietly plotting monthly means where
            // the caller shows a day's reading lies by omission.
            //
            // The line is always here, empty at the day grain rather than
            // absent. Letting it come and go changes the column's height, which
            // inside a dialog resizes the dialog under the finger that just
            // tapped a chip — one text line of jump, and the most distracting
            // thing about switching ranges.
            Padding(
              padding: const .only(top: 4),
              child: Text(
                _caption(grain, l) ?? '',
                textAlign: .center,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Only the windows this series can actually fill. Offering a year to someone
  /// with three weeks of history is a control that does nothing.
  Widget _ranges(L l, double days) {
    final offered = [
      for (final range in TimelineRange.values)
        if (range.days == null || range.days! < _span) range,
    ];
    if (offered.length < 2) return const SizedBox.shrink();

    return Align(
      alignment: .center,
      child: SettingSwitcher<TimelineRange>(
        value: _nearest(offered, days),
        onValueChanged: (range) {
          if (range == null) return;
          _days.value = switch (range.days) {
            int chosen => min(chosen.toDouble(), _span),
            null => _span,
          };
        },
        children: {
          for (final range in offered) range: Text(_rangeLabel(range, l), style: Theme.of(context).textTheme.bodySmall),
        },
      ),
    );
  }

  /// The chip that best describes the current window. A drag lands between
  /// chips constantly, and leaving all of them unlit reads as a broken control
  /// — so the closest one stays lit and tapping it snaps the window to it.
  TimelineRange _nearest(List<TimelineRange> offered, double days) {
    return offered.reduce((a, b) {
      final da = ((a.days ?? _span) - days).abs();
      final db = ((b.days ?? _span) - days).abs();
      return da <= db ? a : b;
    });
  }

  /// The tail of the series covering the last [days] days.
  List<TimelinePoint> _window(double days) {
    final from = widget.series.last.at.subtract(Duration(days: days.round()));
    final start = widget.series.indexWhere((point) => !point.at.isBefore(from));
    return switch (start) {
      // Everything is inside the window, or nothing is — either way the whole
      // series is the honest answer.
      <= 0 => widget.series,
      _ => widget.series.sublist(start),
    };
  }

  /// [window] collapsed to one point per [grain], each the mean of its bucket
  /// and dated by the last reading in it.
  List<TimelinePoint> _bucketed(List<TimelinePoint> window, TimelineGrain grain) {
    if (grain == .day || window.isEmpty) return window;

    final buckets = <DateTime, List<double>>{};
    final dates = <DateTime, DateTime>{};
    for (final point in window) {
      final key = _key(point.at, grain);
      (buckets[key] ??= []).add(point.value);
      dates[key] = point.at;
    }

    return [
      for (final key in buckets.keys)
        (at: dates[key]!, value: buckets[key]!.reduce((a, b) => a + b) / buckets[key]!.length),
    ];
  }

  /// Calendar buckets, not rolling ones: a month is a month, so the axis reads
  /// "Mar" rather than a date 30 days after some arbitrary start.
  DateTime _key(DateTime at, TimelineGrain grain) {
    return switch (grain) {
      .day => DateTime(at.year, at.month, at.day),
      .week => DateTime(at.year, at.month, at.day).subtract(Duration(days: at.weekday - 1)),
      .month => DateTime(at.year, at.month),
      .year => DateTime(at.year),
    };
  }

  /// A handful of dates across the axis, always including the most recent —
  /// that is the one a reader looks for first. Fewer of them at the coarse
  /// grains, where every label carries a year and is half as wide again.
  Set<int> _labelled(int length, TimelineGrain grain) {
    final wanted = switch (grain) {
      .day || .week => 5,
      .month || .year => 4,
    };
    final every = (length / wanted).ceil().clamp(1, max(length, 1)).toInt();
    return {
      for (var index = length - 1; index >= 0; index -= every) index,
    };
  }

  String _axisLabel(DateTime at, TimelineGrain grain, L l, {required bool years}) {
    return switch (grain) {
      .day || .week => l.dayAndMonth(at),
      // "Aug 2026" is half the width of the gap between labels, and four of
      // them rotated at 45 degrees run off the end of the plot. An axis is the
      // one place a two-digit year earns its ambiguity — nobody reads "Aug '26"
      // as anything but a month in a year.
      .month => switch (years) {
        true => "${DateFormat.MMM().format(at)} '${DateFormat('yy').format(at)}",
        false => DateFormat.MMM().format(at),
      },
      .year => DateFormat.y().format(at),
    };
  }

  /// The plot as a sentence — what it measures, the span on screen, where it
  /// ended up and which way it went. A screen reader cannot perceive a painted
  /// line, and per-point narration would be unusable even if it could.
  String _summary(List<TimelinePoint> points, L l) {
    if (points.length < 2) return widget.semanticName ?? l.chartGenericLabel;

    final first = points.first.value;
    final last = points.last.value;
    final trend = switch (last.compareTo(first)) {
      > 0 => l.exerciseChartTrendUp,
      < 0 => l.exerciseChartTrendDown,
      _ => l.exerciseChartTrendFlat,
    };

    return l.exerciseChartSummary(
      widget.semanticName ?? l.chartGenericLabel,
      l.dayAndMonth(points.first.at),
      l.dayAndMonth(points.last.at),
      widget.getTooltip?.call(last) ?? last.toStringAsFixed(0),
      trend,
    );
  }

  String? _caption(TimelineGrain grain, L l) {
    return switch (grain) {
      // A daily point is a reading, not a summary. Nothing to disclose.
      .day => null,
      .week => l.chartWeeklyAverage,
      .month => l.chartMonthlyAverage,
      .year => l.chartYearlyAverage,
    };
  }

  String _rangeLabel(TimelineRange range, L l) {
    return switch (range) {
      .month => l.chartRangeMonth,
      .quarter => l.chartRangeQuarter,
      .year => l.chartRangeYear,
      .all => l.chartRangeAll,
    };
  }
}
