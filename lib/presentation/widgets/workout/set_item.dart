part of 'active_workout.dart';

const _dismissThreshold = .5;

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

class _ExerciseSetItemState extends State<_ExerciseSetItem> with HasHaptic<_ExerciseSetItem> {
  ExerciseSet get set => widget.set;

  WorkoutExercise get exercise => widget.exercise;

  final _weightFocus = FocusNode();
  final _weightController = TextEditingController();
  final _repsFocus = FocusNode();
  final _repsController = TextEditingController();
  final _hasWeighError = ValueNotifier<bool>(false);
  final _hasRepsError = ValueNotifier<bool>(false);
  final _hasCrossedDismissThreshold = ValueNotifier<bool>(false);
  bool _hasBuzzedOnDismiss = false;

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
    _hasCrossedDismissThreshold.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(
      :textTheme,
      colorScheme: ColorScheme(
        :tertiaryContainer,
        :outlineVariant,
        :error,
        :onError,
      ),
    ) = Theme.of(context);
    final L(:deleteSet) = L.of(context);
    final color = set.isCompleted ? tertiaryContainer : outlineVariant.withValues(alpha: .5);

    // builds the background for the dismissed set
    // based on the direction of the swipe
    Widget dismissBackground({Alignment? alignment}) {
      return ValueListenableBuilder<bool>(
        valueListenable: _hasCrossedDismissThreshold,
        builder: (_, hasCrossed, __) {
          return Container(
            color: error,
            child: AnimatedAlign(
              curve: Curves.easeOutCubic,
              duration: const Duration(milliseconds: 200),
              alignment: switch ((hasCrossed, alignment)) {
                // we're swiping right to left
                (true, Alignment(:double x)) when x > _dismissThreshold => Alignment.center,
                (false, Alignment(:double x)) when x > _dismissThreshold => Alignment.centerRight,
                // we're swiping left to right
                (true, Alignment(:double x)) when x < _dismissThreshold => Alignment.center,
                (false, Alignment(:double x)) when x < _dismissThreshold => Alignment.centerLeft,
                _ => Alignment.centerLeft,
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: PoppingText(
                  text: deleteSet,
                  style: textTheme.titleSmall?.copyWith(color: onError),
                  trigger: _hasCrossedDismissThreshold,
                ),
              ),
            ),
          );
        },
      );
    }

    return Dismissible(
      background: dismissBackground(alignment: Alignment.centerLeft),
      secondaryBackground: dismissBackground(alignment: Alignment.centerRight),
      dismissThresholds: const {DismissDirection.horizontal: _dismissThreshold},
      onDismissed: (_) {
        _hasBuzzedOnDismiss = false;
        Workouts.of(context).removeSet(exercise, set);
      },
      onUpdate: _onSwipe,
      key: ValueKey<String>(set.id),
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

  Future<void> _onDone(BuildContext context) async {
    final workouts = Workouts.of(context);
    if (set.isCompleted) {
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
        _startTimer(context);
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

  void _onSwipe(DismissUpdateDetails details) {
    switch (details.progress) {
      case > _dismissThreshold:
        if (!_hasBuzzedOnDismiss) {
          buzz();
          _hasBuzzedOnDismiss = true;
        }

        _hasCrossedDismissThreshold.value = true;
      default:
        if (_hasBuzzedOnDismiss) {
          _hasBuzzedOnDismiss = false;
        }
        _hasCrossedDismissThreshold.value = false;
    }
  }

  Future<void> _startTimer(BuildContext context) async {
    final timers = Timers.of(context);
    final timer = timers[exercise.exercise.name];

    if (timer == null) return;
    return showCountdownDialog(context, timer);
  }
}
