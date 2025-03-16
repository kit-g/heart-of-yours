import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/utils/scrolls.dart';
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
    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        currentIndex: shell.currentIndex,
        enableFeedback: true,
        onTap: (index) => _onTap(context, index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_rounded),
            label: profile,
          ),
          BottomNavigationBarItem(
            icon: Selector<Workouts, bool>(
              selector: (_, provider) => provider.hasActiveWorkout,
              builder: (_, hasActiveWorkout, __) {
                return switch (hasActiveWorkout) {
                  true => const Icon(Icons.fitness_center_rounded),
                  false => const Icon(Icons.add_circle_outline_rounded),
                };
              },
            ),
            label: workout,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timeline_rounded),
            label: history,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.list_rounded),
            label: exercises,
          ),
        ],
      ),
    );
  }

  Future<void> _onTap(BuildContext context, int index) async {
    HapticFeedback.mediumImpact();
    if (shell.currentIndex != index) {
      // switch to that navigation stack unless already there
      return shell.goBranch(index);
    } else {
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
          if (GoRouterState.of(context).matchedLocation == '/history/edit') {
            return Scrolls.of(context).scrollEditableWorkoutToTop();
          }

          if (!context.canPop()) {
            return Scrolls.of(context).resetHistoryStack();
          }
        // exercises stack
        case 3:
          return Scrolls.of(context).resetExerciseStack();
      }
    }
  }
}
