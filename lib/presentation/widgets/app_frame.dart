import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class AppFrame extends StatelessWidget {
  final StatefulNavigationShell shell;

  const new({
    super.key,
    required this.shell,
  });

  @override
  Widget build(BuildContext context) {
    final L(:profile, :workout, :history, :exercises) = L.of(context);

    final destinations = [
      (
        profile,
        () => const Icon(
          Icons.person_rounded,
          key: AppKeys.profileStack,
        ),
      ),
      (
        workout,
        () => Selector<Workouts, bool>(
          selector: (_, provider) => provider.hasActiveWorkout,
          builder: (_, hasActiveWorkout, _) {
            return AnimatedSwitcher(
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
          },
        ),
      ),
      (
        history,
        () => const Icon(
          Icons.timeline_rounded,
          key: AppKeys.historyStack,
        ),
      ),
      (
        exercises,
        () => const Icon(
          Icons.list_rounded,
          key: AppKeys.exercisesStack,
        ),
      ),
    ];

    return LayoutProvider(
      currentStack: shell.currentIndex,
      builder: (context, layout, stackIndex) {
        final ThemeData(:brightness) = Theme.of(context);
        final isDark = brightness == .dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? .light : .dark,
          statusBarBrightness: brightness, // iOS hint
          systemNavigationBarIconBrightness: isDark ? .light : .dark,
        );
        switch (layout) {
          case LayoutSize.compact:
            return _KeyMap(
              shell: shell,
              child: Scaffold(
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: shell,
                ),
                bottomNavigationBar: BottomNavigationBar(
                  type: BottomNavigationBarType.shifting,
                  currentIndex: shell.currentIndex,
                  onTap: (index) => _onTap(context, index),
                  items: destinations.map((d) {
                    return BottomNavigationBarItem(
                      icon: d.$2(),
                      label: d.$1,
                    );
                  }).toList(),
                ),
              ),
            );

          case LayoutSize.wide:
            return _KeyMap(
              shell: shell,
              child: Scaffold(
                body: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: overlayStyle,
                  child: Row(
                    children: [
                      NavigationRail(
                        key: AppKeys.navigationRail,
                        selectedIndex: shell.currentIndex,
                        onDestinationSelected: (index) => _onTap(context, index),
                        labelType: NavigationRailLabelType.all,
                        destinations: destinations.map(
                          (d) {
                            return NavigationRailDestination(
                              icon: d.$2(),
                              label: Text(d.$1),
                            );
                          },
                        ).toList(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: shell),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }

  Future<void> _onTap(BuildContext context, int index) async {
    HapticFeedback.mediumImpact();
    if (shell.currentIndex != index) {
      // switch to that navigation stack unless already there
      return shell.goBranch(index);
    } else {
      _customCallbacks(context, index);
    }
  }
}

Future<void> _customCallbacks(BuildContext context, int index) async {
  // custom callbacks based on the exact location
  switch (index) {
    // profile stack
    case 0:
      while (context.canPop()) {
        context.pop();
      }

      if (!context.canPop()) {
        return Scrolls.of(context).scrollProfileToTop();
      }
    // workout stack
    case 1:
      return Scrolls.of(context).scrollWorkoutToTop();
    // history stack
    case 2:
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
    case 3:
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

class _KeyMap extends StatelessWidget {
  final Widget child;
  final StatefulNavigationShell shell;

  const new({
    required this.child,
    required this.shell,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(.bracketRight): _NextTabIntent(),
        LogicalKeySet(.bracketLeft): _PreviousTabIntent(),
        LogicalKeySet(.meta, .digit1): const _TabIntent(0),
        LogicalKeySet(.meta, .digit2): const _TabIntent(1),
        LogicalKeySet(.meta, .digit3): const _TabIntent(2),
        LogicalKeySet(.meta, .digit4): const _TabIntent(3),
        LogicalKeySet(.meta, .keyN): _NewWorkoutIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) => _changeTab(context, shell, (shell.currentIndex + 1) % 4),
          ),
          _PreviousTabIntent: CallbackAction<_PreviousTabIntent>(
            onInvoke: (_) => _changeTab(context, shell, (shell.currentIndex - 1 + 4) % 4),
          ),
          _TabIntent: CallbackAction<_TabIntent>(
            onInvoke: (intent) => _changeTab(context, shell, intent.index),
          ),
          _NewWorkoutIntent: CallbackAction<_NewWorkoutIntent>(
            onInvoke: (_) {
              shell.goBranch(1);
              final name = L.of(context).defaultWorkoutName();
              return Workouts.of(context).startWorkout(name: name);
            },
          ),
        },
        child: child,
      ),
    );
  }

  void _changeTab(BuildContext context, StatefulNavigationShell shell, int index) {
    if (index != shell.currentIndex) {
      shell.goBranch(index);
    } else {
      _customCallbacks(context, index);
    }
  }
}

class _NextTabIntent extends Intent;

class _PreviousTabIntent extends Intent;

class _NewWorkoutIntent extends Intent;

class _TabIntent extends Intent {
  final int index;

  const new(this.index);
}
