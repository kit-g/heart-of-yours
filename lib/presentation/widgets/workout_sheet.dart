import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';
import 'package:heart_language/heart_language.dart';
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
          controller: controller,
          builder: (_, innerController) {
            final theme = Theme.of(context);
            final workouts = Workouts.watch(context);
            return ActiveWorkout(
              workouts: workouts,
              controller: innerController,
              appBar: SliverPersistentHeader(
                pinned: true,
                delegate: FixedHeightHeaderDelegate(
                  height: 40,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    topLeft: Radius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 40,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (workouts.activeWorkout?.start case DateTime start)
                              WorkoutTimer(
                                start: start,
                                style: theme.textTheme.titleSmall,
                                initValue: workouts.activeWorkout?.elapsed(),
                              ),
                            if (workouts.hasActiveWorkout)
                              PrimaryButton.shrunk(
                                onPressed: () {
                                  showFinishWorkoutDialog(context, workouts);
                                },
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(L.of(context).finish),
                              )
                          ],
                        ),
                      ),
                      if (workouts.activeWorkout?.name case String name)
                        SizedBox(
                          height: 40,
                          child: Center(
                            child: Text(
                              name,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
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
