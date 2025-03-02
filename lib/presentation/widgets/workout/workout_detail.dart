library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/countdown.dart';
import 'package:heart/presentation/widgets/duration_picker.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/popping_text.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import '../buttons.dart';

part 'exercise_item.dart';

part 'feedback.dart';

part 'set_item.dart';

part 'text_field_button.dart';

part 'utils.dart';

class WorkoutDetail extends StatefulWidget {
  final Iterable<WorkoutExercise> exercises;
  final Widget? appBar;
  final ScrollController? controller;
  final List<Widget>? slivers;
  final void Function(WorkoutExercise) onDragExercise;
  final void Function(WorkoutExercise) onAddSet;
  final void Function(WorkoutExercise) onRemoveExercise;
  final void Function(WorkoutExercise, ExerciseSet) onRemoveSet;
  final void Function(Iterable<Exercise>) onAddExercises;
  final bool needsCancelWorkoutButton;
  final bool allowsCompletingSet;

  const WorkoutDetail({
    super.key,
    required this.exercises,
    this.appBar,
    this.controller,
    this.slivers,
    required this.onDragExercise,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemoveExercise,
    required this.onAddExercises,
    this.needsCancelWorkoutButton = true,
    required this.allowsCompletingSet,
  });

  @override
  State<WorkoutDetail> createState() => _WorkoutDetailState();
}

class _WorkoutDetailState extends State<WorkoutDetail> with HasHaptic<WorkoutDetail> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();
  final _beingDragged = ValueNotifier<WorkoutExercise?>(null);
  final _currentlyHoveredExercise = ValueNotifier<WorkoutExercise?>(null);

  Iterable<WorkoutExercise> get exercises => widget.exercises;

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
      :restTimer,
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
        SliverList.builder(
          itemCount: exercises.length + 1,
          itemBuilder: (_, index) {
            if (index == exercises.length) {
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
                          widget.onDragExercise(details.data);
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

            var sets = exercises.toList();
            var set = sets[index];
            return ValueListenableBuilder<WorkoutExercise?>(
              valueListenable: _currentlyHoveredExercise,
              builder: (_, hoveredOver, __) {
                return Column(
                  children: [
                    if (hoveredOver == set) _divider,
                    Selector<Workouts, bool>(
                      builder: (_, isPointedAt, __) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          color: isPointedAt ? colorScheme.primary : Colors.transparent,
                          child: _WorkoutExerciseItem(
                            index: index,
                            exercise: set,
                            copy: addSet,
                            firstColumnCopy: setCopy,
                            secondColumnCopy: previous,
                            dragState: _beingDragged,
                            currentlyHoveredItem: _currentlyHoveredExercise,
                            onAddSet: widget.onAddSet,
                            onRemoveSet: widget.onRemoveSet,
                            onRemoveExercise: widget.onRemoveExercise,
                            onDragStarted: () {
                              _beingDragged.value = set;
                            },
                            onDragEnded: () {
                              buzz();
                              _beingDragged.value = null;
                              _currentlyHoveredExercise.value = null;
                            },
                            allowCompleting: widget.allowsCompletingSet,
                          ),
                        );
                      },
                      selector: (_, provider) => provider.pointedAtExercise == set.id,
                    ),
                  ],
                );
              },
            );
          },
        ),
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
              widget.onDragExercise(details.data);
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
                    if (widget.needsCancelWorkoutButton) ...[
                      PrimaryButton.wide(
                        onPressed: () {
                          showCancelWorkoutDialog(
                            context,
                            onFinish: () {
                              Scrolls.of(context)
                                ..resetExerciseStack()
                                ..resetHistoryStack();
                            },
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
                    ]
                  ],
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Future<Object?> _showExerciseDialog(BuildContext context) {
    final ThemeData(
      colorScheme: ColorScheme(surfaceContainerLow: color),
      :textTheme,
    ) = Theme.of(context);
    final L(:add) = L.of(context);
    return showDialog(
      context: context,
      builder: (context) {
        final exercises = Exercises.watch(context);
        return Card(
          child: ExercisePicker(
            appBar: SliverPersistentHeader(
              pinned: true,
              delegate: FixedHeightHeaderDelegate(
                backgroundColor: color,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      visualDensity: const VisualDensity(horizontal: -4, vertical: -1),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                    ),
                    Row(
                      spacing: 16,
                      children: [
                        if (exercises.selected.length case int selected when selected > 1)
                          Text(
                            L.of(context).selected(selected),
                          ),
                        PrimaryButton.shrunk(
                          child: Center(
                            child: Text(add),
                          ),
                          onPressed: () async {
                            widget.onAddExercises(exercises.selected);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    )
                  ],
                ),
                height: 40,
                borderRadius: const BorderRadius.all(
                  Radius.circular(12),
                ),
              ),
            ),
            exercises: exercises,
            backgroundColor: color,
            searchController: _searchController,
            focusNode: _focusNode,
            onExerciseSelected: (exercise) {
              if (exercises.hasSelected(exercise)) {
                exercises.deselect(exercise);
              } else {
                exercises.select(exercise);
              }
            },
          ),
        );
      },
    ).then<void>(
      (_) {
        Future.delayed(
          const Duration(milliseconds: 100),
          // ignore: use_build_context_synchronously
          () => Exercises.of(context).unselectAll(),
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

class NewWorkoutHeader extends StatelessWidget {
  const NewWorkoutHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: FixedHeightHeaderDelegate(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: PrimaryButton.wide(
          onPressed: () => _startWorkout(context),
          child: Center(
            child: Text(L.of(context).startNewWorkout),
          ),
        ),
        height: 40,
      ),
    );
  }

  Future<void> _startWorkout(BuildContext context) async {
    final Workouts(:startWorkout, :hasActiveWorkout) = Workouts.of(context);

    if (!hasActiveWorkout) {
      startWorkout(name: L.of(context).defaultWorkoutName());
    }
  }
}
