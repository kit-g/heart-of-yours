import 'package:go_router/go_router.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/navigation/keep_awake.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/tab_frame.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// The app's own space (#566 calls it that, beside Coaching): Profile,
/// Workout, History and Exercises, through [TabFrame].
///
/// Exercises can be left out (#608, [Feature.exercisesTab]): the bar then has
/// three tabs and reflows as if it never had a fourth. Its branch stays in the
/// shell, so turning the tab back on finds it where it was left.
class AppFrame extends StatelessWidget {
  /// The shell's branches, in the order the router declares them.
  static const _profile = 0;
  static const _workout = 1;
  static const _history = 2;
  static const _exercises = 3;

  final StatefulNavigationShell shell;

  const new({
    super.key,
    required this.shell,
  });

  @override
  Widget build(BuildContext context) {
    final L(:profile, :workout, :history, :exercises, :keepAwakeBadge) = L.of(context);
    final showsExercises = context.select<Preferences, bool>((preferences) => preferences.isOn(.exercisesTab));
    // left out while it was the tab on screen: the app moves to the first tab
    // rather than keep a screen the bar no longer names
    if (!showsExercises && shell.currentIndex == _exercises) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (shell.currentIndex == _exercises) shell.goBranch(_profile);
      });
    }

    final destinations = <TabDestination>[
      (
        label: profile,
        icon: (_) => const Icon(
          Icons.person_rounded,
          key: AppKeys.profileStack,
        ),
        branch: _profile,
      ),
      (
        label: workout,
        icon: (_) => Selector<Workouts, bool>(
          selector: (_, provider) => provider.hasActiveWorkout,
          builder: (context, hasActiveWorkout, _) {
            final icon = AnimatedSwitcher(
              key: AppKeys.workoutStack,
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                hasActiveWorkout ? Icons.fitness_center_rounded : Icons.add_circle_outline_rounded,
                key: ValueKey(hasActiveWorkout),
              ),
            );
            // the screen is being held on: said here because the bar is the
            // one thing on screen wherever the workout is left running
            return switch (KeepAwake.of(context)) {
              true => Semantics(
                label: keepAwakeBadge,
                child: Badge(
                  key: AppKeys.keepAwakeBadge,
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                  label: Icon(Icons.light_mode_rounded, size: 12, color: Theme.of(context).colorScheme.onTertiary),
                  padding: .zero,
                  child: icon,
                ),
              ),
              false => icon,
            };
          },
        ),
        branch: _workout,
      ),
      (
        label: history,
        icon: (_) => const Icon(
          Icons.timeline_rounded,
          key: AppKeys.historyStack,
        ),
        branch: _history,
      ),
      if (showsExercises)
        (
          label: exercises,
          icon: (_) => const Icon(
            Icons.list_rounded,
            key: AppKeys.exercisesStack,
          ),
          branch: _exercises,
        ),
    ];

    return Shortcuts(
      shortcuts: {LogicalKeySet(.meta, .keyN): _NewWorkoutIntent()},
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewWorkoutIntent: CallbackAction<_NewWorkoutIntent>(
            onInvoke: (_) {
              shell.goBranch(_workout);
              final name = L.of(context).defaultWorkoutName();
              return startWorkoutOverActive(
                context,
                () => Workouts.of(context).startWorkout(source: .blank, name: name),
              );
            },
          ),
        },
        child: TabFrame(
          shell: shell,
          destinations: destinations,
          onReselect: _customCallbacks,
        ),
      ),
    );
  }
}

Future<void> _customCallbacks(BuildContext context, int branch) async {
  // custom callbacks based on the exact location
  switch (branch) {
    // profile stack
    case AppFrame._profile:
      while (context.canPop()) {
        context.pop();
      }

      if (!context.canPop()) {
        return Scrolls.of(context).scrollProfileToTop();
      }
    // workout stack
    case AppFrame._workout:
      return Scrolls.of(context).scrollWorkoutToTop();
    // history stack
    case AppFrame._history:
      // Both scrollables, and no question asked about where the router is. A
      // controller with nothing attached scrolls nothing — see
      // [Scrolls._scrollToTop] — so the editor's is a no-op while the editor
      // is closed, which is all the old `/history/` location match was
      // standing in for. It broke the moment the route moved, and it read the
      // URL to answer a question the controller already answers.
      final scrolls = Scrolls.of(context);

      await Future.wait([
        scrolls.scrollEditableWorkoutToTop(),
        scrolls.resetHistoryStack(),
      ]);

      return;
    // exercises stack
    case AppFrame._exercises:
      // A navbar button is a back action: scroll the page's scrollable to the
      // top if there is one, otherwise back out. On one pane the detail is
      // covering the list and carries no controller of its own, so there is
      // nothing here to scroll and backing out is the whole action. On two it
      // sits *beside* the list, which is on screen and scrollable — so the
      // list goes to the top and the selection is left alone, the way the
      // history stack's editor is.
      // ...and one tap does one of them. While the detail is up the tap is
      // spent backing out of it; the list is only taken to the top once it is
      // the page you are actually looking at. Doing both at once meant a
      // single tap moved a list you could not see, and popping the whole
      // branch meant one tap undid several steps of "also try".
      if (LayoutProvider.of(context) == .compact && context.canPop()) {
        return context.pop();
      }

      return Scrolls.of(context).resetExerciseStack();
  }
}

class _NewWorkoutIntent extends Intent;
