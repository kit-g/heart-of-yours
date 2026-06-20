part of 'exercises.dart';

class _Records extends StatelessWidget {
  final Exercise exercise;
  final Future<Map?> Function(Exercise exercise) recordsLookup;

  const _Records({required this.exercise, required this.recordsLookup});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    return FutureBuilder<Map?>(
      future: recordsLookup(exercise),
      builder: (_, future) {
        final AsyncSnapshot(connectionState: state, :error, :data) = future;
        return switch ((state, error, data)) {
          (.waiting, _, _) => const Center(
              child: CircularProgressIndicator(),
            ),
          (_, Object _, _) => const _ErrorState(),
          (.done, null, Map? records) => Builder(
              builder: (_) {
                final unit = Exercises.watch(context).unitFor(exercise.name);
                final weightUnit = switch (unit ?? prefs.weightUnit) {
                  .imperial => l.lbs,
                  .metric => l.kg,
                };
                final distanceUnit = switch (unit ?? prefs.distanceUnit) {
                  .imperial => l.milesPlural,
                  .metric => l.km,
                };

                return switch ((exercise.category, records)) {
                  (.duration, {'duration': num duration}) => _Record(
                      metrics: [
                        (name: l.maxDuration, value: Duration(seconds: duration.toInt()).formatted()),
                      ],
                    ),
                  (.dumbbell, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble(), unit: unit)} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.barbell, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble(), unit: unit)} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.weightedBodyWeight, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble(), unit: unit)} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.machine, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble(), unit: unit)} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.assistedBodyWeight, {'reps': int reps}) => _Record(
                      metrics: [
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.repsOnly, {'reps': int reps}) => _Record(
                      metrics: [
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (.cardio, {'distance': double distance, 'duration': num duration}) => _Record(
                      metrics: [
                        (name: l.maxDistance, value: '${prefs.distance(distance, unit: unit)} $distanceUnit'),
                        (name: l.maxDuration, value: Duration(seconds: duration.toInt()).formatted()),
                      ],
                    ),
                  _ => const Column(
                    children: [
                      _EmptyState(),
                    ],
                  ),
                };
              },
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _Record extends StatelessWidget {
  final List<_Metric> metrics;

  const _Record({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 8,
      children: [
        Padding(
          padding: const .symmetric(vertical: 4.0),
          child: Text(
            L.of(context).personalRecords,
            style: textTheme.labelLarge,
          ),
        ),
        ...metrics.map(
          (metric) {
            return Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  metric.name,
                  style: textTheme.titleMedium,
                ),
                Text(
                  metric.value,
                  style: textTheme.bodyLarge,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

typedef _Metric = ({String name, String value});
