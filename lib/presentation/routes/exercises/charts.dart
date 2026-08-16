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
    final style = Theme.of(context).textTheme.bodySmall;

    // Every metric relevant to this exercise's category — the same set the
    // dashboard offers when adding a chart, now surfaced per exercise.
    final types = ChartPreferenceType.chartsByExerciseCategory(exercise.category);

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: types.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final type = types[index];
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
          label: type.title(context, prefs, unit: unit),
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

/// Sessions fetched for a per-exercise chart.
///
/// Was 30 — a few weeks for anyone training seriously, which made the chart a
/// snapshot rather than a history. The chart travels through time now, so the
/// cap only has to stay ahead of what anyone can plausibly have logged: five
/// sessions a week for a decade is 2600.
const _exerciseHistoryLimit = 5000;
