library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/utils/assets.dart';
import 'package:heart/core/utils/image_picker.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart/presentation/widgets/countdown.dart';
import 'package:heart/presentation/widgets/duration_picker.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/exercises/previous_exercise.dart' show PreviousSet;
import 'package:heart/presentation/widgets/exercises/previous_exercise.dart';
import 'package:heart/presentation/widgets/image.dart';
import 'package:heart/presentation/widgets/menu.dart';
import 'package:heart/presentation/widgets/popping_text.dart';
import 'package:heart/presentation/widgets/selection_controls.dart';
import 'package:heart/presentation/widgets/vector.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'timer.dart';

part 'empty_state.dart';
part 'exercise_item.dart';
part 'feedback.dart';
part 'keys.dart';
part 'set_item.dart';
part 'text_field_button.dart';
part 'utils.dart';

enum _WorkoutOption { editImage, editName }

class WorkoutDetail extends StatefulWidget {
  final Iterable<WorkoutExercise> exercises;
  final Widget? appBar;
  final ScrollController? controller;
  final List<Widget>? slivers;
  final void Function(WorkoutExercise) onDragExercise;
  final void Function(WorkoutExercise) onAddSet;
  final void Function(WorkoutExercise) onRemoveExercise;
  final void Function(WorkoutExercise dragged, WorkoutExercise current) onSwapExercise;
  final void Function(WorkoutExercise, ExerciseSet) onRemoveSet;
  final void Function(WorkoutExercise, ExerciseSet)? onSetDone;
  final void Function(Iterable<Exercise>) onAddExercises;
  final bool needsCancelWorkoutButton;
  final bool allowsCompletingSet;
  final Uint8List? localImage;
  final String? remoteImage;
  final void Function({String? workoutId, String? imageId, String? imageLink, Uint8List? imageBytes})? onTapImage;
  final String? workoutId;
  final void Function(Exercise) onTapExercise;

