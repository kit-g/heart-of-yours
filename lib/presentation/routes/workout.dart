import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  final _workoutNameController = TextEditingController();
  final _workoutNameFocusNode = FocusNode();

  @override
  void dispose() {
    _workoutNameController.dispose();
    _workoutNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :textTheme) = Theme.of(context);

    final L(:finish) = L.of(context);
    final workouts = Workouts.watch(context);

    if (workouts.activeWorkout?.name case String name when name.isNotEmpty) {
      _workoutNameController.text = name;
    }

    return SafeArea(
      child: Scaffold(
        body: ActiveWorkout(
          workouts: workouts,
          appBar: SliverAppBar(
            scrolledUnderElevation: 0,
            backgroundColor: scaffoldBackgroundColor,
            pinned: true,
            expandedHeight: 80.0,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (workouts.activeWorkout) {
                  null => Text(L.of(context).startWorkout),
                  _ => TextField(
                      focusNode: _workoutNameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textAlign: TextAlign.center,
                      controller: _workoutNameController,
                      style: textTheme.titleLarge,
                      decoration: const InputDecoration.collapsed(hintText: ''),
                      onEditingComplete: () {
                        final text = _workoutNameController.text.trim();
                        final name = switch (text.isEmpty) {
                          true => workouts.activeWorkout?.name ?? L.of(context).defaultWorkoutName(),
                          false => text,
                        };
                        workouts.renameWorkout(name);
                        _workoutNameFocusNode.unfocus();
                      },
                      onTapOutside: (_) {
                        _workoutNameFocusNode.unfocus();
                      },
                    ),
                },
              ),
            ),
          ),
          slivers: switch (workouts.activeWorkout) {
            Workout workout => [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: FixedHeightHeaderDelegate(
                    backgroundColor: scaffoldBackgroundColor,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        WorkoutTimer(
                          start: workout.start,
                          initValue: workout.elapsed(),
                          style: textTheme.titleSmall,
                        ),
                        PrimaryButton.shrunk(
                          onPressed: () {
                            _onFinish(context, workouts);
                          },
                          child: Text(finish),
                        )
                      ],
                    ),
                    height: 40,
                  ),
                ),
              ],
            null => null,
          },
        ),
      ),
    );
  }

  void _onFinish(BuildContext context, Workouts workouts) {
    workouts.finishWorkout();
  }
}
