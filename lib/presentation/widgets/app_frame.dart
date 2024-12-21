import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heart_language/heart_language.dart';

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
        onTap: shell.goBranch,
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
}