  const WorkoutDetail({
    super.key,
    required this.exercises,
    this.appBar,
    this.controller,
    this.slivers,
    required this.onDragExercise,
    required this.onAddSet,
    required this.onRemoveSet,
    this.onSetDone,
    required this.onRemoveExercise,
    required this.onSwapExercise,
    required this.onAddExercises,
    this.needsCancelWorkoutButton = true,
    required this.allowsCompletingSet,
    this.localImage,
    this.remoteImage,
    this.onTapImage,
    this.workoutId,
    required this.onTapExercise,
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
    ) = L.of(
      context,
    );

    final ThemeData(
      scaffoldBackgroundColor: backgroundColor,
      :colorScheme,
      :textTheme,
    ) = Theme.of(
      context,
    );

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
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: switch (widget.localImage != null || widget.remoteImage != null) {
              false => const SizedBox.shrink(),
              true => Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 8, right: 8),
                child: GestureDetector(
                  onTap: () {
                    widget.onTapImage?.call(
                      workoutId: widget.workoutId,
                      imageBytes: widget.localImage,
                      imageLink: widget.remoteImage,
                    );
                  },
                  child: Container(
                    key: ValueKey(widget.localImage ?? widget.remoteImage),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppImage(
                        url: widget.remoteImage,
                        bytes: widget.localImage,
                        fit: .cover,
                      ),
                    ),
                  ),
                ),
              ),
            },
          ),
        ),
        switch (exercises.isEmpty) {
          true => const _EmptyState(size: 320),
          false => _exerciseList(colorScheme, addSet, setCopy, previous),
        },
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
            builder: (_, _, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    PrimaryButton.wide(
                      onPressed: () {
                        _showExerciseDialog(context);
                      },
                      key: WorkoutDetailKeys.addExercises,
                      child: Center(
                        child: Text(addExercises),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.needsCancelWorkoutButton) ...[
                      PrimaryButton.wide(
                        key: WorkoutDetailKeys.cancelWorkout,
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
                      const SizedBox(height: 60),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  SliverList _exerciseList(ColorScheme colorScheme, String addSet, String setCopy, String previous) {
    return SliverList.builder(
      itemCount: exercises.length + 1,
      itemBuilder: (_, index) {
        if (index == exercises.length) {
          return ValueListenableBuilder<WorkoutExercise?>(
            valueListenable: _currentlyHoveredExercise,
            builder: (_, hoveredOver, _) {
              return ValueListenableBuilder<WorkoutExercise?>(
                valueListenable: _beingDragged,
                builder: (_, dragged, _) {
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
                    builder: (_, _, _) {
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
          builder: (_, hoveredOver, _) {
            return Column(
              children: [
                if (hoveredOver == set) _divider,
                Selector<Workouts, bool>(
                  builder: (_, isPointedAt, _) {
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
                        onSetDone: widget.onSetDone,
                        onRemoveExercise: widget.onRemoveExercise,
                        onSwapExercise: widget.onSwapExercise,
                        onDragStarted: () {
                          _beingDragged.value = set;
                        },
                        onDragEnded: () {
                          buzz();
                          _beingDragged.value = null;
                          _currentlyHoveredExercise.value = null;
                        },
                        allowCompleting: widget.allowsCompletingSet,
                        onTapExercise: widget.onTapExercise,
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
    );
  }

  Future<Object?> _showExerciseDialog(BuildContext context) {
    final ThemeData(
      colorScheme: ColorScheme(surfaceContainerLow: color),
      :textTheme,
    ) = Theme.of(
      context,
    );
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
                          key: WorkoutDetailKeys.addExerciseButton,
                          child: Center(
                            child: Text(add),
                          ),
                          onPressed: () async {
                            widget.onAddExercises(exercises.selected);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                height: 40,
                borderRadius: const .all(.circular(12)),
              ),
            ),
            exercises: exercises,
            backgroundColor: color,
            searchController: _searchController,
            focusNode: _focusNode,
            onExerciseSelected: (exercise, _) {
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
          () {
            // ignore: use_build_context_synchronously
            Exercises.of(context)
              ..unselectAll()
              ..clearFilters();
          },
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
  final VoidCallback openWorkoutSheet;

  const NewWorkoutHeader({
    super.key,
    required this.openWorkoutSheet,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: FixedHeightHeaderDelegate(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: PrimaryButton.wide(
          key: WorkoutDetailKeys.startNewWorkout,
          onPressed: () => _startWorkout(context),
          child: Center(
            child: Selector<Workouts, bool>(
              selector: (_, provider) => provider.hasActiveWorkout,
              builder: (_, hasActiveWorkout, _) {
                if (hasActiveWorkout) {
                  return Text(L.of(context).goToWorkout);
                } else {
                  return Text(L.of(context).startNewWorkout);
                }
              },
            ),
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

    openWorkoutSheet();
  }
}

class ActiveWorkoutSheet extends StatefulWidget {
  final Workouts workouts;
  final double closingThreshold;
  final void Function({String? workoutId, String? imageId, String? imageLink, Uint8List? imageBytes})? onTapImage;

  const ActiveWorkoutSheet({
    super.key,
    required this.workouts,
    this.closingThreshold = .25,
    this.onTapImage,
  });

  @override
  State<ActiveWorkoutSheet> createState() => _ActiveWorkoutSheetState();
}

class _ActiveWorkoutSheetState extends State<ActiveWorkoutSheet> {
  final _sheetController = DraggableScrollableController();
  bool _isClosing = false;

  final _optionsButtonKey = GlobalKey();
  final _workoutNameController = TextEditingController();
  final _workoutNameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();

    _workoutNameController.dispose();
    _workoutNameFocusNode.dispose();

    super.dispose();
  }

  void _onSheetChanged() {
    // when dragged to minimum size, dismiss the route
    if (_sheetController.size <= widget.closingThreshold && !_isClosing) {
      _isClosing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final workouts = Workouts.of(context);

    if (workouts.activeWorkout?.name case String name when name.isNotEmpty) {
      if (name != _workoutNameController.text) {
        _workoutNameController.text = name;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :scaffoldBackgroundColor, :textTheme, :platform) = Theme.of(context);
    final l = L.of(context);
    final workouts = widget.workouts;
    final active = workouts.activeWorkout!;
    final hasImage = active.localImage != null || active.remoteImage != null;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.2,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.5, 1.0],
      controller: _sheetController,
      expand: false,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: WorkoutDetail(
            controller: scrollController,
            exercises: active,
            remoteImage: active.remoteImage?.link,
            localImage: active.localImage,
            onTapImage: widget.onTapImage,
            workoutId: active.id,
            onDragExercise: workouts.append,
            onSwapExercise: workouts.swap,
            allowsCompletingSet: true,
            onAddSet: workouts.addSet,
            onRemoveSet: workouts.removeSet,
            onRemoveExercise: workouts.removeExercise,
            onTapExercise: (exercise) => showExerciseDetailDialog(context, exercise),
            onAddExercises: (exercises) async {
              final workouts = Workouts.of(context);
              for (final each in exercises.toList()) {
                await Future.delayed(
                  const Duration(milliseconds: 2),
                  () => workouts.startExercise(each),
                );
              }
            },
            appBar: SliverPersistentHeader(
              pinned: true,
              delegate: FixedHeightHeaderDelegate(
                height: 40,
                backgroundColor: scaffoldBackgroundColor,
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
                            Row(
                              spacing: 4,
                              children: [
                                Container(
                                  key: _optionsButtonKey,
                                  child: PrimaryButton.shrunk(
                                    key: WorkoutDetailKeys.options,
                                    child: Icon(
                                      switch (platform) {
                                        .iOS || .macOS => Icons.more_horiz_rounded,
                                        _ => Icons.more_vert_rounded,
                                      },
                                    ),
                                    onPressed: () {
                                      showMenu<_WorkoutOption>(
                                        context: context,
                                        position: _optionsButtonKey.position(),
                                        items: _WorkoutOption.values.map(
                                          (option) {
                                            return PopupMenuItem<_WorkoutOption>(
                                              value: option,
                                              onTap: _workoutOptionCallback(context, option, hasImage),
                                              child: Row(
                                                spacing: 6,
                                                children: [
                                                  Icon(_workoutOptionIcon(option)),
                                                  Text(_workoutOptionCopy(l, option, hasImage)),
                                                ],
                                              ),
                                            );
                                          },
                                        ).toList(),
                                      );
                                    },
                                  ),
                                ),
                                WorkoutTimer(
                                  key: WorkoutDetailKeys.timer,
                                  start: start,
                                  style: textTheme.titleSmall,
                                  initValue: workouts.activeWorkout?.elapsed(),
                                ),
                              ],
                            ),
                          if (workouts.hasActiveWorkout)
                            PrimaryButton.shrunk(
                              key: WorkoutDetailKeys.finishWorkout,
                              onPressed: () {
                                showFinishWorkoutDialog(context, workouts);
                              },
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text(L.of(context).finish),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 180,
                          child: TextField(
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(18),
                            ],
                            selectionControls: context.platformSpecificSelectionControls(),
                            focusNode: _workoutNameFocusNode,
                            textCapitalization: TextCapitalization.words,
                            textAlign: TextAlign.center,
                            controller: _workoutNameController,
                            style: textTheme.titleSmall,
                            decoration: const InputDecoration.collapsed(hintText: ''),
                            onEditingComplete: () {
                              final text = _workoutNameController.text.trim();
                              final name = switch (text.isEmpty) {
                                true => workouts.activeWorkout?.name?.trim() ?? L.of(context).defaultWorkoutName(),
                                false => text.trim(),
                              };
                              workouts.renameWorkout(name);
                              _workoutNameFocusNode.unfocus();
                            },
                            onTapOutside: (_) {
                              _workoutNameFocusNode.unfocus();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _workoutOptionCopy(L l, _WorkoutOption option, bool hasImage) {
    return switch (option) {
      .editImage => hasImage ? l.removePhoto : l.addPhoto,
      .editName => l.editWorkoutName,
    };
  }

  IconData _workoutOptionIcon(_WorkoutOption option) {
    return switch (option) {
      .editImage => Icons.photo_camera,
      .editName => Icons.edit_rounded,
    };
  }

  FutureOr<void> Function() _workoutOptionCallback(BuildContext context, _WorkoutOption option, bool hasImage) {
    final L(:capturePhoto, :chooseFromGallery, :cancel, :cropImage) = L.of(context);

    final pop = Navigator.of(context).pop;
    final supportsTakingPhoto = context.supportsTakingPhoto();

    Future<void> addPhoto() {
      return showBottomMenu<void>(
        context,
        [
          if (supportsTakingPhoto)
            BottomMenuAction(
              title: capturePhoto,
              onPressed: () {
                pop();
                _attachImage(context, () => captureAndCropPhoto(context, cropImage));
              },
              icon: const Icon(Icons.camera_alt_rounded),
            ),
          BottomMenuAction(
            title: chooseFromGallery,
            onPressed: () {
              pop();
              _attachImage(context, () => pickAndCropGalleryImage(context, cropImage));
            },
            icon: const Icon(Icons.photo_library_rounded),
          ),
          BottomMenuAction(
            title: cancel,
            onPressed: pop,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      );
    }

    void removePhoto() {
      Workouts.of(context).detachImageFromActiveWorkout();
    }

    return switch (option) {
      .editImage => hasImage ? removePhoto : addPhoto,
      .editName => () {
        _workoutNameFocusNode.requestFocus();
        _workoutNameController.selectAllText();
      },
    };
  }

  Future<void> _attachImage(BuildContext context, Future<LocalImage?> Function() getImage) async {
    final workouts = Workouts.of(context);
    final localImage = await getImage();
    if (localImage != null) {
      workouts.attachImageToActiveWorkout(localImage);
    }
  }
}
