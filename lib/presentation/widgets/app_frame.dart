import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class AppFrame extends StatelessWidget {
  final StatefulNavigationShell shell;

  const AppFrame({
    super.key,
    required this.shell,
  });

  @override
  Widget build(BuildContext context) {
    final L(:profile, :workout, :history, :exercises) = L.of(context);

    final destinations = [
      (Icons.person_rounded, profile, () => null),
      (
        Icons.fitness_center_rounded,
        workout,
        () => Selector<Workouts, bool>(
              selector: (_, provider) => provider.hasActiveWorkout,
              builder: (_, hasActiveWorkout, __) {
                return switch (hasActiveWorkout) {
                  true => const Icon(Icons.fitness_center_rounded),
                  false => const Icon(Icons.add_circle_outline_rounded),
                };
              },
            ),
      ),
      (Icons.timeline_rounded, history, () => null),
      (Icons.list_rounded, exercises, () => null),
    ];

    return LayoutProvider(
      currentStack: shell.currentIndex,
      builder: (context, layout, stackIndex) {
        switch (layout) {
          case LayoutSize.compact:
            return _KeyMap(
              shell: shell,
              child: Scaffold(
                body: shell,
                bottomNavigationBar: BottomNavigationBar(
                  type: BottomNavigationBarType.shifting,
                  currentIndex: shell.currentIndex,
                  onTap: (index) => _onTap(context, index),
                  items: destinations.map((d) {
                    return BottomNavigationBarItem(
                      icon: switch (d.$3) {
                        Widget Function() builder => builder(),
                        _ => Icon(d.$1),
                      },
                      label: d.$2,
                    );
                  }).toList(),
                ),
              ),
            );

          case LayoutSize.wide:
            return _KeyMap(
              shell: shell,
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: shell.currentIndex,
                    onDestinationSelected: (index) => _onTap(context, index),
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations.map(
                      (d) {
                        return NavigationRailDestination(
                          icon: switch (d.$3) {
                            Widget Function() builder => builder(),
                            _ => Icon(d.$1),
                          },
                          label: Text(d.$2),
                        );
                      },
                    ).toList(),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: shell),
                ],
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
      // workout detail, brittle
      if (GoRouterState.of(context).matchedLocation.startsWith('/history/')) {
        return Scrolls.of(context).scrollEditableWorkoutToTop();
      }

      if (!context.canPop()) {
        return Scrolls.of(context).resetHistoryStack();
      }
    // exercises stack
    case 3:
      if (!context.canPop()) {
        return Scrolls.of(context).resetExerciseStack();
      } else {
        while (context.canPop()) {
          context.pop();
        }
      }
  }
}

class _KeyMap extends StatelessWidget {
  final Widget child;
  final StatefulNavigationShell shell;

  const _KeyMap({
    required this.child,
    required this.shell,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.bracketRight): _NextTabIntent(),
        LogicalKeySet(LogicalKeyboardKey.bracketLeft): _PreviousTabIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1): const _TabIntent(0),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2): const _TabIntent(1),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit3): const _TabIntent(2),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit4): const _TabIntent(3),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyN): _NewWorkoutIntent(),
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

class _NextTabIntent extends Intent {}

class _PreviousTabIntent extends Intent {}

class _NewWorkoutIntent extends Intent {}

class _TabIntent extends Intent {
  final int index;

  const _TabIntent(this.index);
}
