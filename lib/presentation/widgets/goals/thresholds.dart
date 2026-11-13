part of 'goals.dart';

/// The goals whose rungs belong on a chart of [metric] for the exercise with
/// [exerciseId] — the same server id both charts and goals address exercises
/// by since schema v11.
///
/// A recurring goal belongs when its period folds sessions into one session's
/// kind of number: "a 100 kg top set this week" is the week's best session,
/// on the very scale the chart plots, and so is a period average. One that
/// sums ("2000 kg of volume a week") is left out — its target is a total no
/// single session's point is measured against. Leaving every recurring goal
/// out hid the weekly top-set and e1RM goals the app suggests from every chart
/// but the goal's own sheet (#627).
Iterable<Goal> goalsOnChart(
  Iterable<Goal> goals, {
  required String exerciseId,
  required ChartPreferenceType metric,
}) {
  return goals.where(
    (goal) {
      if (goal.metric.chart != metric || goal.exerciseId != exerciseId) return false;
      return switch ((goal.cadence, metric.periodAggregate)) {
        (null, _) => true,
        (_, .best || .mean) => true,
        (_, .sum) => false,
      };
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
/// [unit] and [category] must match whatever the chart's own converter was
/// given — the exercise's unit override, and the category that puts a carry in
/// metres — or the lines land in different units from the series they are
/// measuring.
List<ChartThreshold> goalThresholds(
  BuildContext context,
  Goal goal, {
  required ChartPreferenceType metric,
  required Preferences settings,
  MeasurementUnit? unit,
  Category? category,
  bool nextOnly = false,
}) {
  if (!settings.isInitialized) return const [];

  final convert = metric.converter(settings, unit: unit, category: category);
  final label = metric.unitLabel(context, settings, unit: unit, category: category);

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
