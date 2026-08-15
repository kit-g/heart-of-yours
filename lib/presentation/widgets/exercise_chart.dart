import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_language/heart_language.dart';

class ExerciseChart extends StatefulWidget {
  final Future<List<(num, DateTime)>?> Function() callback;
  final Widget emptyState;
  final String? label;
  final Widget? customLabel;
  final double Function(num) converter;
  final Widget Function(double y)? getLeftLabel;
  final String Function(double y)? getTooltip;
  final Widget errorState;
  final Widget? loadingState;
  final List<double>? yStepCandidates;
  final Color? color;

  /// Values to mark across the plot. Already in display units — the chart is
  /// given converted numbers, so these have to arrive converted too.
  final List<ChartThreshold> thresholds;

  /// Identity of the data this chart shows. The [callback] is invoked once and
  /// the result is kept across rebuilds, so purely cosmetic rebuilds (theme,
  /// units, a sibling loading) don't flash the loading state. Change this when
  /// the underlying data changes — e.g. a different exercise/metric — to force a
  /// re-fetch.
  final Object? refreshKey;

  const new({
    super.key,
    required this.emptyState,
    required this.callback,
    this.label,
    this.customLabel,
    required this.converter,
    this.getLeftLabel,
    this.getTooltip,
    required this.errorState,
    this.loadingState,
    this.yStepCandidates,
    this.color,
    this.thresholds = const [],
    this.refreshKey,
  });

  @override
  State<ExerciseChart> createState() => _ExerciseChartState();
}

class _ExerciseChartState extends State<ExerciseChart> {
  late Future<List<(num, DateTime)>?> _future = widget.callback();

  @override
  void didUpdateWidget(ExerciseChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // re-fetch only when the caller signals the data changed, never on a plain
    // rebuild — otherwise the FutureBuilder flickers back through its loader
    if (widget.refreshKey != oldWidget.refreshKey) {
      _future = widget.callback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return FutureBuilder<List<(num, DateTime)>?>(
      future: _future,
      builder: (_, snapshot) {
        final AsyncSnapshot(connectionState: state, :error, :data) = snapshot;
        final (phase, content) = switch ((state, error, data)) {
          (.waiting, _, _) => ('loading', widget.loadingState ?? const SizedBox(height: 300)),
          (_, Object _, _) => ('error', widget.errorState),
          (.done, null, List<(num, DateTime)> records) when records.isEmpty => ('empty', widget.emptyState),
          (.done, null, List<(num, DateTime)> records) => ('data', _dataChart(records, textTheme, colorScheme)),
          _ => ('none', const SizedBox.shrink()),
        };
        // fade between phases so the chart eases in once its data lands, rather
        // than popping in from the blank loader (default transition is a fade)
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          child: KeyedSubtree(key: ValueKey(phase), child: content),
        );
      },
    );
  }

  Widget _dataChart(List<(num, DateTime)> records, TextTheme textTheme, ColorScheme colorScheme) {
    final reversed = records.reversed.toList();
    // aim for ~6 date labels regardless of how many points there are, so a long
    // history doesn't crowd the axis
    // One label per *day*, not per Nth point. Points are sessions, so training
    // twice in a day used to print the same date twice — "8/9, 8/9, 8/9, 8/11"
    // reads as a broken axis rather than a busy week. The first session of each
    // day carries the label, and those are then thinned to roughly six.
    final firstOfDay = <int>[];
    String? previous;
    for (final (index, (_, at)) in reversed.indexed) {
      final day = L.of(context).dayAndMonth(at);
      if (day == previous) continue;
      previous = day;
      firstOfDay.add(index);
    }
    final labelEvery = (firstOfDay.length / 6).ceil().clamp(1, max(firstOfDay.length, 1));
    final labelled = {
      for (final (nth, index) in firstOfDay.indexed)
        if (nth % labelEvery == 0) index,
    };

    return SizedBox(
      height: 300,
      child: HistoryChart(
        thresholds: widget.thresholds,
        yStepCandidates: widget.yStepCandidates,
        color: widget.color,
        indicatorStrokeColor: colorScheme.surface,
        bottomAxisLabelStyle: textTheme.bodySmall,
        series: reversed.indexed.map(
          (record) {
            final (index, (metric, _)) = record;
            return Dot(
              index.toDouble(),
              widget.converter(metric),
            );
          },
        ),
        getBottomLabel: (x) {
          return switch (labelled.contains(x)) {
            true => L.of(context).dayAndMonth(reversed[x].$2),
            false => '',
          };
        },
        getLeftLabel: widget.getLeftLabel,
        topLabel: switch ((widget.label, widget.customLabel)) {
          (_, Widget l) => l,
          // fl_chart centers the axis name over the whole chart width, but the
          // plot sits to the right of the y-axis labels — pad by that reserved
          // width so the title centers over the plot
          (String l, _) => Padding(
            padding: const .only(left: historyChartLeftAxisSize),
            child: Text(l, style: textTheme.titleMedium),
          ),
          _ => null,
        },
        getTooltip: (_, y) => widget.getTooltip?.call(y) ?? _double(y),
      ),
    );
  }
}

String _double(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
}
