part of 'workout_detail.dart';

const _dismissThreshold = .5;

/// A dismissible interactive widget that represent a single exercise set.
/// Allows to store and update the measurements of the set.
class _ExerciseSetItem extends StatefulWidget {
  final int index;

  /// What the set shows: its place among the exercise's plain sets, which a
  /// warm-up, drop or failure set before it does not take (#151).
  final int number;
  final ExerciseSet set;
  final WorkoutExercise exercise;
  final void Function(WorkoutExercise, ExerciseSet) onRemoveSet;
  final void Function(WorkoutExercise, ExerciseSet)? onSetDone;
  final bool isLocked;
  final Map<String, dynamic>? previousValue;
  final void Function(ExerciseSet, SetType)? onSetType;

  /// Rates the set from its number's popup (#234); null where sets are not
  /// rated.
  final void Function(ExerciseSet, double?)? onSetRpe;

  const new({
    required this.set,
    required this.index,
    required this.number,
    this.onSetType,
    this.onSetRpe,
    required this.exercise,
    required this.onRemoveSet,
    this.onSetDone,
    required this.isLocked,
    this.previousValue,
  });

  @override
  State<_ExerciseSetItem> createState() => _ExerciseSetItemState();
}

class _ExerciseSetItemState extends State<_ExerciseSetItem>
    with HasHaptic<_ExerciseSetItem>, AfterLayoutMixin<_ExerciseSetItem> {
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
  final _hasWeightError = ValueNotifier<bool>(false);
  final _hasDistanceError = ValueNotifier<bool>(false);
  final _hasDurationError = ValueNotifier<bool>(false);
  final _hasRepsError = ValueNotifier<bool>(false);
  final _hasCrossedDismissThreshold = ValueNotifier<bool>(false);
  bool _hasBuzzedOnDismiss = false;

  late L l;
  late Workouts workouts;

  /// Per-exercise unit override for this set's exercise, or null to fall back to
  /// the global weight/distance setting. Single source of truth for both input
  /// parsing and display so they never disagree.
  MeasurementUnit? get _unitOverride => Exercises.of(context).unitFor(widget.exercise.exercise.id);

  @override
  void initState() {
    super.initState();

    _weightController.addListener(_weightListener);
    _repsController.addListener(_repsListener);
    _distanceController.addListener(_distanceListener);
    _durationController.addListener(_durationListener);
  }

  /// The set's rating, as its last value cell shows it; null while it has
  /// none or the feature is off.
  String? _rpeBadge(BuildContext context) {
    if (!Preferences.watch(context).isOn(.rpe)) return null;
    return switch (set.rpe) {
      double rpe => L.of(context).rpeBadge(_rpeText(context, rpe)),
      null => null,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    l = L.of(context);
    final current = Workouts.of(context);
    if (!identical(current, _listened)) {
      _listened?.removeListener(_syncFromSet);
      _listened = current..addListener(_syncFromSet);
    }
    workouts = current;
  }

  /// The [Workouts] [_syncFromSet] listens to.
  Workouts? _listened;

  /// Brings the fields in line with the set when its values change under this
  /// row — ticked from the watch with the numbers shown there (#183). The
  /// fields are read into once, at first layout; without this they would go
  /// on showing the old values, and the next edit would write them back.
  ///
  /// A field being typed into is left alone. The write is silent: each field's
  /// listener stores what it holds, and a round trip through display rounding
  /// would nudge the stored value (60 kg shown as 132.3 lb comes back 60.01).
  void _syncFromSet() {
    if (!mounted) return;
    final prefs = Preferences.of(context);
    _syncField(_weightController, _weightFocus, _weightListener, switch (set.weight) {
      double weight => prefs.weight(weight, unit: _unitOverride),
      null => null,
    });
    _syncField(_repsController, _repsFocus, _repsListener, set.reps?.toString());
    // and a column filled from its header (#225), cardio's included
    _syncField(_distanceController, _distanceFocus, _distanceListener, switch (set.distance) {
      double distance => prefs.distance(distance, unit: _unitOverride),
      null => null,
    });
    _syncField(_durationController, _durationFocus, _durationListener, set.duration?.toDuration());
  }

  void _syncField(TextEditingController field, FocusNode focus, VoidCallback listener, String? shown) {
    if (shown == null || focus.hasFocus || field.text == shown) return;
    // the same number written differently ("60" for "60.0") is no change; a
    // duration ("3:00") is no number, and goes by its text above
    if (double.tryParse(field.text) case double now when now == double.tryParse(shown)) return;
    field
      ..removeListener(listener)
      ..text = shown
      ..addListener(listener);
  }

  @override
  void dispose() {
    _listened?.removeListener(_syncFromSet);
    _weightFocus.dispose();
    _repsFocus.dispose();
    _distanceFocus.dispose();
    _durationFocus.dispose();
    _hasRepsError.dispose();
    _hasWeightError.dispose();
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
        :onTertiaryContainer,
        :surfaceContainerHighest,
        :onSurfaceVariant,
        :primary,
        :error,
        :onError,
      ),
      :scaffoldBackgroundColor,
    ) = Theme.of(
      context,
    );
    final L(:deleteSet) = L.of(context);
    // Values sit on the quiet fill whether done or not — the check button
    // alone wears the accent, so a finished workout doesn't read as a wall
    // of accent pills with ink drowning on them.
    final fill = surfaceContainerHighest;

    // builds the background for the dismissed set
    // based on the direction of the swipe
    Widget dismissBackground({Alignment? alignment}) {
      return ValueListenableBuilder<bool>(
        valueListenable: _hasCrossedDismissThreshold,
        builder: (_, hasCrossed, _) {
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

    final prefs = Preferences.watch(context);

    return Dismissible(
      background: dismissBackground(alignment: Alignment.centerLeft),
      secondaryBackground: dismissBackground(alignment: Alignment.centerRight),
      dismissThresholds: const {DismissDirection.horizontal: _dismissThreshold},
      onDismissed: (_) {
        _hasBuzzedOnDismiss = false;
        widget.onRemoveSet(exercise, set);
      },
      onUpdate: _onSwipe,
      key: ValueKey<String>('_ExerciseSetItem.${set.id}'),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                _SetTypeButton(
                  key: WorkoutDetailKeys.setTypeFor(exercise.exercise.id, widget.index),
                  set: set,
                  number: widget.number,
                  fill: fill,
                  onSetType: widget.onSetType,
                  onSetRpe: widget.onSetRpe,
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: switch (widget.previousValue) {
                      // only a previous that shows real values gets the tappable
                      // pill — a legacy row missing its category's fields renders
                      // a bare dash, same as no previous at all
                      Map<String, dynamic> m when PreviousSet.represents(exercise.exercise, m) => PrimaryButton.shrunk(
                        backgroundColor: scaffoldBackgroundColor,
                        margin: const EdgeInsets.all(4),
                        child: PreviousSet(
                          previousValue: m,
                          exercise: exercise.exercise,
                          prefs: prefs,
                        ),
                        onPressed: () {
                          buzz();
                          switch (exercise.exercise.category) {
                            case .weightedBodyWeight:
                            case .assistedBodyWeight:
                            case .machine:
                            case .dumbbell:
                            case .barbell:
                              switch (m) {
                                case {'weight': num weight, 'reps': int reps}:
                                  _weightController.text = prefs.weight(weight, unit: _unitOverride);
                                  _repsController.text = '$reps';
                              }
                            case .repsOnly:
                              switch (m) {
                                case {'reps': int reps}:
                                  _repsController.text = '$reps';
                              }
                            case .cardio:
                              switch (m) {
                                case {'duration': num duration, 'distance': num distance}:
                                  _durationController.text = duration.toInt().toDuration();
                                  _distanceController.text = prefs.distance(distance, unit: _unitOverride);
                              }
                            case .duration:
                              switch (m) {
                                case {'duration': num duration}:
                                  _durationController.text = duration.toInt().toDuration();
                              }
                          }
                        },
                      ),
                      _ => const Text(_emptyValue),
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    children: _buttons(fill),
                  ),
                ),
                SizedBox(
                  width: _fixedColumnWidth,
                  height: _fixedButtonHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: PrimaryButton.shrunk(
                      key: WorkoutDetailKeys.doneFor(exercise.exercise.id, widget.index),
                      backgroundColor: switch (set.isCompleted) {
                        true => tertiaryContainer,
                        false => fill,
                      },
                      margin: EdgeInsets.zero,
                      onPressed: () {
                        if (!widget.isLocked) {
                          if (widget.onSetDone != null) {
                            widget.onSetDone?.call(exercise, set);
                          } else {
                            switch (_timing) {
                              // the clock runs on with the dialog away; ■ brings it back
                              case true:
                                _openStopwatch();
                              case false:
                                _onDone(context);
                            }
                          }
                        }
                      },
                      child: Center(
                        child: Opacity(
                          opacity: widget.isLocked ? .5 : 1,
                          child: ListenableBuilder(
                            listenable: workouts.stopwatch,
                            builder: (context, _) {
                              return switch (_timing) {
                                true => Semantics(
                                  label: L.of(context).showSetStopwatch,
                                  child: Icon(Icons.stop_rounded, size: 18, color: primary),
                                ),
                                false => Icon(
                                  Icons.done,
                                  size: 18,
                                  color: switch (set.isCompleted) {
                                    true => onTertiaryContainer,
                                    false => onSurfaceVariant,
                                  },
                                ),
                              };
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // in the row's own padding, so a running set keeps its height
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            child: ListenableBuilder(
              listenable: workouts.stopwatch,
              builder: (context, _) {
                final stopwatch = workouts.stopwatch;
                return switch (_timing) {
                  true => ValueListenableBuilder<int>(
                    valueListenable: stopwatch.seconds,
                    builder: (_, seconds, _) {
                      return _StopwatchLine(
                        seconds: seconds,
                        target: set.duration,
                        paused: stopwatch.isPaused,
                        // the row's bottom padding, whole
                        thickness: 4,
                      );
                    },
                  ),
                  false => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _initTextControllers(context);
  }

  List<Widget> _buttons(Color color) {
    switch (set.category) {
      case .weightedBodyWeight:
      case .assistedBodyWeight:
      case .barbell:
      case .dumbbell:
      case .machine:
        return [
          Expanded(
            child: _TextFieldButton(
              key: WorkoutDetailKeys.weightFor(exercise.exercise.id, widget.index),
              focusNode: _weightFocus,
              isSetCompleted: set.isCompleted,
              controller: _weightController,
              color: color,
              errorState: _hasWeightError,
              formatters: _floatingPointFormatters,
              semanticLabel: L.of(context).weightUnit,
            ),
          ),
          Expanded(
            child: _TextFieldButton(
              key: WorkoutDetailKeys.repsFor(exercise.exercise.id, widget.index),
              isSetCompleted: set.isCompleted,
              focusNode: _repsFocus,
              controller: _repsController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasRepsError,
              formatters: _integerFormatters,
              semanticLabel: L.of(context).reps,
              badge: _rpeBadge(context),
            ),
          ),
        ];
      case .repsOnly:
        return [
          Expanded(
            child: _TextFieldButton(
              isSetCompleted: set.isCompleted,
              focusNode: _repsFocus,
              controller: _repsController,
              color: color,
              keyboardType: TextInputType.number,
              errorState: _hasRepsError,
              formatters: _integerFormatters,
              semanticLabel: L.of(context).reps,
              badge: _rpeBadge(context),
            ),
          ),
        ];
      case .duration:
        return [
          Expanded(
            child: _durationCell(color),
          ),
        ];
      case .cardio:
        return [
          Expanded(
            child: Selector<Preferences, MeasurementUnit>(
              selector: (_, provider) => provider.distanceUnit,
              builder: (context, unit, _) {
                final raw = set.distance;
                if (raw != null) {
                  final rounded = Preferences.of(context).distance(raw, unit: _unitOverride ?? unit);

                  // cannot update during build
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) {
                      if (_distanceController.text != rounded) {
                        _distanceController.text = rounded;
                      }
                    },
                  );
                }
                return _TextFieldButton(
                  isSetCompleted: set.isCompleted,
                  focusNode: _distanceFocus,
                  controller: _distanceController,
                  color: color,
                  keyboardType: TextInputType.number,
                  errorState: _hasDistanceError,
                  formatters: _floatingPointFormatters,
                  semanticLabel: L.of(context).distanceUnit,
                );
              },
            ),
          ),
          Expanded(
            child: _durationCell(color),
          ),
        ];
    }
  }

  Widget _durationCell(Color color) {
    return ListenableBuilder(
      listenable: workouts.stopwatch,
      builder: (context, _) => _TextFieldButton(
        isSetCompleted: set.isCompleted,
        focusNode: _durationFocus,
        controller: _durationController,
        color: color,
        keyboardType: TextInputType.number,
        errorState: _hasDurationError,
        formatters: [TimeFormatter()],
        semanticLabel: L.of(context).duration,
        badge: _rpeBadge(context),
        running: switch (_timing) {
          true => workouts.stopwatch.seconds,
          false => null,
        },
        paused: workouts.stopwatch.isPaused,
        onRunning: _openStopwatch,
        onStopwatch: switch (_canStartStopwatch) {
          true => _startStopwatch,
          false => null,
        },
        stopwatchLabel: L.of(context).startSetStopwatch,
      ),
    );
  }

  /// The set stopwatch is on and this row is in the active workout, where it
  /// can run (#171); never in a template or the history editor.
  bool get _stopwatchOn {
    // the row watches Preferences in build; this is also read from a tap
    return Preferences.of(context).isOn(.setStopwatch) &&
        widget.onSetDone == null &&
        !widget.isLocked &&
        switch (set.category) {
          .duration || .cardio => true,
          _ => false,
        };
  }

  /// This set's stopwatch is running or paused.
  bool get _timing => _stopwatchOn && workouts.stopwatch.isTiming(set);

  /// A ▶ in the time cell: any timed set not done yet, whatever it holds — a
  /// copied or typed time is the target the stopwatch fills toward — while no
  /// other set is being timed.
  bool get _canStartStopwatch => _stopwatchOn && !set.isCompleted && !workouts.stopwatch.isRunning;

  void _startStopwatch() {
    final workout = workouts.activeWorkout;
    if (workout == null) return;
    _durationFocus.unfocus();
    // a refused tick's red is moot once the clock is running
    _hasDurationError.value = false;
    Alarms.of(context).stopActiveExerciseTimer();
    workouts.stopwatch.start(workout, set);
    _openStopwatch();
  }

  void _openStopwatch() {
    _showSetStopwatch(
      context,
      title: '${exercise.exercise.name} · ${L.of(context).ongoingWorkoutStopwatch(widget.number)}',
      target: set.duration,
      onDone: _stopStopwatch,
    );
  }

  Future<void> _stopStopwatch() async {
    final seconds = workouts.stopwatch.stop();
    await workouts.editSet(set, duration: seconds);
    if (!mounted) return;
    _hasDurationError.value = seconds <= 0;
    _durationController
      ..removeListener(_durationListener)
      ..text = seconds.toDuration()
      ..addListener(_durationListener);
    if (set.canBeCompleted) {
      await _onDone(context);
    } else if (set.category == .cardio) {
      _distanceFocus.requestFocus();
    }
  }

  /// The duration field as seconds for a tick: an empty or zero time is an
  /// error, as an empty reps field is, rather than a set logged at 0:00.
  int _timedSeconds() {
    return switch (_parseDuration()) {
      > 0 && final seconds => seconds,
      _ => throw const FormatException('no duration'),
    };
  }

  Future<void> _onDone(BuildContext context) async {
    final workouts = Workouts.of(context);
    if (set.isCompleted) {
      return workouts.markSetAsIncomplete(exercise, set);
    }

    try {
      switch (set.category) {
        case .weightedBodyWeight:
          _setMeasurements(
            weight: double.tryParse(_weightController.text), // we'll allow null for this
            reps: int.parse(_repsController.text),
          );
          _hasWeightError.value = false;
          _hasRepsError.value = false;
        case .assistedBodyWeight:
        case .machine:
        case .dumbbell:
        case .barbell:
          _setMeasurements(
            weight: double.parse(_weightController.text),
            reps: int.parse(_repsController.text),
          );
          _hasWeightError.value = false;
          _hasRepsError.value = false;
        case .repsOnly:
          _setMeasurements(
            reps: int.parse(_repsController.text),
          );
          _hasRepsError.value = false;
        case .cardio:
          final seconds = _timedSeconds();

          _setMeasurements(
            distance: double.parse(_distanceController.text),
            duration: seconds,
          );
          _hasDurationError.value = false;
          _hasDistanceError.value = false;
          _durationController.text = seconds.toDuration();
        case .duration:
          final seconds = _timedSeconds();
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
      _hasWeightError.value = !weightCorrect;
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
    final timer = timers[exercise.exercise.id];

    if (timer == null) return;

    return showCountdownDialog(
      context,
      timer,
      exerciseId: exercise.id,
      scheduleNotification: _scheduleNotification,
    );
  }

  Future<void> _scheduleNotification(DateTime when) => scheduleRestNotification(context, exercise, when);

  void _initTextControllers(BuildContext context) {
    final prefs = Preferences.of(context);
    var ExerciseSet(:reps, :weight, :distance, :duration) = set;

    if (weight != null) {
      _weightController.text = prefs.weight(weight, unit: _unitOverride);
    }

    if (reps != null) {
      _repsController.text = reps.toString();
    }

    if (distance != null) {
      _distanceController.text = prefs.distance(distance, unit: _unitOverride);
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
      [String s] => _parse(s),
      [String m, String s] => _parse(m) * 60 + _parse(s),
      [String h, String m, String s] => _parse(h) * 3600 + _parse(m) * 60 + _parse(s),
      _ => throw const FormatException(),
    };
  }

  static int _parse(String v) => int.tryParse(v) ?? 0;

  void _setMeasurements({double? weight, int? reps, int? duration, double? distance}) {
    if (!context.mounted) return;
    final Preferences(:distanceUnit, :weightUnit) = Preferences.of(context);
    final override = _unitOverride;

    // the user typed this, as opposed to a template having prescribed it —
    // `Workouts` needs the difference to know what a finish may keep
    Workouts.of(context).markEdited(set);

    // we're storing in metric, converting from the exercise's effective unit
    set.setMeasurements(
      duration: duration,
      weight: switch (override ?? weightUnit) {
        .imperial => weight?.asKilograms,
        .metric => weight,
      },
      reps: reps,
      distance: switch (override ?? distanceUnit) {
        .imperial => distance?.asKilometers,
        .metric => distance,
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
    if (this < 60) return '00:${_pad(this)}';
    final minutes = (this ~/ 60) % 60;
    final hours = this ~/ 3600;
    final seconds = this % 60;

    if (hours > 0) {
      return '$hours:${_pad(minutes)}:${_pad(seconds)}';
    }
    return '$minutes:${_pad(seconds)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
