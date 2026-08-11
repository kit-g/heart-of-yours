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
/// [current] is in the units the app *stores*, exactly as [currentGoalValue]
/// answers — this converts it, the same way it converts the target.
///
/// Taking it pre-converted was the ambiguity that broke it: the target was
/// converted in here while `current` was printed as handed over, so whichever
/// call site guessed differently was wrong. The row converted first, the detail
/// sheet did not, and an imperial user read "100 / 225 lbs" with 100 still in
/// kilograms. One function owns the units now.
String goalStatus(
  BuildContext context,
  Goal goal, {
  required Preferences settings,
  required num? current,
}) {
  final l = L.of(context);
  final stage = goal.currentStage;
  if (stage == null) return l.goalComplete;

  // num, not double: a workout count arrives as an int and would otherwise
  // fall through to the empty branch, quietly dropping the progress
  final progress = switch (current) {
    final num value => '${goal.convert(settings, value).trimmed()} / ',
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

  return '$progress${goalTargetLabel(context, goal, stage.target, settings: settings)}$cadence';
}

/// A target as the user reads it: converted to their units, trimmed of a
/// trailing `.0`, with the unit appended where the dimension has one.
///
/// The target half of [goalStatus], on its own — the workout summary states a
/// rung it just earned and wants exactly this without the progress or the
/// cadence wrapped around it.
String goalTargetLabel(BuildContext context, Goal goal, num target, {required Preferences settings}) {
  final unit = goal.metric.chart?.unitLabel(context, settings) ?? '';
  final suffix = unit.isEmpty ? '' : ' $unit';
  return '${goal.convert(settings, target).trimmed()}$suffix';
}

extension GoalUnits on Goal {
  /// A stored value in the units the user reads. Weights and distances depend
  /// on their settings; counts and durations are the same either way.
  double convert(Preferences settings, num value) {
    return metric.chart?.converter(settings)(value) ?? value.toDouble();
  }
}
