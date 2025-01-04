part of 'active_workout.dart';

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
  void initState() {
    super.initState();

    switch (set) {
      case WeightedSet(:int reps, :double weight):
      case AssistedSet(:int reps, :double weight):
        _weightController.text = weight.toString();
        _repsController.text = reps.toString();
      default:
    }
  }

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
