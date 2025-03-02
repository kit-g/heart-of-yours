import 'package:flutter/material.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';

class WorkoutDone extends StatelessWidget {
  final Workout workout;
  final VoidCallback onQuit;

  const WorkoutDone({
    super.key,
    required this.workout,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final L(:congratulations, :congratulationsBody, :okBang) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onQuit,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 72),
            Text(
              congratulations,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              congratulationsBody,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 72),
            WorkoutItem(
              workout: workout,
              showsMenuButton: false,
            ),
            const SizedBox(height: 72),
            OutlinedButton(
              onPressed: onQuit,
              child: Text(okBang),
            ),
          ],
        ),
      ),
    );
  }
}
