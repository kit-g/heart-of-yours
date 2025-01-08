library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/navigation/router.dart';
import 'package:heart/presentation/widgets/popping_text.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import '../buttons.dart';
import '../exercise_picker.dart';

part 'exercise_item.dart';

part 'feedback.dart';

part 'set_item.dart';

part 'text_field_button.dart';

part 'utils.dart';

class ActiveWorkout extends StatefulWidget {
  final Workouts workouts;
  final Widget? appBar;
  final ScrollController? controller;
  final List<Widget>? slivers;

  const ActiveWorkout({
    super.key,
    required this.workouts,
    this.appBar,
    this.controller,
    this.slivers,
  });

  @override
  State<ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends State<ActiveWorkout> with HasHaptic<ActiveWorkout> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  final _beingDragged = ValueNotifier<WorkoutExercise?>(null);
  final _currentlyHoveredExercise = ValueNotifier<WorkoutExercise?>(null);

  Workouts get workouts => widget.workouts;

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _beingDragged.dispose();
    _currentlyHoveredExercise.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :startNewWorkout,
      :startWorkout,
      :addExercises,
      :cancelWorkout,
      :addSet,
      set: setCopy,
      :previous,
      :lbs,
      :reps,
    ) = L.of(context);

    final ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      :colorScheme,
      :textTheme,
    ) = Theme.of(context);

    return CustomScrollView(
      controller: widget.controller,
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (widget.appBar case Widget appbar)
          appbar
        else
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
        ...?widget.slivers,
        if (!workouts.hasActiveWorkout)
          SliverPersistentHeader(
            pinned: true,
            delegate: FixedHeightHeaderDelegate(
              child: PrimaryButton.wide(
                onPressed: () => _startWorkout(context),
                child: Center(
                  child: Text(startNewWorkout),
                ),
              ),
              height: 40,
            ),
          ),
        if (workouts.activeWorkout case Workout workout)
          SliverList.builder(
            itemCount: workout.length + 1,
            itemBuilder: (_, index) {
              if (index == workout.length) {
                return ValueListenableBuilder<WorkoutExercise?>(
                  valueListenable: _currentlyHoveredExercise,
                  builder: (_, hoveredOver, __) {
                    return ValueListenableBuilder<WorkoutExercise?>(
                      valueListenable: _beingDragged,
                      builder: (_, dragged, __) {
                        return DragTarget<WorkoutExercise>(
                          onWillAcceptWithDetails: (_) {
                            _currentlyHoveredExercise.value = null;
                            return true;
                          },
                          onLeave: (_) {
                            _currentlyHoveredExercise.value = null;
                          },
                          onAcceptWithDetails: (details) {
                            workouts.append(details.data);
                          },
                          builder: (_, __, ___) {
                            return Column(
                              children: [
                                if (hoveredOver == null && dragged != null) _divider,
                                const SizedBox(height: 12),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              }

              var sets = workout.toList();
              var set = sets[index];
              return ValueListenableBuilder<WorkoutExercise?>(
                valueListenable: _currentlyHoveredExercise,
                builder: (_, hoveredOver, __) {
                  return Column(
                    children: [
                      if (hoveredOver == set) _divider,
                      _WorkoutExerciseItem(
                        index: index,
                        exercise: set,
                        copy: addSet,
                        firstColumnCopy: setCopy,
                        secondColumnCopy: previous,
                        thirdColumnCopy: lbs,
                        fourthColumnCopy: reps,
                        dragState: _beingDragged,
                        currentlyHoveredItem: _currentlyHoveredExercise,
                        onDragStarted: () {
                          _beingDragged.value = set;
                        },
                        onDragEnded: () {
                          buzz();
                          _beingDragged.value = null;
                          _currentlyHoveredExercise.value = null;
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        if (workouts.hasActiveWorkout)
          SliverToBoxAdapter(
            child: DragTarget<WorkoutExercise>(
              onWillAcceptWithDetails: (_) {
                _currentlyHoveredExercise.value = null;
                return true;
              },
              onLeave: (_) {
                _currentlyHoveredExercise.value = null;
              },
              onAcceptWithDetails: (details) {
                workouts.append(details.data);
              },
              builder: (_, __, ___) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      PrimaryButton.wide(
                        onPressed: () {
                          _showExerciseDialog(context);
                        },
                        child: Center(
                          child: Text(addExercises),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PrimaryButton.wide(
                        onPressed: () {
                          showCancelWorkoutDialog(
                            context,
                            workouts,
                          );
                        },
                        backgroundColor: colorScheme.errorContainer,
                        child: Center(
                          child: Text(
                            cancelWorkout,
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          )
      ],
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final Workouts(:startWorkout, :hasActiveWorkout) = Workouts.of(context);

    if (!hasActiveWorkout) {
      startWorkout(name: L.of(context).defaultWorkoutName());
    }
  }

  Future<Object?> _showExerciseDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        final exercises = Exercises.watch(context);
        return Card(
          child: ExercisePicker(
            exercises: exercises,
            searchController: _searchController,
            focusNode: _focusNode,
            onExerciseSelected: (exercise) {
              Navigator.pop(context);
              Workouts.of(context).startExercise(exercise);
            },
          ),
        );
      },
    );
  }
}

const _divider = Divider(
  thickness: 2,
  indent: 8,
  endIndent: 8,
);
