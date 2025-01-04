import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';
import 'package:heart_state/heart_state.dart';

Future<void> showWorkoutSheet(
  BuildContext context, {
  DraggableScrollableController? controller,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: DraggableScrollableSheet(
          maxChildSize: .9,
          snapSizes: const [.5],
          snap: true,
          expand: false,
          builder: (_, innerController) {
            return Consumer<Workouts>(
              builder: (__, workouts, _) {
                return ActiveWorkout(
                  workouts: workouts,
                  controller: innerController,
                );
              },
            );
          },
        ),
      );
    },
  );
}
