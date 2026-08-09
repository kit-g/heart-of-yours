part of 'goals.dart';

/// The goals whose rungs belong on a chart of [metric] for the exercise named
/// [exerciseName].
///
/// A dashboard chart addresses its exercise by *name* — that is what the
/// metrics queries are keyed by — while a goal addresses its own by *id*, so
/// the catalog is what joins the two.
///
/// Recurring goals are left out. Their target is per-period while the chart
/// plots one point per session, so a line drawn at it would sit on a scale the
/// series is not on — the same reason [Goals.observeProgress] skips them.
Iterable<Goal> goalsOnChart(
  Iterable<Goal> goals, {
  required String exerciseName,
  required ChartPreferenceType metric,
  required Exercises exercises,
}) {
  return goals.where(
    (goal) {
      if (goal.cadence != null || goal.metric.chart != metric) return false;
      return goalExercise(goal, exercises)?.name == exerciseName;
    },
  );
}

/// A goal's rungs as lines to draw across a chart of [metric], in display units
/// — the series is handed converted numbers, so these have to arrive converted
/// too.
///
/// [nextOnly] keeps just the rung being worked toward. A dashboard card is a
/// glance surface at a fraction of the detail sheet's height, where a five-rung
/// ladder is five dashed lines and five labels over a plot with no room for
/// them; the whole ladder still draws where there is space for it.
///
/// Empty until [Preferences] has loaded: its unit fields are `late`, and this
/// reads them eagerly to label the lines.
///
/// [unit] must match whatever the chart's own converter was given — the
/// per-exercise chart page overrides it per exercise — or the lines land in
/// different units from the series they are measuring.
List<ChartThreshold> goalThresholds(
  BuildContext context,
  Goal goal, {
  required ChartPreferenceType metric,
  required Preferences settings,
  MeasurementUnit? unit,
  bool nextOnly = false,
}) {
  if (!settings.isInitialized) return const [];

  final convert = metric.converter(settings, unit: unit);
  final label = metric.unitLabel(context, settings, unit: unit);

  final stages = switch (nextOnly) {
    // null once the ladder is finished, which is the point: a goal with nothing
    // left to reach has nothing left to draw
    true => <GoalStage>[?goal.currentStage],
    false => goal.stages,
  };

  return [
    for (final stage in stages)
      if (convert(stage.target) case final double target)
        ChartThreshold(
          value: target,
          label: switch (label) {
            final String unit => '${target.trimmed()} $unit',
            null => target.trimmed(),
          },
          reached: stage.isAchieved,
        ),
  ];
}
