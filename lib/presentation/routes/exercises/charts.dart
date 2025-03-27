part of 'exercises.dart';

class _Charts extends StatelessWidget {
  final Exercise exercise;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? weightHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? repsHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? distanceHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? durationHistoryLookup;

  const _Charts({
    required this.exercise,
    this.weightHistoryLookup,
    this.repsHistoryLookup,
    this.distanceHistoryLookup,
    this.durationHistoryLookup,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);

    const expandedEmptyState = Expanded(child: _EmptyState());

    switch (exercise.category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.barbell:
      case Category.machine:
      case Category.dumbbell:
        return ListView(
          children: [
            _Chart(
              emptyState: const _EmptyState(),
              callback: () => weightHistoryLookup!(exercise),
              label: l.weightUnit,
              converter: (v) => prefs.weightValue(v),
            ),
            const SizedBox(height: 12),
            _Chart(
              emptyState: const SizedBox(),
              callback: () => repsHistoryLookup!(exercise),
              label: l.reps,
              converter: (v) => v.toDouble(),
            ),
          ],
        );
      case Category.repsOnly:
        return Column(
          children: [
            _Chart(
              emptyState: expandedEmptyState,
              callback: () => repsHistoryLookup!(exercise),
              label: l.reps,
              converter: (v) => v.toDouble(),
            ),
          ],
        );
      case Category.cardio:
        return ListView(
          children: [
            _Chart(
              emptyState: const _EmptyState(),
              callback: () => durationHistoryLookup!(exercise),
              label: l.duration,
              converter: (v) => v.toDouble(),
              getLeftLabel: (y) {
                return Duration(seconds: y.toInt()).formatted();
              },
              getTooltip: (y) => Duration(seconds: y.toInt()).formatted(),
            ),
            const SizedBox(height: 12),
            _Chart(
              emptyState: const SizedBox(),
              callback: () => distanceHistoryLookup!(exercise),
              label: l.distanceUnit,
              converter: (v) => prefs.distanceValue(v),
            ),
          ],
        );
      case Category.duration:
        return Column(
          children: [
            _Chart(
              emptyState: expandedEmptyState,
              callback: () => durationHistoryLookup!(exercise),
              label: l.duration,
              converter: (v) => v.toDouble(),
              getLeftLabel: (y) {
                return Duration(seconds: y.toInt()).formatted();
              },
              getTooltip: (y) => Duration(seconds: y.toInt()).formatted(),
            ),
          ],
        );
    }
  }
}

class _Chart extends StatelessWidget {
  final Future<List<(num, DateTime)>?> Function() callback;
  final Widget emptyState;
  final String label;
  final double Function(num) converter;
  final String Function(double y)? getLeftLabel;
  final String Function(double y)? getTooltip;

  const _Chart({
    required this.emptyState,
    required this.callback,
    required this.label,
    required this.converter,
    this.getLeftLabel,
    this.getTooltip,
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
          (_, Object _, _) => const _ErrorState(),
          (ConnectionState.done, null, List<(num, DateTime)> records) => Builder(
              builder: (_) {
                if (records.isEmpty) {
                  return emptyState;
                }

                final reversed = records.reversed.toList();

                return SizedBox(
                  height: 300,
                  child: HistoryChart(
                    bottomAxisLabelStyle: Theme.of(context).textTheme.bodySmall,
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
                    topLabel: Text(
                      label,
                      style: textTheme.titleMedium,
                    ),
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
