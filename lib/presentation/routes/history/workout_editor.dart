part of 'history.dart';

class WorkoutEditor extends StatefulWidget {
  final Workout copy;
  final Future<void> Function(Iterable<Media>, {required int startingIndex, String? workoutId})? onTapImage;

  /// Empties the two-pane detail. Null in compact, where the editor is a pushed
  /// route and popping it is the right thing.
  final VoidCallback? onClose;

  const new({
    super.key,
    required this.copy,
    this.onTapImage,
    this.onClose,
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
    final L(:editWorkout, :save, :workoutName, :defaultWorkoutName) = l;

    if ((_controller.text.isEmpty, workout.name) case (true, String name) when name.isNotEmpty) {
      _controller.text = name;
    }

    return ListenableBuilder(
      listenable: _notifier,
      builder: (_, _) {
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
              // in a persistent pane there is nothing behind to go back to, so
              // the control says "put this away" instead
              leading: switch (widget.onClose) {
                null => null,
                _ => IconButton(
                  key: AppKeys.closeDetail,
                  tooltip: L.of(context).close,
                  onPressed: () => _close(context),
                  icon: const Icon(Icons.close),
                ),
              },
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
                            onTap: _workoutOptionCallback(context, option, workout),
                            child: Row(
                              spacing: 6,
                              children: [
                                Icon(_workoutOptionIcon(option)),
                                Text(_workoutOptionCopy(l, option)),
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
                  builder: (_, value, _) {
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
                                  workout.resolveName(defaultWorkoutName());
                                  Workouts.of(context).editWorkout(workout);
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
                  padding: const .only(left: 8, bottom: 2, right: 8),
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
                slivers: [
                  SliverToBoxAdapter(
                    child: _WorkoutTimesSummary(
                      workout: workout,
                      onTap: () => _openTimesDialog(context, workout),
                    ),
                  ),
                ],
                controller: Scrolls.of(context).editWorkoutScrollController,
                onDragExercise: _notifier.append,
                onSwapExercise: _notifier.swap,
                onAddSet: _notifier.addSet,
                onRemoveSet: _notifier.removeSet,
                onRemoveExercise: _notifier.removeExercise,
                onSetDone: _notifier.markSet,
                workoutImages: workout.images?.values,
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
                onTapExercise: (exercise) => showExerciseDetailDialog(context, exercise),
                onDeleteImage: (image) {
                  return showDeleteImageDialog(
                    context,
                    workout,
                    image,
                    onDeleted: (context) async {
                      Navigator.of(context, rootNavigator: true).pop();
                      _notifier.detachImageFromWorkout(image);
                      await Workouts.of(context).detachImageFromWorkout(workout, image);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dismisses the pane, routing through the same unsaved-changes guard that
  /// [PopScope] gives the pushed route — closing must not be a quiet way to
  /// throw edits away.
  void _close(BuildContext context) {
    final close = widget.onClose;
    if (close == null) return;

    switch (_notifier.hasChanged) {
      case true:
        _showDiscardTemplateDialog(context, onQuit: close);
      case false:
        close();
    }
  }

  Future<void> _showDiscardTemplateDialog(BuildContext context, {VoidCallback? onQuit}) {
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
        textAlign: .center,
      ),
      content: Text(
        changesWillBeLost,
        textAlign: .center,
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
                switch (onQuit) {
                  // pushed route: leaving means popping it
                  case null:
                    Navigator.of(context).pop();
                  // persistent pane: there is no route to pop, only a
                  // selection to clear
                  case VoidCallback quit:
                    quit();
                }
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

  String _workoutOptionCopy(L l, _WorkoutEditOption option) {
    return switch (option) {
      .editImage => l.addPhoto,
      .editName => l.editWorkoutName,
      .editTimes => l.editWorkoutTimes,
    };
  }

  IconData _workoutOptionIcon(_WorkoutEditOption option) {
    return switch (option) {
      .editImage => Icons.photo_camera,
      .editName => Icons.edit_rounded,
      .editTimes => Icons.schedule_rounded,
    };
  }

  void Function() _workoutOptionCallback(BuildContext context, _WorkoutEditOption option, Workout workout) {
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
                _attachImage(context, () => captureAndCropPhoto(context, cropImage), workout);
              },
              icon: const Icon(Icons.camera_alt_rounded),
            ),
          BottomMenuAction(
            title: chooseFromGallery,
            onPressed: () {
              pop();
              _attachImage(context, () => pickAndCropGalleryImage(context, cropImage), workout);
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

    return switch (option) {
      .editImage => addPhoto,
      .editName => () => _focusNode.requestFocus(),
      .editTimes => () => _openTimesDialog(context, workout),
    };
  }

  /// Opens the "Adjust Start/End Time" dialog — from the menu item or the
  /// linkified date/duration header. The dialog works in local time; we convert
  /// to UTC on the wire and only patch the fields that actually changed.
  Future<void> _openTimesDialog(BuildContext context, Workout workout) {
    return showAdjustTimesDialog(
      context,
      start: workout.start.toLocal(),
      end: workout.end?.toLocal(),
      onSave: (start, end) async {
        final startChanged = start != workout.start.toLocal();
        final endChanged = end != workout.end?.toLocal();
        if (!startChanged && !endChanged) return;

        final patched = await Workouts.of(context).editWorkoutTimes(
          workout.id,
          start: startChanged ? start.toUtc() : null,
          end: endChanged ? end?.toUtc() : null,
        );
        if (patched != null && mounted) {
          _notifier.setTimes(start: patched.start, end: patched.end);
        }
      },
    );
  }

  Future<void> _attachImage(BuildContext context, Future<LocalImage?> Function() getImage, Workout workout) async {
    final workouts = Workouts.of(context);
    final localImage = await getImage();
    if (localImage != null) {
      final remoteImage = await workouts.attachImageToWorkout(workout, localImage);
      if (remoteImage != null) {
        _notifier.attachImage(remoteImage);
      }
    }
  }
}

class _WorkoutNotifier with ChangeNotifier {
  final Workout workout;

  bool _hasChanged = false;

  bool get hasChanged => _hasChanged;

  new(this.workout);

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

  /// Reflects times that were just persisted via PATCH back onto the local copy.
  /// Notifies without flipping [hasChanged] — the change is already saved, so it
  /// must not arm the "discard changes?" guard or require another Save.
  void setTimes({DateTime? start, DateTime? end}) {
    if (start != null) workout.start = start;
    if (end != null) workout.end = end;
    super.notifyListeners();
  }

  void attachImage(WorkoutImage image) {
    workout.images?[image.id] = image;
    notifyListeners();
  }

  void detachImageFromWorkout(WorkoutImage image) {
    workout.images?.remove(image.id);
    notifyListeners();
  }

  @override
  void notifyListeners() {
    _hasChanged = true;
    super.notifyListeners();
  }
}

enum _WorkoutEditOption { editImage, editName, editTimes }

/// Linkified date + duration under the workout title. Tapping anywhere opens the
/// "Adjust Start/End Time" dialog. Mirrors the history list-item header, but the
/// whole block is a tappable affordance for editing the times.
class _WorkoutTimesSummary extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const new({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final muted = textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final date = DateFormat.yMMMd(L.of(context).localeName).format(workout.start.toLocal());

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const .fromLTRB(16, 4, 16, 4),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                Text(date, style: muted),
              ],
            ),
            if (workout.duration case Duration elapsed)
              Row(
                spacing: 8,
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                  Text(elapsed.formatted(context), style: muted),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
