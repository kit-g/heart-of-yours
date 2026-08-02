part of 'exercises.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final void Function(Exercise exercise, {String? tab})? onShareExercise;
  final bool allowOptions;
  final Widget? leading;

  /// Tab to open on, by name (e.g. from a shared `?tab=charts` deep link).
  final String? initialTab;

  /// Opens the library filtered to the tapped category or target. When null the
  /// chips render as plain labels — navigating away is wrong from a dialog
  /// sitting on top of a workout.
  final void Function(ExerciseFilter)? onFilter;

  /// Opens a substitute suggested by the "also try" section.
  final void Function(Exercise)? onTapAlternative;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.onTapWorkout,
    this.allowOptions = true,
    this.leading,
    this.onShareExercise,
    this.initialTab,
    this.onFilter,
    this.onTapAlternative,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      .iOS || .macOS => _CupertinoExerciseDetailPage(
        exercise: exercise,
        onTapWorkout: onTapWorkout,
        allowOptions: allowOptions,
        leading: leading,
        onShareExercise: onShareExercise,
        initialTab: initialTab,
        onFilter: onFilter,
        onTapAlternative: onTapAlternative,
      ),
      _ => _MaterialExerciseDetailPage(
        exercise: exercise,
        onTapWorkout: onTapWorkout,
        allowOptions: allowOptions,
        leading: leading,
        onShareExercise: onShareExercise,
        initialTab: initialTab,
        onFilter: onFilter,
        onTapAlternative: onTapAlternative,
      ),
    };
  }
}

Future<void> showExerciseDetailDialog(BuildContext context, Exercise exercise) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExerciseDetailPage(
          exercise: exercise,
          onTapWorkout: (_) async {},
          allowOptions: false,
          leading: IconButton(
            tooltip: L.of(context).close,
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.close),
          ),
          // no `onFilter`: the library is a route away, and this dialog is
          // opened from a workout the lifter is in the middle of.
          onTapAlternative: (alternative) {
            Navigator.of(context).pop();
            showExerciseDetailDialog(context, alternative);
          },
        ),
      );
    },
  );
}
