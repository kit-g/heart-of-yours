import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';
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
            final theme = Theme.of(context);
            final workouts = Workouts.watch(context);
            return ActiveWorkout(
              workouts: workouts,
              controller: innerController,
              appBar: SliverPersistentHeader(
                pinned: true,
                delegate: FixedHeightHeaderDelegate(
                  height: 32,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    topLeft: Radius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (workouts.activeWorkout?.start case DateTime start)
                        WorkoutTimer(
                          start: start,
                          style: theme.textTheme.titleSmall,
                          initValue: workouts.activeWorkout?.elapsed(),
                        ),
                      if (workouts.activeWorkout?.name case String name)
                        Text(
                          name,
                          style: theme.textTheme.titleSmall,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
