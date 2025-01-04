part of 'active_workout.dart';

class _WorkoutExerciseItem extends StatelessWidget {
  final int index;
  final String copy;
  final WorkoutExercise exercise;
  final String firstColumnCopy;
  final String secondColumnCopy;
  final String thirdColumnCopy;
  final String fourthColumnCopy;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final ValueNotifier<WorkoutExercise?> dragState;
  final ValueNotifier<WorkoutExercise?> currentlyHoveredItem;

  const _WorkoutExerciseItem({
    required this.index,
    required this.exercise,
    required this.copy,
    required this.firstColumnCopy,
    required this.secondColumnCopy,
    required this.thirdColumnCopy,
    required this.fourthColumnCopy,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.dragState,
    required this.currentlyHoveredItem,
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
        currentlyHoveredItem.value = null;
        Workouts.of(context).swap(details.data, exercise);
      },
      onMove: (_) {
        currentlyHoveredItem.value = exercise;
      },
      builder: (_, candidates, rejects) {
        return ValueListenableBuilder<WorkoutExercise?>(
          valueListenable: dragState,
          builder: (_, draggedExercise, __) {
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
              child: switch (draggedExercise) {
                WorkoutExercise e when e != exercise => header,
                null => Padding(
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
                _ => const SizedBox.shrink(),
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
        return Workouts.of(context).removeExercise(exercise);
      case _ExerciseOption.addNote:
      case _ExerciseOption.replace:
      case _ExerciseOption.weightUnit:
      case _ExerciseOption.autoRestTimer:
      // TODO: Handle this case.
    }
  }
}
