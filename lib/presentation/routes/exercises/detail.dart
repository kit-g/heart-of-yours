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
    // Keyed by the exercise, so picking a sibling in the two-pane master list
    // builds a new State instead of pouring a new exercise into the old one.
    // Everything below seeds itself once — `_sections` and the tab controller
    // here, the queries in the History and Records tabs — so without this the
    // two stateless tabs (About, Charts) tracked the selection and the two
    // stateful ones went on showing the exercise you arrived with. It also
    // keeps the controller's length honest: `sections` drops About for an
    // exercise with no info, and a stale length mismatches the children.
    //
    // The remembered tab survives because it is library-scoped, not State —
    // see [_rememberedSection].
    final key = ValueKey(exercise.id);

    return switch (Theme.of(context).platform) {
      .iOS || .macOS => _CupertinoExerciseDetailPage(
        key: key,
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
        key: key,
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
