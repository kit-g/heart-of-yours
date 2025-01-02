import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'buttons.dart';
import 'exercise_picker.dart';

const _fixedColumnWidth = 32.0;
const _fixedButtonHeight = 24.0;
const _emptyValue = '-';

enum _ExerciseOption {
  addNote,
  replace,
  weightUnit,
  autoRestTimer,
  remove;
}

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
  final _isExerciseBeingDragged = ValueNotifier<bool>(false);

  Workouts get workouts => widget.workouts;

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    _isExerciseBeingDragged.dispose();

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
                dragState: _isExerciseBeingDragged,
                onDragStarted: () {
                  _isExerciseBeingDragged.value = true;
                },
                onDragEnded: () {
                  _isExerciseBeingDragged.value = false;
                },
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
                  const SizedBox(height: 8),
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
    return Workouts.of(context).cancelActiveWorkout();
  }

  Future<Object?> _showExerciseDialog(BuildContext context) {
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
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final ValueNotifier<bool> dragState;

  const _WorkoutExerciseItem({
    required this.exercise,
    required this.copy,
    required this.firstColumnCopy,
    required this.secondColumnCopy,
    required this.thirdColumnCopy,
    required this.fourthColumnCopy,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.dragState,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return DragTarget<WorkoutExercise>(
      onWillAcceptWithDetails: (details) {
        // only fire when the drag is dropped on any other exercise
        return exercise != details.data;
      },
      onAcceptWithDetails: (details) {
        Workouts.of(context).swap(details.data, exercise);
      },
      builder: (_, candidates, rejects) {
        return ValueListenableBuilder<bool>(
          valueListenable: dragState,
          builder: (_, isDragged, __) {
            final header = Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    exercise.exercise.name,
                    style: textTheme.titleMedium,
                  ),
                  PopupMenuButton<_ExerciseOption>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity(vertical: 0, horizontal: -2),
                    ),
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (option) => _onTapExerciseOption(context, option),
                    itemBuilder: (context) {
                      return _ExerciseOption.values.map(
                        (option) {
                          return PopupMenuItem<_ExerciseOption>(
                            height: 40,
                            value: option,
                            child: Text(
                              _exerciseOptionCopy(context, option),
                              style: _exerciseOptionStyle(textTheme, colorScheme, option),
                            ),
                          );
                        },
                      ).toList();
                    },
                  ),
                ],
              ),
            );

            return AnimatedSize(
              curve: Curves.easeInOut,
              duration: const Duration(milliseconds: 400),
              child: switch (isDragged) {
                true => header,
                false => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      LongPressDraggable<WorkoutExercise>(
                        delay: const Duration(milliseconds: 200),
                        data: exercise,
                        onDragStarted: onDragStarted,
                        onDragEnd: (_) => onDragEnded(),
                        onDragCompleted: onDragEnded,
                        onDraggableCanceled: (_, __) => onDragEnded(),
                        feedback: _Feedback(
                          exercise: exercise.exercise.name,
                          textTheme: textTheme,
                        ),
                        maxSimultaneousDrags: 1,
                        child: header,
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
                ),
              },
            );
          },
        );
      },
    );
  }

  String _exerciseOptionCopy(BuildContext context, _ExerciseOption option) {
    return switch (option) {
      _ExerciseOption.addNote => L.of(context).addNote,
      _ExerciseOption.replace => L.of(context).replaceExercise,
      _ExerciseOption.weightUnit => L.of(context).weightUnit,
      _ExerciseOption.autoRestTimer => L.of(context).restTimer,
      _ExerciseOption.remove => L.of(context).removeExercise,
    };
  }

  TextStyle? _exerciseOptionStyle(TextTheme theme, ColorScheme scheme, _ExerciseOption option) {
    return switch (option) {
      _ExerciseOption.remove => theme.titleSmall?.copyWith(color: scheme.error),
      _ => theme.titleSmall,
    };
  }

  Future<void> _onTapExerciseOption(BuildContext context, _ExerciseOption option) async {
    switch (option) {
      case _ExerciseOption.remove:
        Workouts.of(context).removeExercise(exercise);
      case _ExerciseOption.addNote:
      case _ExerciseOption.replace:
      case _ExerciseOption.weightUnit:
      case _ExerciseOption.autoRestTimer:
      // TODO: Handle this case.
    }
  }
}

class _ExerciseSetItem extends StatefulWidget {
  final int index;
  final ExerciseSet set;
  final WorkoutExercise exercise;

  const _ExerciseSetItem({
    required this.set,
    required this.index,
    required this.exercise,
  });

  @override
  State<_ExerciseSetItem> createState() => _ExerciseSetItemState();
}

class _ExerciseSetItemState extends State<_ExerciseSetItem> {
  ExerciseSet get set => widget.set;

  WorkoutExercise get exercise => widget.exercise;

