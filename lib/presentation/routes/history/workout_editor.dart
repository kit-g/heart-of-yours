part of 'history.dart';

class WorkoutEditor extends StatefulWidget {
  final Workout copy;

  const WorkoutEditor({super.key, required this.copy});

  @override
  State<WorkoutEditor> createState() => _WorkoutEditorState();
}

class _WorkoutEditorState extends State<WorkoutEditor> with HasHaptic<WorkoutEditor> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  late final _WorkoutNotifier _notifier;

  Workout get workout => _notifier.workout;

  @override
  void initState() {
    super.initState();

    _notifier = _WorkoutNotifier(widget.copy);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:scaffoldBackgroundColor, :colorScheme, :textTheme) = Theme.of(context);
    final L(:editWorkout, :save, :workoutName) = L.of(context);

    if ((_controller.text.isEmpty, workout.name) case (true, String name) when name.isNotEmpty) {
      _controller.text = name;
    }

    return ListenableBuilder(
      listenable: _notifier,
      builder: (_, __) {
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
                                    Workouts.of(context).saveWorkout(_notifier.workout);
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
                onAddExercises: (exercises) async {
                  for (var each in exercises.toList()) {
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
    ) = L.of(context);

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
        )
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
    ) = L.of(context);

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

  @override
  void notifyListeners() {
    _hasChanged = true;
    super.notifyListeners();
  }
}
