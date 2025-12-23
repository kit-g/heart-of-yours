part of 'exercises.dart';

class _Charts extends StatelessWidget {
  final Exercise exercise;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? weightHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? repsHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? distanceHistoryLookup;
  final Future<List<(num, DateTime)>?> Function(Exercise exercise)? durationHistoryLookup;

  const _Charts({
    required this.exercise,
    this.weightHistoryLookup,
    this.repsHistoryLookup,
    this.distanceHistoryLookup,
    this.durationHistoryLookup,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final ThemeData(:textTheme) = Theme.of(context);

    Widget durationLabel(double y) {
      return switch (_beautify(y)) {
        String v => Text(
          v,
          style: textTheme.bodySmall,
        ),
        null => const SizedBox.shrink(),
      };
    }

    Widget repsLabel(double y) {
      return switch (y % 1 == 0) {
        true => Text(
          y.toInt().toString(),
          style: textTheme.bodySmall,
        ),
        false => const SizedBox.shrink(),
      };
    }

    Widget weightLabel(double y) {
      return switch (y % 2 == 0) {
        true => Text(
          y.toInt().toString(),
          style: textTheme.bodySmall,
        ),
        false => const SizedBox.shrink(),
      };
    }

    switch (exercise.category) {
      case .weightedBodyWeight:
      case .assistedBodyWeight:
      case .barbell:
      case .machine:
      case .dumbbell:
        return ListView(
          children: [
            ExerciseChart(
              emptyState: const _EmptyState(),
              callback: () => weightHistoryLookup!(exercise),
              label: l.weightUnit,
              converter: (v) => prefs.weightValue(v),
              getLeftLabel: weightLabel,
              errorState: const _ErrorState(),
            ),
            const SizedBox(height: 12),
            ExerciseChart(
              emptyState: const SizedBox(),
              callback: () => repsHistoryLookup!(exercise),
              label: l.reps,
              converter: (v) => v.toDouble(),
              getLeftLabel: repsLabel,
              errorState: const _ErrorState(),
            ),
          ],
        );
      case .repsOnly:
        return Column(
          children: [
            ExerciseChart(
              emptyState: const _EmptyState(),
              callback: () => repsHistoryLookup!(exercise),
              label: l.reps,
              converter: (v) => v.toDouble(),
              getLeftLabel: repsLabel,
              errorState: const _ErrorState(),
            ),
          ],
        );
      case .cardio:
        return ListView(
          children: [
            ExerciseChart(
              emptyState: const _EmptyState(),
              callback: () => durationHistoryLookup!(exercise),
              label: l.duration,
              converter: (v) => v.toDouble(),
              getLeftLabel: durationLabel,
              getTooltip: (y) => Duration(seconds: y.toInt()).formatted(),
              errorState: const _ErrorState(),
            ),
            const SizedBox(height: 12),
            ExerciseChart(
              emptyState: const SizedBox(),
              callback: () => distanceHistoryLookup!(exercise),
              label: l.distanceUnit,
              converter: (v) => prefs.distanceValue(v),
              errorState: const _ErrorState(),
            ),
          ],
        );
      case .duration:
        return Column(
          children: [
            ExerciseChart(
              emptyState: const _EmptyState(),
              callback: () => durationHistoryLookup!(exercise),
              label: l.duration,
              converter: (v) => v.toDouble(),
              getLeftLabel: durationLabel,
              getTooltip: (y) => Duration(seconds: y.toInt()).formatted(),
              errorState: const _ErrorState(),
            ),
          ],
        );
    }
  }
}
