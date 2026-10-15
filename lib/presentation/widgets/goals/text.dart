part of 'goals.dart';

/// "Workouts", "Bench Press (Barbell) — Estimated 1RM", or "Horizontal
/// press — Sets".
String goalTitle(BuildContext context, Goal goal, Exercise? exercise) {
  final l = L.of(context);
  if (goal.metric.isWholeWorkout) return l.workouts;
  if (goal.metric.countsSubject) {
    final counted = switch (goal.metric) {
      .sessions => l.sessions,
      _ => l.sets,
    };
    return '${subjectLabel(l, goal.subject, exercise)} — $counted';
  }

  final metric = goal.metric.chart?.label(context);
  return switch ((exercise?.name, metric)) {
    (final String name, final String metric) => '$name — $metric',
    (final String name, _) => name,
    _ => metric ?? '',
  };
}

/// What a sets or sessions goal is about, as copy: its exercise's name, a
/// pattern's label, a muscle group's. A muscle key that is no atlas group (a
/// newer client's) and a missing exercise read as their identifiers rather
/// than as nothing.
String subjectLabel(L l, GoalSubject? subject, Exercise? exercise) {
  return switch (subject) {
    ExerciseSubject(:final id) => exercise?.name ?? id,
    PatternSubject(:final key) => patternLabel(key, l),
    MuscleSubject(:final key) => MuscleGroup.tryFromString(key)?.label(l) ?? key,
    null => '',
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
///
/// [scale] is the goal's exercise's (see [goalScale]), read by the caller where
/// it already holds [Exercises].
String goalStatus(
  BuildContext context,
  Goal goal, {
  required Preferences settings,
  required ChartScale scale,
  required num? current,
}) {
  final l = L.of(context);
  final stage = goal.currentStage;
  if (stage == null) return l.goalComplete;

  // num, not double: a workout count arrives as an int and would otherwise
  // fall through to the empty branch, quietly dropping the progress
  final progress = switch (current) {
    final num value => '${goal.convert(settings, scale, value).trimmed()} / ',
    _ => '',
  };

  final cadence = switch (goal.cadence) {
    .week => ' · ${l.goalPerWeek}',
    .month => ' · ${l.goalPerMonth}',
    null => switch (stage.dueOn) {
      final DateTime due => ' · ${l.goalDue(DateFormat.yMMMd(l.localeName).format(due))}',
      _ => '',
    },
  };

  return '$progress${goalTargetLabel(context, goal, stage.target, settings: settings, scale: scale)}$cadence';
}

/// A target as the user reads it: converted to their units, trimmed of a
/// trailing `.0`, with the unit appended where the dimension has one.
///
/// The target half of [goalStatus], on its own — the workout summary states a
/// rung it just earned and wants exactly this without the progress or the
/// cadence wrapped around it.
String goalTargetLabel(
  BuildContext context,
  Goal goal,
  num target, {
  required Preferences settings,
  required ChartScale scale,
}) {
  final unit = goal.unitLabel(context, settings, scale) ?? '';
  final suffix = unit.isEmpty ? '' : ' $unit';
  return '${goal.convert(settings, scale, target).trimmed()}$suffix';
}

extension GoalUnits on Goal {
  /// A stored value in the units the user reads. Weights and distances depend
  /// on their settings and on [scale], the goal's exercise's (see
  /// [goalScale]); counts and durations are the same either way.
  ///
  /// A muscle's sets are counted in fractions and read whole (the pattern
  /// lens's rule 8) through [wholeSets], as the weekly card reads them.
  double convert(Preferences settings, ChartScale scale, num value) {
    if (metric == .sets) return wholeSets(value).toDouble();
    final (:unit, :category) = scale;
    return metric.chart?.converter(settings, unit: unit, category: category)(value) ?? value.toDouble();
  }

  /// The unit [convert] reads in, where the dimension has one.
  String? unitLabel(BuildContext context, Preferences settings, ChartScale scale) {
    final (:unit, :category) = scale;
    return metric.chart?.unitLabel(context, settings, unit: unit, category: category);
  }
}
