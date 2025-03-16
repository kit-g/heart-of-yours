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
        return Scaffold(
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
                              Workouts.of(context).saveWorkout(_notifier.workout);
                              Navigator.of(context).pop();
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
                    _notifier.workout.name = value.trim();
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
              onDragExercise: (exercise) {
                //
              },
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
        );
      },
    );
  }
}

class _WorkoutNotifier with ChangeNotifier {
  final Workout workout;

  _WorkoutNotifier(this.workout);

  void addSet(WorkoutExercise exercise) {
    final set = exercise.lastOrNull?.copy() ?? ExerciseSet(exercise.exercise);
    _forExercise(exercise, (each) => each.add(set));
  }

  void removeSet(WorkoutExercise exercise, ExerciseSet set) {
    _forExercise(
      exercise,
      (each) => each.remove(set),
    );
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

  void _forExercise(WorkoutExercise exercise, void Function(WorkoutExercise) action, {bool notifies = true}) {
    workout.where((each) => each == exercise).forEach(action);
    if (notifies) {
      notifyListeners();
    }
  }
}
