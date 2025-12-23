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
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return FutureBuilder<List<(num, DateTime)>?>(
      future: callback(),
      builder: (_, future) {
        final AsyncSnapshot(connectionState: state, :error, :data) = future;
        return switch ((state, error, data)) {
          (ConnectionState.waiting, _, _) => const Center(
            child: CircularProgressIndicator(),
          ),
          (_, Object _, _) => errorState,
          (ConnectionState.done, null, List<(num, DateTime)> records) => Builder(
            builder: (_) {
              if (records.isEmpty) {
                return emptyState;
              }

              final reversed = records.reversed.toList();

              return SizedBox(
                height: 300,
                child: HistoryChart(
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
                    return switch (x.isEven) {
                      true => DateFormat('d/M').format(reversed[x].$2),
                      false => '',
                    };
                  },
                  getLeftLabel: getLeftLabel,
                  topLabel: switch ((label, customLabel)) {
                    (_, Widget l) => l,
                    (String l, _) => Text(l, style: textTheme.titleMedium),
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
