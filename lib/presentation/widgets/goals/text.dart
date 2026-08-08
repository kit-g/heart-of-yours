part of 'goals.dart';

/// "Workouts", or "Bench Press (Barbell) — Estimated 1RM".
String goalTitle(BuildContext context, Goal goal, Exercise? exercise) {
  final l = L.of(context);
  if (goal.metric.isWholeWorkout) return l.workouts;

  final metric = goal.metric.chart?.label(context);
  return switch ((exercise?.name, metric)) {
    (final String name, final String metric) => '$name — $metric',
    (final String name, _) => name,
    _ => metric ?? '',
  };
}

/// The line under the title: where the user is, and the deadline if there is
/// one. A cadence goal says "1 / 4 · per week"; a ladder says what is next.
String goalStatus(
  BuildContext context,
  Goal goal, {
  required Preferences settings,
  required num? current,
}) {
  final l = L.of(context);
  final stage = goal.currentStage;
  if (stage == null) return l.goalComplete;

  final unit = goal.metric.chart?.unitLabel(context, settings) ?? '';
  final suffix = unit.isEmpty ? '' : ' $unit';

  // num, not double: a workout count arrives as an int and would otherwise
  // fall through to the empty branch, quietly dropping the progress
  final progress = switch (current) {
    final num value => '${value.trimmed()} / ',
    _ => '',
  };

  final cadence = switch (goal.cadence) {
    .week => ' · ${l.goalPerWeek}',
    .month => ' · ${l.goalPerMonth}',
    null => switch (stage.dueOn) {
      final DateTime due => ' · ${l.goalDue(DateFormat.yMMMd().format(due))}',
      _ => '',
    },
  };

  return '$progress${goal.convert(settings, stage.target).trimmed()}$suffix$cadence';
}

extension GoalUnits on Goal {
  /// A stored value in the units the user reads. Weights and distances depend
  /// on their settings; counts and durations are the same either way.
  double convert(Preferences settings, num value) {
    return metric.chart?.converter(settings)(value) ?? value.toDouble();
  }
}
