part of 'exercises.dart';

class _Charts extends StatelessWidget {
  final Exercise exercise;

  const _Charts({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final prefs = Preferences.watch(context);
    final exercises = Exercises.of(context);
    final unit = Exercises.watch(context).unitFor(exercise.name);
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
          // only the first chart carries the full "no data yet" hint; the rest
          // stay quiet so an empty exercise doesn't repeat it N times
          emptyState: index == 0 ? const _EmptyState() : const SizedBox.shrink(),
          callback: () => exercises.getChartExerciseMetics(type, exercise.name, limit: _exerciseHistoryLimit),
          label: type.label(context),
          converter: type.converter(prefs, unit: unit),
          getLeftLabel: type.leftLabel(style),
          getTooltip: type.tooltip,
          errorState: const _ErrorState(),
        );
      },
    );
  }
}

const _exerciseHistoryLimit = 30;
