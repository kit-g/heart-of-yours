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
          (ConnectionState.waiting, _, _) => const Center(
              child: CircularProgressIndicator(),
            ),
          (_, Object _, _) => const _ErrorState(),
          (ConnectionState.done, null, Map? records) => Builder(
              builder: (_) {
                final weightUnit = switch (prefs.weightUnit) {
                  MeasurementUnit.imperial => l.lbs,
                  MeasurementUnit.metric => l.kg,
                };
                final distanceUnit = switch (prefs.distanceUnit) {
                  MeasurementUnit.imperial => l.milesPlural,
                  MeasurementUnit.metric => l.km,
                };

                return switch ((exercise.category, records)) {
                  (Category.duration, {'duration': num duration}) => _Record(
                      metrics: [
                        (name: l.maxDuration, value: Duration(seconds: duration.toInt()).formatted()),
                      ],
                    ),
                  (Category.dumbbell, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble())} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (Category.barbell, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble())} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (Category.weightedBodyWeight, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxWeight, value: '${prefs.weight(weight.toDouble())} $weightUnit'),
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (Category.machine, {'reps': int reps, 'weight': num weight}) => _Record(
                      metrics: [
                        (name: l.maxDistance, value: '${prefs.weight(weight.toDouble())} $weightUnit'),
                        (name: l.maxDuration, value: '$reps'),
                      ],
                    ),
                  (Category.assistedBodyWeight, {'reps': int reps}) => _Record(
                      metrics: [
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (Category.repsOnly, {'reps': int reps}) => _Record(
                      metrics: [
                        (name: l.reps, value: '$reps'),
                      ],
                    ),
                  (Category.cardio, {'distance': double distance, 'duration': num duration}) => _Record(
                      metrics: [
                        (name: l.maxDistance, value: '${prefs.distance(distance)} $distanceUnit'),
                        (name: l.maxDuration, value: Duration(seconds: duration.toInt()).formatted()),
                      ],
                    ),
                  _ => const _EmptyState(),
                  // _ => const _EmptyState(),
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
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            L.of(context).personalRecords,
            style: textTheme.labelLarge,
          ),
        ),
        ...metrics.map(
          (metric) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        )
      ],
    );
  }
}

typedef _Metric = ({String name, String value});
