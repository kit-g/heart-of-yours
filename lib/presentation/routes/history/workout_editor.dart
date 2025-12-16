part of 'history.dart';

class WorkoutEditor extends StatefulWidget {
  final Workout copy;
  final void Function({String? workoutId, String? imageId, String? imageLink, Uint8List? imageBytes})? onTapImage;

  const WorkoutEditor({
    super.key,
    required this.copy,
    this.onTapImage,
  });

  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> with HasHaptic<WorkoutEditor> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  late _WorkoutNotifier _notifier;

  Workout get workout => _notifier.workout;
  final _optionsButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _notifier = _WorkoutNotifier(widget.copy);
  }

  @override
  void didUpdateWidget(covariant WorkoutEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // navigated to a different workout
    if (widget.copy.id != oldWidget.copy.id) {
      _notifier = _WorkoutNotifier(widget.copy);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _notifier.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme, :textTheme, :platform) = Theme.of(context);
    final l = L.of(context);
    final L(:editWorkout, :save, :workoutName) = l;

    if ((_controller.text.isEmpty, workout.name) case (true, String name) when name.isNotEmpty) {
      _controller.text = name;
    }

    return ListenableBuilder(
      listenable: _notifier,
      builder: (_, __) {
        final hasImage = workout.remoteImage != null || workout.remoteImage != null;
        return PopScope(
          canPop: !_notifier.hasChanged,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _showDiscardTemplateDialog(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              backgroundColor: scaffoldBackgroundColor,
              title: Text(editWorkout),
              actions: [
                PrimaryButton.shrunk(
                  key: _optionsButtonKey,
                  child: Icon(
                    switch (platform) {
                      .iOS || .macOS => Icons.more_horiz_rounded,
                      _ => Icons.more_vert_rounded,
                    },
                    size: 20,
                  ),
                  onPressed: () {
                    showMenu<_WorkoutEditOption>(
                      context: context,
                      position: _optionsButtonKey.position(),
                      items: _WorkoutEditOption.values.map(
                        (option) {
                          return PopupMenuItem<_WorkoutEditOption>(
                            value: option,
                            onTap: _workoutOptionCallback(context, option, hasImage, workout.id),
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
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, __) {
                    final enabled = workout.isNotEmpty && value.text.isNotEmpty;
                    return AnimatedOpacity(
                      opacity: enabled ? 1 : .3,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: PrimaryButton.shrunk(
                          backgroundColor: colorScheme.secondaryContainer,
                          onPressed: switch (enabled) {
                            true => () {
                              _showFinishWorkoutDialog(
                                context,
                                workout,
                                onFinish: () {
                                  Workouts.of(context).saveWorkout(workout);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                            false => buzz,
                          },
                          child: Text(save),
                        ),
                      ),
                    );
                  },
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: AppBarTextField(
                    hint: workoutName,
                    style: textTheme.titleMedium,
                    hintStyle: textTheme.bodyLarge,
                    onChanged: (value) {
                      _notifier.name = value.trim();
                    },
                    focusNode: _focusNode,
                    controller: _controller,
                  ),
                ),
              ),
            ),
            body: SafeArea(
              child: WorkoutDetail(
                exercises: workout,
                needsCancelWorkoutButton: false,
                controller: Scrolls.of(context).editWorkoutScrollController,
                onDragExercise: _notifier.append,
                onSwapExercise: _notifier.swap,
                onAddSet: _notifier.addSet,
                onRemoveSet: _notifier.removeSet,
                onRemoveExercise: _notifier.removeExercise,
                onSetDone: _notifier.markSet,
                remoteImage: workout.remoteImage?.link,
                localImage: workout.localImage,
                onTapImage: widget.onTapImage,
                onAddExercises: (exercises) async {
                  for (final each in exercises.toList()) {
                    await Future.delayed(
                      // for different IDs
                      const Duration(milliseconds: 2),
                      () => _notifier.add(each),
                    );
                  }
                },
                allowsCompletingSet: true,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDiscardTemplateDialog(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(
      :quitEditing,
      :changesWillBeLost,
      :stayHere,
      :quitPage,
    ) = L.of(
      context,
    );

    return showBrandedDialog(
      context,
      title: Text(
        quitEditing,
        textAlign: TextAlign.center,
      ),
      content: Text(
        changesWillBeLost,
        textAlign: TextAlign.center,
      ),
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      actions: [
        Column(
          spacing: 8,
          children: [
            PrimaryButton.wide(
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
              child: Center(
                child: Text(stayHere),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            PrimaryButton.wide(
              backgroundColor: colorScheme.errorContainer,
              child: Center(
                child: Text(
                  quitPage,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                ),
              ),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showFinishWorkoutDialog(BuildContext context, Workout workout, {VoidCallback? onFinish}) async {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(
      :finishWorkoutWarningTitle,
      :finishWorkoutWarningBody,
      :readyToFinish,
      :notReadyToFinish,
    ) = L.of(
      context,
    );

    final actions = [
      Column(
        spacing: 8,
        children: [
          PrimaryButton.wide(
            backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
            child: Center(
              child: Text(notReadyToFinish),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
            },
          ),
          PrimaryButton.wide(
            backgroundColor: colorScheme.primaryContainer,
            child: Center(
              child: Text(readyToFinish),
            ),
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              onFinish?.call();
            },
          ),
        ],
      ),
    ];

    return showBrandedDialog(
      context,
      title: Text(finishWorkoutWarningTitle),
      titleTextStyle: textTheme.titleMedium,
      icon: Icon(
        Icons.error_outline_rounded,
        color: colorScheme.onErrorContainer,
      ),
      content: Text(
        finishWorkoutWarningBody,
        textAlign: TextAlign.center,
      ),
      actions: actions,
    );
  }

  String _workoutOptionCopy(L l, _WorkoutEditOption option, bool hasImage) {
    return switch (option) {
      .editImage => hasImage ? l.removePhoto : l.addPhoto,
      .editName => l.editWorkoutName,
    };
  }

  IconData _workoutOptionIcon(_WorkoutEditOption option) {
    return switch (option) {
      .editImage => Icons.photo_camera,
      .editName => Icons.edit_rounded,
    };
  }

  void Function() _workoutOptionCallback(
    BuildContext context,
    _WorkoutEditOption option,
    bool hasImage,
    String workoutId,
  ) {
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
                _attachImage(context, () => captureAndCropPhoto(context, cropImage), workoutId);
              },
              icon: const Icon(Icons.camera_alt_rounded),
            ),
          BottomMenuAction(
            title: chooseFromGallery,
            onPressed: () {
              pop();
              _attachImage(context, () => pickAndCropGalleryImage(context, cropImage), workoutId);
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
      Workouts.of(context).detachImageFromWorkout(workoutId);
      _notifier
        ..localImage = null
        ..remoteImage = null;
    }

    return switch (option) {
      .editImage => hasImage ? removePhoto : addPhoto,
      .editName => () {
        _focusNode.requestFocus();
      },
    };
  }

  Future<void> _attachImage(BuildContext context, Future<LocalImage?> Function() getImage, String workoutId) async {
    final workouts = Workouts.of(context);
    final localImage = await getImage();
    if (localImage != null) {
      final attached = await workouts.attachImageToWorkout(workoutId, localImage);
      if (attached) {
        _notifier.localImage = localImage.$1;
      }
    }
  }
}

class _WorkoutNotifier with ChangeNotifier {
  final Workout workout;

  bool _hasChanged = false;

  bool get hasChanged => _hasChanged;

  _WorkoutNotifier(this.workout);

  void addSet(WorkoutExercise exercise) {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    _forExercise(exercise, (each) => each.add(set));
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(exercise, (each) => each.remove(set));
  }

  void removeExercise(WorkoutExercise exercise) {
    workout.remove(exercise);
    notifyListeners();
  }

  void add(Exercise exercise) {
    workout.add(exercise);
    notifyListeners();
  }

  void markSet(WorkoutExercise _, ExerciseSet set) {
    set.isCompleted = !set.isCompleted;
    notifyListeners();
  }

  void swap(WorkoutExercise one, WorkoutExercise two) {
    workout.swap(one, two);
    notifyListeners();
  }

  void append(WorkoutExercise exercise) {
    workout.append(exercise);
    notifyListeners();
  }

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action) {
    workout.where((each) => each == exercise).forEach(action);
    notifyListeners();
  }

  set name(String? value) {
    workout.name = value;
    notifyListeners();
  }

  set localImage(Uint8List? asset) {
    workout.localImage = asset;
    notifyListeners();
  }

  set remoteImage(String? _) {
    workout.remoteImage = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _hasChanged = true;
    super.notifyListeners();
  }
}

enum _WorkoutEditOption { editImage, editName }
