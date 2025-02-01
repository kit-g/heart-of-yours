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
  final _repsFocus = FocusNode();
  final _durationFocus = FocusNode();
  final _distanceFocus = FocusNode();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _hasWeighError = ValueNotifier<bool>(false);
  final _hasDistanceError = ValueNotifier<bool>(false);
  final _hasDurationError = ValueNotifier<bool>(false);
  final _hasRepsError = ValueNotifier<bool>(false);
  final _hasCrossedDismissThreshold = ValueNotifier<bool>(false);
  bool _hasBuzzedOnDismiss = false;

  @override
  void initState() {
    super.initState();

    _initTextControllers();

    _weightController.addListener(_weightListener);
    _repsController.addListener(_repsListener);
  }

  @override
  void dispose() {
    _weightFocus.dispose();
    _repsFocus.dispose();
    _distanceFocus.dispose();
    _durationFocus.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _hasRepsError.dispose();
    _hasWeighError.dispose();
    _hasDistanceError.dispose();
    _hasDurationError.dispose();
    _hasCrossedDismissThreshold.dispose();

    _weightController.removeListener(_weightListener);
    _repsController.removeListener(_repsListener);

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
            Expanded(
              flex: 3,
              child: Center(
                child: Text(set.category.name),
                // child: Text(_emptyValue), todo
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: _buttons(color),
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

  List<Widget> _buttons(Color color) {
    switch (set.category) {
      case Category.weightedBodyWeight:
      case Category.assistedBodyWeight:
      case Category.barbell:
      case Category.dumbbell:
      case Category.machine:
        return [
          Expanded(
            child: _TextFieldButton(
              focusNode: _weightFocus,
              set: set,
              controller: _weightController,
              color: color,
              errorState: _hasWeighError,
              formatters: _floatingPointFormatters,
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
              formatters: _integerFormatters,
            ),
          ),
        ];
      case Category.repsOnly:
        return [
          Expanded(
            child: _TextFieldButton(
              set: set,
              focusNode: _repsFocus,
              controller: _repsController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasRepsError,
              formatters: _integerFormatters,
            ),
          ),
        ];
      case Category.duration:
        return [
          Expanded(
            child: _TextFieldButton(
              set: set,
              focusNode: _durationFocus,
              controller: _durationController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasDurationError,
            ),
          ),
        ];
      case Category.cardio:
        return [
          Expanded(
            child: _TextFieldButton(
              set: set,
              focusNode: _distanceFocus,
              controller: _distanceController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasDistanceError,
              formatters: _floatingPointFormatters,
            ),
          ),
          Expanded(
            child: _TextFieldButton(
              set: set,
              focusNode: _durationFocus,
              controller: _durationController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasDurationError,
            ),
          ),
        ];
    }
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
    return showCountdownDialog(
      context,
      timer,
      onCountdown: () => _onCountdown(context),
    );
  }

  Future<void> _onCountdown(BuildContext context) {
    final L(:restComplete, :restCompleteBody, :weightedSetRepresentation, :lb) = L.of(context);
    final workouts = Workouts.of(context);
    final body = switch (workouts.nextIncomplete?.$2) {
      ExerciseSet(:double weight, :int reps) => weightedSetRepresentation(lb(weight.toInt()), reps),
      _ => null,
    };
    final nextExercise = workouts.nextIncomplete?.$1 ?? exercise;
    return showExerciseNotification(
      exerciseId: nextExercise.id,
      title: restComplete,
      subtitle: restCompleteBody(nextExercise.exercise.name),
      body: body,
    );
  }

  void _initTextControllers() {
    // todo
    switch (set) {
      case ExerciseSet(:int reps, :double weight):
        final rounded = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
        _weightController.text = rounded;
        _repsController.text = reps.toString();
      default:
    }
  }

  void _weightListener() {
    if (!context.mounted) return;
    bool hasChanged = false;
    if (double.tryParse(_weightController.text) case double weight when weight > 0) {
      set.setMeasurements(weight: weight);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }

  void _repsListener() {
    if (!context.mounted) return;
    bool hasChanged = false;

    if (int.tryParse(_repsController.text) case int reps when reps > 0) {
      set.setMeasurements(reps: reps);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }
}
