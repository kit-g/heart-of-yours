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
    final ThemeData(:textTheme) = Theme.of(context);

    Widget durationLabel(double y) {
      return switch (_beautify(y)) {
        String v => Text(
            v,
            style: textTheme.bodySmall,
          ),
        null => const SizedBox.shrink(),
      };
    }

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
              emptyState: const _EmptyState(),
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
              getLeftLabel: durationLabel,
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
              emptyState: const _EmptyState(),
              callback: () => durationHistoryLookup!(exercise),
              label: l.duration,
              converter: (v) => v.toDouble(),
              getLeftLabel: durationLabel,
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
  final Widget Function(double y)? getLeftLabel;
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

String? _beautify(double y) {
  int seconds = y.round();

  final roundTo = switch (y.round()) {
    < 60 => 10, // to nearest 10s
    < 600 => 30, // to nearest 30s
    < 3600 => 300, // to nearest 5min
    _ => 900, // to nearest 5min
  };

  // apply rounding
  int rounded = (seconds / roundTo).round() * roundTo;

  // filter out "ugly" labels
  if (rounded % 60 != 0 && rounded >= 600) {
    return null; // drop values that aren’t full minutes after 10 min
  }
  return Duration(seconds: rounded).formatted();
}
