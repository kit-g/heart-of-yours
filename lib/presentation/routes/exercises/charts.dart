part of 'exercises.dart';

class _Charts extends StatelessWidget {
  final Exercise exercise;

  const new({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final prefs = Preferences.watch(context);
    final exercises = Exercises.of(context);
    final unit = Exercises.watch(context).unitFor(exercise.name);
    // watched: reaching a rung redraws the line on the chart that measures it
    final goals = Goals.watch(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final style = textTheme.bodySmall;

    // Every metric relevant to this exercise's category — the same set the
    // dashboard offers when adding a chart, now surfaced per exercise.
    final types = ChartPreferenceType.chartsByExerciseCategory(exercise.category);

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: types.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final type = types[index];
        final title = type.title(context, prefs, unit: unit);
        return ExerciseChart(
          // the rung being worked toward, for every goal on this exercise and
          // metric. Converted with this exercise's own unit, the one the series
          // beside it is plotted in — the user default would land elsewhere.
          thresholds: [
            for (final goal in goalsOnChart(goals, exerciseName: exercise.name, metric: type, exercises: exercises))
              ...goalThresholds(context, goal, metric: type, settings: prefs, unit: unit, nextOnly: true),
          ],
          // only the first chart carries the full "no data yet" hint; the rest
          // stay quiet so an empty exercise doesn't repeat it N times
          emptyState: index == 0 ? const _EmptyState() : const SizedBox.shrink(),
          callback: () => exercises.getChartExerciseMetics(type, exercise.name, limit: _exerciseHistoryLimit),
          timeline: true,
          refreshKey: (type, exercise.name),
          // the string still travels as [label] — it feeds the chart's
          // spoken summary — while the row adds the dashboard toggle
          label: title,
          customLabel: Row(
            children: [
              Expanded(
                child: Text(title, style: textTheme.titleMedium, maxLines: 1, overflow: .ellipsis),
              ),
              _DashboardToggle(exercise: exercise, type: type),
            ],
          ),
          converter: type.converter(prefs, unit: unit),
          getLeftLabel: type.leftLabel(style),
          getTooltip: type.tooltip,
          yStepCandidates: type.yStepCandidates,
          color: type.color(context),
          errorState: const _ErrorState(),
        );
      },
    );
  }
}

/// Puts this exercise+metric chart on the profile dashboard, or takes it back
/// off — the same [ChartPreference] the profile's "New chart" dialog builds,
/// minus the two-step picker, offered right where the metric is on screen.
class _DashboardToggle extends StatelessWidget {
  final Exercise exercise;
  final ChartPreferenceType type;

  const new({required this.exercise, required this.type});

  @override
  Widget build(BuildContext context) {
    // watched: adding or removing the card flips this button in place
    final charts = Charts.watch(context);
    final L(:addChartToProfile, :removeChartFromProfile, :chartAddedToProfile) = L.of(context);

    // the dashboard card this chart would duplicate, if it is already there
    final existing = charts.where((each) => each.exerciseName == exercise.name && each.type == type).firstOrNull;

    return switch (existing) {
      null => FeedbackButton.circular(
        tooltip: addChartToProfile,
        onPressed: () {
          charts.addPreference(.exercise(exercise.name, type));
          // the result lives on another tab, so confirm it landed
          snack(context, chartAddedToProfile);
        },
        child: const Padding(
          padding: .all(2.0),
          child: Icon(Icons.addchart_rounded, size: 20),
        ),
      ),
      final preference => FeedbackButton.circular(
        tooltip: removeChartFromProfile,
        onPressed: () => charts.removePreference(preference),
        child: Padding(
          padding: const .all(2.0),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    };
  }
}

/// Sessions fetched for a per-exercise chart.
///
/// Was 30 — a few weeks for anyone training seriously, which made the chart a
/// snapshot rather than a history. The chart travels through time now, so the
/// cap only has to stay ahead of what anyone can plausibly have logged: five
/// sessions a week for a decade is 2600.
const _exerciseHistoryLimit = 5000;
