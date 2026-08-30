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

  /// Appends this exercise to the workout in progress. Injected, like the
  /// other actions, so the composition root decides where the affordance
  /// exists at all — the dialog a workout opens over itself never gets one.
  /// Even when set, the button only shows while a workout is actually active
  /// (see [_AddToWorkoutAction]).
  final Future<void> Function(Exercise)? onAddToWorkout;

  const new({
    super.key,
    required this.exercise,
    required this.onTapWorkout,
    this.allowOptions = true,
    this.leading,
    this.onShareExercise,
    this.initialTab,
    this.onFilter,
    this.onTapAlternative,
    this.onAddToWorkout,
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
        onAddToWorkout: onAddToWorkout,
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
        onAddToWorkout: onAddToWorkout,
      ),
    };
  }
}

/// App-bar action that appends the exercise to the workout in progress.
///
/// The action arrives injected (see [ExerciseDetailPage.onAddToWorkout]); this
/// widget supplies the liveness — it watches [Workouts] so the button appears
/// and disappears with the active workout while the page stays open.
class _AddToWorkoutAction extends StatelessWidget {
  final Exercise exercise;
  final Future<void> Function(Exercise)? onAdd;

  const new({required this.exercise, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    // no injected action, no provider lookup: a page that was never given the
    // affordance must not require [Workouts] above it (tests pump it bare)
    return switch (onAdd) {
      null => const SizedBox.shrink(),
      final add => switch (Workouts.watch(context).hasActiveWorkout) {
        false => const SizedBox.shrink(),
        true => IconButton(
          tooltip: L.of(context).addToActiveWorkout,
          onPressed: () => add(exercise),
          icon: const Icon(Icons.playlist_add_rounded),
        ),
      },
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
