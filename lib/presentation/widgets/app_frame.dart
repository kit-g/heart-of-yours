import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/utils/misc.dart';
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
            icon: const Icon(Icons.person),
            label: profile,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: workout,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.timeline),
            label: history,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center),
            label: exercises,
          ),
        ],
      ),
    );
  }

  Future<void> _onTap(BuildContext context, int index) async {
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
        // exercises stack
        case 3:
          return scrollToTop(Exercises.of(context).scrollController);
      }
    }
  }
}
