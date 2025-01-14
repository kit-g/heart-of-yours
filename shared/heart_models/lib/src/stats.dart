abstract interface class WorkoutSummary {
  String get id;

  String get name;
}

abstract interface class WeekSummary with Iterable<WorkoutSummary> implements Comparable<WeekSummary> {
  String get weekId;

  Iterable<WorkoutSummary> get workouts;

  DateTime get startDate;
}

abstract interface class WorkoutAggregation with Iterable<WeekSummary> {
  Iterable<WeekSummary> get weeks;

  factory WorkoutAggregation.fromJson(Map json) = _WorkoutAggregation.fromJson;
}

class _WorkoutSummary implements WorkoutSummary {
  @override
  final String id;
  @override
  final String name;

  const _WorkoutSummary({
    required this.id,
    required this.name,
  });
}

class _WeekSummary with Iterable<WorkoutSummary> implements WeekSummary {
  @override
  final String weekId;
  @override
  final Iterable<WorkoutSummary> workouts;

  const _WeekSummary({
    required this.weekId,
    required this.workouts,
  });

  @override
  Iterator<WorkoutSummary> get iterator => workouts.iterator;

  @override
  DateTime get startDate => DateTime.parse(weekId.replaceAll('_', '.'));

  @override
  int compareTo(WeekSummary other) {
    return weekId.compareTo(other.weekId);
  }
}

class _WorkoutAggregation with Iterable<WeekSummary> implements WorkoutAggregation {
  @override
  final Iterable<WeekSummary> weeks;

  const _WorkoutAggregation({required this.weeks});

  @override
  Iterator<WeekSummary> get iterator => weeks.iterator;

  factory _WorkoutAggregation.fromJson(Map json) {
    return _WorkoutAggregation(
      weeks: json.entries.map(
        (entry) {
          return _WeekSummary(
            weekId: entry.key,
            workouts: (entry.value as Iterable).map(
              (each) {
                return _WorkoutSummary(
                  id: each['id'],
                  name: each['name'],
                );
              },
            ),
          );
        },
      ).toList()
        ..sort(),
    );
  }
}
