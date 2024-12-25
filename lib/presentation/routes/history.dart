import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import '../widgets/workout_sheet.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Center(
        child: Text('HistoryPage'),
      ),
      floatingActionButton: Selector<Workouts, Workout?>(
        builder: (context, active, child) {
          if (active == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              showWorkoutSheet(context);
            },
            label: const Text('12:34:56'),
          );
        },
        selector: (_, workouts) => workouts.activeWorkout,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
