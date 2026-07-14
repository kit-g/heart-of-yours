import 'package:flutter/material.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:intl/intl.dart';

class ExerciseChart extends StatelessWidget {
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

  const ExerciseChart({
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
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return FutureBuilder<List<(num, DateTime)>?>(
      future: callback(),
      builder: (_, future) {
        final AsyncSnapshot(connectionState: state, :error, :data) = future;
        return switch ((state, error, data)) {
          (ConnectionState.waiting, _, _) => loadingState ?? const Center(child: CircularProgressIndicator()),
          (_, Object _, _) => errorState,
          (ConnectionState.done, null, List<(num, DateTime)> records) => Builder(
            builder: (_) {
              if (records.isEmpty) {
                return emptyState;
              }

              final reversed = records.reversed.toList();
              // aim for ~6 date labels regardless of how many points there are,
              // so a long history doesn't crowd the axis
              final labelEvery = (reversed.length / 6).ceil().clamp(1, reversed.length);

              return SizedBox(
                height: 300,
                child: HistoryChart(
                  yStepCandidates: yStepCandidates,
                  color: color,
                  indicatorStrokeColor: colorScheme.surface,
                  bottomAxisLabelStyle: textTheme.bodySmall,
                  series: reversed.indexed.map(
                    (record) {
                      final (index, (metric, _)) = record;
                      return Dot(
                        index.toDouble(),
                        converter(metric),
                      );
                    },
                  ),
                  getBottomLabel: (x) {
                    return switch (x % labelEvery == 0) {
                      true => DateFormat('d/M').format(reversed[x].$2),
                      false => '',
                    };
                  },
                  getLeftLabel: getLeftLabel,
                  topLabel: switch ((label, customLabel)) {
                    (_, Widget l) => l,
                    // fl_chart centers the axis name over the whole chart width,
                    // but the plot sits to the right of the y-axis labels — pad
                    // by that reserved width so the title centers over the plot
                    (String l, _) => Padding(
                      padding: const .only(left: historyChartLeftAxisSize),
                      child: Text(l, style: textTheme.titleMedium),
                    ),
                    _ => null,
                  },
                  getTooltip: (_, y) => getTooltip?.call(y) ?? _double(y),
                ),
              );
            },
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

String _double(double value) {
  final rounded = double.parse(value.toStringAsFixed(2));
  return rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(1);
}
