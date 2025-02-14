part of 'active_workout.dart';

const _dismissThreshold = .5;

/// A dismissible interactive widget that represent a single exercise set.
/// Allows to store and update the measurements of the set.
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
    _distanceController.addListener(_distanceListener);
    _durationController.addListener(_durationListener);
  }

  @override
  void dispose() {
    _weightFocus.dispose();
    _repsFocus.dispose();
    _distanceFocus.dispose();
    _durationFocus.dispose();
    _hasRepsError.dispose();
    _hasWeighError.dispose();
    _hasDistanceError.dispose();
    _hasDurationError.dispose();
    _hasCrossedDismissThreshold.dispose();

    _weightController
      ..removeListener(_weightListener)
      ..dispose();
    _repsController
      ..removeListener(_repsListener)
      ..dispose();
    _distanceController
      ..removeListener(_distanceListener)
      ..dispose();
    _durationController
      ..removeListener(_durationListener)
      ..dispose();

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
            child: Selector<Preferences, MeasurementUnit>(
              selector: (_, provider) => provider.weightUnit,
              builder: (_, unit, __) {
                double? weight = set.weight;

                if (weight != null) {
                  weight = switch (unit) {
                    MeasurementUnit.imperial => (weight.asPounds * 100).roundToDouble() / 100,
                    MeasurementUnit.metric => (weight * 100).roundToDouble() / 100,
                  };
                  final rounded = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(2);
                  _weightController.text = rounded;
                }

                return _TextFieldButton(
                  focusNode: _weightFocus,
                  set: set,
                  controller: _weightController,
                  color: color,
                  errorState: _hasWeighError,
                  formatters: _floatingPointFormatters,
                );
              },
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
              formatters: [TimeFormatter()],
            ),
          ),
        ];
      case Category.cardio:
        return [
          Expanded(
            child: Selector<Preferences, MeasurementUnit>(
              selector: (_, provider) => provider.distanceUnit,
              builder: (_, unit, __) {
                double? distance = set.distance;
                if (distance != null) {
                  distance = switch (unit) {
                    MeasurementUnit.imperial => distance.asMiles,
                    MeasurementUnit.metric => distance,
                  };
                  final rounded = distance % 1 == 0 ? distance.toInt().toString() : distance.toStringAsFixed(1);
                  _distanceController.text = rounded;
                }
                return _TextFieldButton(
                  set: set,
                  focusNode: _distanceFocus,
                  controller: _distanceController,
                  color: color,
                  keyboardType: TextInputType.number,
                  errorState: _hasDistanceError,
                  formatters: _floatingPointFormatters,
                );
              },
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
              formatters: [TimeFormatter()],
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
      switch (set.category) {
        case Category.weightedBodyWeight:
        case Category.assistedBodyWeight:
        case Category.machine:
        case Category.dumbbell:
        case Category.barbell:
          _setMeasurements(
            weight: double.parse(_weightController.text),
            reps: int.parse(_repsController.text),
          );
          _hasWeighError.value = false;
          _hasRepsError.value = false;
        case Category.repsOnly:
          _setMeasurements(
            reps: int.parse(_repsController.text),
          );
          _hasRepsError.value = false;
        case Category.cardio:
          final seconds = _parseDuration();

          _setMeasurements(
            distance: double.parse(_distanceController.text),
            duration: seconds,
          );
          _hasDurationError.value = false;
          _hasDistanceError.value = false;
          _durationController.text = seconds.toDuration();
        case Category.duration:
          final seconds = _parseDuration();
          _setMeasurements(duration: seconds);
          _hasDurationError.value = false;
          _durationController.text = seconds.toDuration();
      }

      if (set.canBeCompleted) {
        workouts.markSetAsComplete(exercise, set);
        _startTimer(context);
      }

      _repsFocus.unfocus();
      _weightFocus.unfocus();
      _distanceFocus.unfocus();
      _durationFocus.unfocus();
    } on FormatException {
      final repsCorrect = int.tryParse(_repsController.text) != null;
      final weightCorrect = double.tryParse(_weightController.text) != null;
      final distanceCorrect = double.tryParse(_distanceController.text) != null;
      final durationCorrect = _parseDuration() > 0;

      _hasRepsError.value = !repsCorrect;
      _hasWeighError.value = !weightCorrect;
      _hasDistanceError.value = !distanceCorrect;
      _hasDurationError.value = !durationCorrect;
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
    var ExerciseSet(:reps, :weight, :distance, :duration) = set;

    if (weight != null) {
      final rounded = weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);
      _weightController.text = rounded;
    }

    if (reps != null) {
      _repsController.text = reps.toString();
    }

    if (distance != null) {
      final rounded = distance % 1 == 0 ? distance.toInt().toString() : distance.toStringAsFixed(1);
      _distanceController.text = rounded;
    }

    if (duration != null) {
      _durationController.text = duration.toDuration();
    }
  }

  /// Parses the weight input from `_weightController` and updates the set's weight measurement.
  void _weightListener() {
    if (!context.mounted) return;
    bool hasChanged = false;
    if (double.tryParse(_weightController.text) case double weight when weight > 0) {
      _setMeasurements(weight: weight);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }

  /// Parses the reps input from `_repsController` and updates the set's reps measurement.
  void _repsListener() {
    if (!context.mounted) return;
    bool hasChanged = false;

    if (int.tryParse(_repsController.text) case int reps when reps > 0) {
      _setMeasurements(reps: reps);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }

  /// Parses the distance input from `_distanceController` and updates the set's distance.
  void _distanceListener() {
    if (!context.mounted) return;
    bool hasChanged = false;

    if (double.tryParse(_distanceController.text) case double distance when distance > 0) {
      _setMeasurements(distance: distance);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }

  /// Parses the duration input from `_durationController` and updates the set's duration.
  ///
  /// This function ensures that only valid numeric inputs are processed.
  ///
  /// Example inputs and their parsed values:
  /// ```dart
  /// "5"       -> 5 seconds
  /// "50"      -> 50 seconds
  /// "5:00"    -> 300 seconds (5 minutes)
  /// "50:00"   -> 3000 seconds (50 minutes)
  /// "5:00:00" -> 18000 seconds (5 hours)
  /// "3:33"    -> 213 seconds (3 minutes, 33 seconds)
  /// "01:02:03" -> 3723 seconds (1 hour, 2 minutes, 3 seconds)
  /// ```
  ///
  /// If the parsed duration is greater than 0, it updates the stored workout measurements.
  void _durationListener() {
    if (!context.mounted) return;
    bool hasChanged = false;

    final seconds = _parseDuration();

    if (seconds > 0) {
      set.setMeasurements(duration: seconds);
      hasChanged = true;
    }

    if (hasChanged) {
      Workouts.of(context).storeMeasurements(set);
    }
  }

  int _parseDuration() {
    return switch (_durationController.text.split(':').toList()) {
      [String s] => parse(s),
      [String m, String s] => parse(m) * 60 + parse(s),
      [String h, String m, String s] => parse(h) * 3600 + parse(m) * 60 + parse(s),
      _ => throw const FormatException(),
    };
  }

  static int parse(String v) => int.tryParse(v) ?? 0;

  void _setMeasurements({double? weight, int? reps, int? duration, double? distance}) {
    if (!context.mounted) return;
    final Preferences(:weightUnit, :distanceUnit) = Preferences.of(context);
    set.setMeasurements(
      duration: duration,
      weight: switch (weightUnit) {
        MeasurementUnit.imperial => weight?.asKilograms,
        MeasurementUnit.metric => weight,
      },
      reps: reps,
      distance: switch (distanceUnit) {
        MeasurementUnit.imperial => distance?.asKilometers,
        MeasurementUnit.metric => distance,
      },
    );
  }
}

extension on int {
  /// Converts a duration in seconds into a formatted string (`hh:mm:ss`, `mm:ss`, or `ss`).
  ///
  /// - If the duration is 3600 seconds or more, it returns `h:mm:ss`.
  /// - If the duration is 60 seconds or more, it returns `m:ss`.
  /// - Otherwise, it returns `s` (single number for seconds).
  ///
  /// Examples:
  /// ```dart
  /// 5.toDuration();      // "5"
  /// 50.toDuration();     // "50"
  /// 180.toDuration();    // "3:00"
  /// 3000.toDuration();   // "50:00"
  /// 18000.toDuration();  // "5:00:00"
  /// 3723.toDuration();   // "1:02:03"
  /// ```
  String toDuration() {
    if (this < 60) return "00:${_pad(this)}";
    final minutes = (this ~/ 60) % 60;
    final hours = this ~/ 3600;
    final seconds = this % 60;

    if (hours > 0) {
      return "$hours:${_pad(minutes)}:${_pad(seconds)}";
    }
    return "$minutes:${_pad(seconds)}";
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