  final _weightFocus = FocusNode();
  final _weightController = TextEditingController();
  final _repsFocus = FocusNode();
  final _repsController = TextEditingController();
  final _hasWeighError = ValueNotifier<bool>(false);
  final _hasRepsError = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _weightFocus.dispose();
    _weightController.dispose();
    _repsFocus.dispose();
    _repsController.dispose();
    _hasRepsError.dispose();
    _hasWeighError.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    final color = set.completed ? colorScheme.tertiaryContainer : colorScheme.outlineVariant.withValues(alpha: .5);

    return Dismissible(
      background: Container(color: colorScheme.error),
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
                  child: Text('${widget.index}'),
                ),
              ),
              onPressed: () {},
            ),
            const Expanded(
              flex: 3,
              child: Center(
                child: Text(_emptyValue),
              ),
            ),
            Expanded(
              child: _TextFieldButton(
                focusNode: _weightFocus,
                set: set,
                controller: _weightController,
                color: color,
                errorState: _hasWeighError,
              ),
            ),
            Expanded(
              child: _TextFieldButton(
                set: set,
                focusNode: _repsFocus,
                controller: _repsController,
                color: color,
                keyboardType: TextInputType.number,
                errorState: _hasRepsError,
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
                  onPressed: () => _onDone(context),
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

  void _onDone(BuildContext context) {
    final workouts = Workouts.of(context);
    if (set.completed) {
      return workouts.markSetAsIncomplete(exercise, set);
    }

    try {
      final weight = double.parse(_weightController.text);
      final reps = int.parse(_repsController.text);

      workouts.setWeight(exercise, set, weight);
      _hasWeighError.value = false;

      workouts.setReps(exercise, set, reps);
      _hasRepsError.value = false;

      if (set.canBeCompleted) {
        workouts.markSetAsComplete(exercise, set);
      }

      _repsFocus.unfocus();
      _weightFocus.unfocus();
    } on FormatException {
      final repsCorrect = int.tryParse(_repsController.text) != null;
      final weightCorrect = double.tryParse(_weightController.text) != null;

      _hasRepsError.value = !repsCorrect;
      _hasWeighError.value = !weightCorrect;
    }
  }
}

final _inputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d+(\.\d*)?')),
  LengthLimitingTextInputFormatter(5), // todo change to five digits, e.g. 123.45
  FilteringTextInputFormatter.singleLineFormatter,
];

class _TextFieldButton extends StatelessWidget {
  final FocusNode focusNode;
  final Color? color;
  final ExerciseSet set;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final ValueNotifier<bool> errorState;

  const _TextFieldButton({
    required this.focusNode,
    required this.errorState,
    this.color,
    required this.set,
    required this.controller,
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);

    return Focus(
      focusNode: focusNode,
      child: SizedBox(
        height: _fixedButtonHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: ListenableBuilder(
            listenable: focusNode,
            builder: (__, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: errorState,
                builder: (__, hasError, _) {
                  return PrimaryButton.shrunk(
                    margin: EdgeInsets.zero,
                    backgroundColor: hasError ? colorScheme.error : color,
                    border: switch ((hasError, focusNode.hasFocus, set.completed)) {
                      (true, true, _) => Border.all(
                          color: colorScheme.onErrorContainer,
                          width: .5,
                        ),
                      (_, true, true) => Border.all(
                          color: colorScheme.onTertiaryFixed,
                          width: .5,
                        ),
                      (_, true, false) => Border.all(
                          color: colorScheme.onSurfaceVariant,
                          width: .5,
                        ),
                      _ => null,
                    },
                    child: Center(
                      // refactor avoid creating a new theme for each item
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          textSelectionTheme: TextSelectionThemeData(
                            selectionColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .3),
                              false => null,
                            },
                            selectionHandleColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .5),
                              false => null,
                            },
                          ),
                          cupertinoOverrideTheme: NoDefaultCupertinoThemeData(
                            primaryColor: switch (hasError) {
                              true => colorScheme.onError.withValues(alpha: .5),
                              false => null,
                            },
                          ),
                        ),
                        child: TextField(
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          controller: controller,
                          inputFormatters: _inputFormatters,
                          decoration: const InputDecoration.collapsed(hintText: _emptyValue),
                          style: switch (hasError) {
                            true => textTheme.bodyMedium?.copyWith(color: colorScheme.onError),
                            false => textTheme.bodyMedium,
                          },
                          textAlign: TextAlign.center,
                          cursorHeight: 16,
                          textAlignVertical: TextAlignVertical.center,
                          maxLines: 1,
                          minLines: 1,
                          cursorColor: switch ((hasError, set.completed)) {
                            (true, _) => colorScheme.onError,
                            (false, true) => colorScheme.onTertiaryFixed,
                            (false, false) => colorScheme.onSurfaceVariant,
                          },
                          onSubmitted: (value) {
                            FocusScope.of(context).unfocus(); // Dismiss keyboard on done
                          },
                          onEditingComplete: () {},
                          onTap: () => _selectAllText(controller),
                        ),
                      ),
                    ),
                    onPressed: () {},
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

void _selectAllText(TextEditingController controller) {
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.value.text.length,
  );
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.exercise,
    required this.textTheme,
  });

  final String exercise;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 16,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          elevation: 3,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
