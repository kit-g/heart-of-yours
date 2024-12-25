import 'package:flutter/material.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'buttons.dart';
import 'exercise_picker.dart';

const _fixedColumnWidth = 32.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

class ActiveWorkout extends StatefulWidget {
  final Workouts workouts;
  final Widget? appBar;
  final ScrollController? controller;

  const ActiveWorkout({
    super.key,
    required this.workouts,
    this.appBar,
    this.controller,
  });

  @override
  State<ActiveWorkout> createState() => _ActiveWorkoutState();
}

class _ActiveWorkoutState extends State<ActiveWorkout> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();

  Workouts get workouts => widget.workouts;

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
              backgroundColor: backgroundColor,
            ),
          ),
        if (workouts.activeWorkout case Workout workout)
          SliverList.builder(
            itemCount: workout.length,
            itemBuilder: (context, index) {
              var sets = workout.toList();
              var set = sets[index];
              return _WorkoutExerciseItem(
                exercise: set,
                copy: addSet,
                firstColumnCopy: setCopy,
                secondColumnCopy: previous,
                thirdColumnCopy: lbs,
                fourthColumnCopy: reps,
              );
            },
          ),
        if (workouts.hasActiveWorkout)
          SliverToBoxAdapter(
            child: Padding(
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
                      _cancelWorkout(context);
                    },
                    backgroundColor: colorScheme.errorContainer,
                    child: Center(
                      child: Text(
                        cancelWorkout,
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
      ],
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final Workouts(:startWorkout, :hasActiveWorkout) = Workouts.of(context);

    if (!hasActiveWorkout) {
      startWorkout(name: 'Afternoon workout');
    }
  }

  Future<void> _cancelWorkout(BuildContext context) async {
    Workouts.of(context).cancelActiveWorkout();
  }

  Future<Object?> _showExerciseDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return Consumer<Exercises>(
          builder: (__, exercises, _) {
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
      },
    );
  }
}

class _WorkoutExerciseItem extends StatelessWidget {
  final String copy;
  final WorkoutExercise exercise;
  final String firstColumnCopy;
  final String secondColumnCopy;
  final String thirdColumnCopy;
  final String fourthColumnCopy;

  const _WorkoutExerciseItem({
    required this.exercise,
    required this.copy,
    required this.firstColumnCopy,
    required this.secondColumnCopy,
    required this.thirdColumnCopy,
    required this.fourthColumnCopy,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              exercise.exercise.name,
              style: textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                SizedBox(
                  width: _fixedColumnWidth,
                  child: Center(child: Text(firstColumnCopy)),
                ),
                Expanded(
                  flex: 3,
                  child: Center(child: Text(secondColumnCopy)),
                ),
                Expanded(
                  child: Center(child: Text(thirdColumnCopy)),
                ),
                Flexible(
                  child: Center(child: Text(fourthColumnCopy)),
                ),
                const SizedBox(
                  width: _fixedColumnWidth,
                  child: Center(
                    child: Icon(
                      Icons.done,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...exercise.indexed.map(
            (set) {
              return _ExerciseSetItem(
                index: set.$1 + 1,
                set: set.$2,
                exercise: exercise,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    const Icon(
                      Icons.add,
                      size: 18,
                    ),
                    Text(copy),
                  ],
                ),
              ),
              onPressed: () {
                Workouts.of(context).addEmptySet(exercise);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSetItem extends StatelessWidget {
  final int index;
  final ExerciseSet set;
  final WorkoutExercise exercise;

  const _ExerciseSetItem({
    required this.set,
    required this.index,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final color = set.completed ? colorScheme.tertiaryContainer : colorScheme.outlineVariant.withValues(alpha: .5);

    return Dismissible(
      background: Container(
        color: colorScheme.error,
      ),
      onDismissed: (_) {
        Workouts.of(context).removeSet(exercise, set);
      },
      key: ValueKey(set.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
        child: Row(
          children: [
            PrimaryButton.shrunk(
              margin: EdgeInsets.zero,
              backgroundColor: color,
              child: SizedBox(
                width: _fixedColumnWidth,
                height: _fixedButtonHeight,
                child: Center(
                  child: Text('$index'),
                ),
              ),
              onPressed: () {},
            ),
            const Expanded(
              flex: 3,
              child: Center(child: Text(_emptyValue)),
            ),
            Expanded(
              child: SizedBox(
                height: _fixedButtonHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: PrimaryButton.shrunk(
                    margin: EdgeInsets.zero,
                    backgroundColor: color,
                    child: Center(
                      child: Text(
                        switch (set) {
                          // TODO: Handle this case.
                          AssistedSet() => _emptyValue,
                          // TODO: Handle this case.
                          CardioSet() => _emptyValue,
                          WeightedSet s => s.weight?.toString() ?? _emptyValue,
                        },
                      ),
                    ),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: _fixedButtonHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: PrimaryButton.shrunk(
                    backgroundColor: color,
                    margin: EdgeInsets.zero,
                    child: Center(
                      child: Text(
                        switch (set) {
                          // TODO: Handle this case.
                          CardioSet() => throw UnimplementedError(),
                          WeightedSet s => s.reps?.toString() ?? _emptyValue,
                          AssistedSet s => s.reps?.toString() ?? _emptyValue,
                        },
                      ),
                    ),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _fixedColumnWidth,
              height: _fixedButtonHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: PrimaryButton.shrunk(
                  backgroundColor: color,
                  margin: EdgeInsets.zero,
                  onPressed: () {
                    if (set.completed) {
                      Workouts.of(context).markSetAsIncomplete(exercise, set);
                    } else {
                      Workouts.of(context).markSetAsComplete(exercise, set);
                    }
                  },
                  child: const Center(
                    child: Icon(
                      Icons.done,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
