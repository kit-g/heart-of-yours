import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

Future<void> showWorkoutSheet(
  BuildContext context, {
  DraggableScrollableController? controller,
}) {
  final theme = Theme.of(context);

  return showModalBottomSheet(
    backgroundColor: theme.scaffoldBackgroundColor,
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
            final workouts = Workouts.watch(context);
            if (workouts.activeWorkout == null) {
              return const SizedBox.shrink();
            }
            return WorkoutDetail(
              exercises: workouts.activeWorkout!,
              controller: innerController,
              onDragExercise: workouts.append,
              onSwapExercise: workouts.swap,
              allowsCompletingSet: true,
              onAddSet: workouts.addSet,
              onRemoveSet: workouts.removeSet,
              onRemoveExercise: workouts.removeExercise,
              onAddExercises: (exercises) async {
                final workouts = Workouts.of(context);
                for (var each in exercises.toList()) {
                  await Future.delayed(
                    // for different IDs
                    const Duration(milliseconds: 2),
                    () => workouts.startExercise(each),
                  );
                }
              },
              appBar: SliverPersistentHeader(
                pinned: true,
                delegate: FixedHeightHeaderDelegate(
                  height: 40,
                  backgroundColor: theme.scaffoldBackgroundColor,
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
