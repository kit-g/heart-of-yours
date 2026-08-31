part of 'workout_detail.dart';

class _WorkoutExerciseItem extends StatelessWidget with HasHaptic<_WorkoutExerciseItem> {
  final int index;
  final String copy;
  final WorkoutExercise exercise;
  final void Function(WorkoutExercise) onAddSet;
  final void Function(WorkoutExercise, ExerciseSet) onRemoveSet;
  final void Function(WorkoutExercise, ExerciseSet)? onSetDone;
  final void Function(WorkoutExercise) onRemoveExercise;
  final void Function(WorkoutExercise dragged, WorkoutExercise current) onSwapExercise;
  final String firstColumnCopy;
  final String secondColumnCopy;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final ValueNotifier<WorkoutExercise?> dragState;
  final ValueNotifier<WorkoutExercise?> currentlyHoveredItem;
  final bool allowCompleting;
  final void Function(Exercise) onTapExercise;

  const new({
    required this.index,
    required this.exercise,
    required this.onAddSet,
    required this.onRemoveSet,
    this.onSetDone,
    required this.onRemoveExercise,
    required this.onSwapExercise,
    required this.copy,
    required this.firstColumnCopy,
    required this.secondColumnCopy,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.dragState,
    required this.currentlyHoveredItem,
    required this.allowCompleting,
    required this.onTapExercise,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return DragTarget<WorkoutExercise>(
      key: ValueKey<String>('_WorkoutExerciseItem.${exercise.id}'),
      onWillAcceptWithDetails: (details) {
        // only fire when the drag is dropped on any other exercise
        return exercise != details.data;
      },
      onAcceptWithDetails: (details) {
        currentlyHoveredItem.value = null;
        onSwapExercise(details.data, exercise);
      },
      onMove: (_) {
        currentlyHoveredItem.value = exercise;
      },
      builder: (_, candidates, rejects) {
        final previous = PreviousExercises.watch(context);
        return ValueListenableBuilder<WorkoutExercise?>(
          valueListenable: dragState,
          builder: (_, draggedExercise, _) {
            final header = Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 4),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => onTapExercise(exercise.exercise),
                    child: Text(
                      exercise.exercise.name,
                      style: textTheme.titleMedium,
                    ),
                  ),
                  Row(
                    children: [
                      Selector<Timers, int?>(
                        selector: (_, provider) => provider[exercise.exercise.id],
                        builder: (_, timer, _) {
                          return Selector<Alarms, (ValueNotifier<int>?, num?, String?)>(
                            selector: (_, provider) => (
                              provider.remainsInActiveExercise,
                              provider.activeExerciseTotal,
                              provider.activeExerciseId,
                            ),
                            builder: (_, alarm, _) {
                              return switch ((timer, alarm)) {
                                (int timer, _) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Stack(
                                    alignment: .center,
                                    children: [
                                      // the one running countdown, drawn only on
                                      // the exercise it belongs to
                                      if (alarm case (ValueNotifier<int> counter, num total, String owner)
                                          when owner == exercise.id)
                                        SizedBox(
                                          height: 32,
                                          width: 32,
                                          child: ValueListenableBuilder<int>(
                                            valueListenable: counter,
                                            builder: (_, remains, _) {
                                              return CustomPaint(
                                                painter: CircularTimerPainter(
                                                  progress: remains / total,
                                                  strokeColor: colorScheme.primary,
                                                  backgroundColor: colorScheme.inversePrimary.withValues(alpha: .3),
                                                  strokeWidth: 3,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      IconButton(
                                        visualDensity: const VisualDensity(vertical: 0, horizontal: -2),
                                        icon: const Icon(Icons.timer_outlined),
                                        onPressed: () {
                                          // behaves differently
                                          switch (alarm) {
                                            // this exercise's countdown is running, show it
                                            case (ValueNotifier<int> remains, _, String owner)
                                                when owner == exercise.id:
                                              showCountdownDialog(
                                                context,
                                                remains.value,
                                                exerciseId: exercise.id,
                                                scheduleNotification: (_) {},
                                              );
                                            // no countdown of its own, show the rest time picker
                                            default:
                                              _selectRestTime(context, initialValue: timer);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                (_, _) => const SizedBox.shrink(),
                              };
                            },
                          );
                        },
                      ),
                      MenuAnchor(
                        style: _menuStyle(),
                        builder: (context, controller, _) {
                          return IconButton(
                            key: WorkoutDetailKeys.exerciseOptionsFor(exercise.exercise.id),
                            tooltip: L.of(context).exerciseOptions,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity(vertical: 0, horizontal: -2),
                            ),
                            icon: const Icon(Icons.more_horiz),
                            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                          );
                        },
                        menuChildren: [
                          _exerciseOptionButton(context, .inspectExercise, textTheme, colorScheme),
                          _exerciseOptionButton(context, .autoRestTimer, textTheme, colorScheme),
                          if (_showsUnitOption) _unitSubmenu(context, textTheme),
                          _exerciseOptionButton(context, .remove, textTheme, colorScheme),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );

            return AnimatedSize(
              curve: Curves.easeInOut,
              // Collapsing every row to its header is what makes a long workout
              // droppable at all, but animating that collapse slides all the
              // drop targets around for 400ms under a pointer that is already
              // down. So the collapse is instant and only the expansion after
              // the drop animates.
              duration: switch (draggedExercise) {
                null => const Duration(milliseconds: 400),
                _ => Duration.zero,
              },
              child: switch (draggedExercise) {
                null => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [
                      LongPressDraggable<WorkoutExercise>(
                        delay: const Duration(milliseconds: 200),
                        data: exercise,
                        onDragStarted: onDragStarted,
                        onDragEnd: (_) => onDragEnded(),
                        onDragCompleted: onDragEnded,
                        onDraggableCanceled: (_, _) => onDragEnded(),
                        feedback: _Feedback(
                          exercise: exercise.exercise.name,
                          textTheme: textTheme,
                        ),
                        maxSimultaneousDrags: 1,
                        child: header,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: _fixedColumnWidth,
                              child: Center(child: Text(firstColumnCopy)),
                            ),
                            Expanded(
                              flex: 3,
                              child: Center(child: Text(secondColumnCopy)),
                            ),
                            ..._buttonsHeader(context),
                            SizedBox(
                              width: _fixedColumnWidth,
                              child: Center(
                                child: Icon(
                                  allowCompleting ? Icons.done : Icons.lock_outline_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...exercise.indexed.map(
                        (set) {
                          return _ExerciseSetItem(
                            index: set.$1 + 1,
                            set: set.$2,
                            exercise: exercise,
                            onRemoveSet: onRemoveSet,
                            isLocked: !allowCompleting,
                            onSetDone: onSetDone,
                            previousValue: previous.at(exercise.exercise.id, set.$1),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: PrimaryButton.wide(
                          key: WorkoutDetailKeys.addSet,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 8,
                              children: [
                                const Icon(
                                  Icons.add,
                                  size: 18,
                                ),
                                Text(copy),
                              ],
                            ),
                          ),
                          onPressed: () => onAddSet(exercise),
                        ),
                      ),
                    ],
                  ),
                ),
                // the dragged row holds its slot as a dimmed placeholder — taking
                // it out of the list shifts every target below it mid-drag, and
                // it is the row directly under the pointer
                WorkoutExercise e when e == exercise => Opacity(opacity: .4, child: header),
                _ => header,
              },
            );
          },
        );
      },
    );
  }

  List<Widget> _buttonsHeader(BuildContext context) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final override = Exercises.watch(context).unitFor(exercise.exercise.id);

    String weightUnit() {
      return switch (override ?? prefs.weightUnit) {
        .metric => l.kg,
        .imperial => l.lbs,
      };
    }

    String distanceUnit() {
      return switch (override ?? prefs.distanceUnit) {
        .metric => l.km,
        .imperial => l.mile,
      };
    }

    switch (exercise.exercise.category) {
      case .machine:
      case .dumbbell:
      case .barbell:
        return [
          Expanded(
            child: Center(
              child: Text(
                weightUnit(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(l.reps),
            ),
          ),
        ];
      case .weightedBodyWeight:
        return [
          Expanded(
            child: Center(child: Text('+${weightUnit()}')),
          ),
          Expanded(
            child: Center(
              child: Text(l.reps),
            ),
          ),
        ];
      case .assistedBodyWeight:
        return [
          Expanded(
            child: Center(child: Text('-${weightUnit()}')),
          ),
          Expanded(
            child: Center(
              child: Text(l.reps),
            ),
          ),
        ];
      case .repsOnly:
        return [
          Expanded(
            flex: 2,
            child: Center(
              child: Text(l.reps),
            ),
          ),
        ];
      case .cardio:
        return [
          Expanded(
            child: Center(
              child: Text(
                distanceUnit(),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(l.time),
            ),
          ),
        ];
      case .duration:
        return [
          Expanded(
            flex: 2,
            child: Center(
              child: Text(l.time),
            ),
          ),
        ];
    }
  }

  String _exerciseOptionCopy(BuildContext context, _ExerciseOption option) {
    return switch (option) {
      .autoRestTimer => L.of(context).restTimer,
      .remove => L.of(context).removeExercise,
      .inspectExercise => L.of(context).aboutExercise,
    };
  }

  /// Whether the per-exercise unit submenu applies (weight- or distance-based
  /// exercises only — duration/reps have no unit).
  bool get _showsUnitOption {
    return switch (exercise.exercise.category) {
      .duration || .repsOnly => false,
      _ => true,
    };
  }

  Widget _exerciseOptionButton(
    BuildContext context,
    _ExerciseOption option,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return MenuItemButton(
      leadingIcon: _exerciseOptionIcon(option, colorScheme),
      onPressed: () => _onTapExerciseOption(context, option),
      child: Text(
        _exerciseOptionCopy(context, option),
        style: _exerciseOptionStyle(textTheme, colorScheme, option),
      ),
    );
  }

  /// Cascading "Weight/Distance unit → Imperial/Metric" submenu. Writes through
  /// [Exercises.setUnit] (per-user) and check-marks the active selection.
  Widget _unitSubmenu(BuildContext context, TextTheme textTheme) {
    final l = L.of(context);
    final prefs = Preferences.of(context);
    final exercises = Exercises.of(context);
    final isCardio = exercise.exercise.category == Category.cardio;
    // fall back to the global setting for this dimension when there's no
    // explicit per-exercise override, so the menu always check-marks something.
    final current = exercises.unitFor(exercise.exercise.id) ?? (isCardio ? prefs.distanceUnit : prefs.weightUnit);
    final label = isCardio ? l.distanceUnitLabel : l.weightUnitLabel;
    return SubmenuButton(
      menuStyle: _menuStyle(),
      leadingIcon: const Icon(Icons.straighten),
      menuChildren: [
        for (final unit in MeasurementUnit.values)
          MenuItemButton(
            leadingIcon: Icon(
              current == unit ? Icons.check : null,
              size: 18,
            ),
            onPressed: () {
              buzz();
              exercises.setUnit(exercise.exercise, unit);
            },
            child: Text(
              switch (unit) {
                .imperial => l.imperial,
                .metric => l.metric,
              },
              style: textTheme.titleSmall,
            ),
          ),
      ],
      child: Text(
        label,
        style: textTheme.titleSmall,
      ),
    );
  }

  MenuStyle _menuStyle() {
    return const MenuStyle(
      padding: WidgetStatePropertyAll(.zero),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: .all(.circular(8)))),
    );
  }

  TextStyle? _exerciseOptionStyle(TextTheme theme, ColorScheme scheme, _ExerciseOption option) {
    return switch (option) {
      .remove => theme.titleSmall?.copyWith(color: scheme.error),
      _ => theme.titleSmall,
    };
  }

  Widget _exerciseOptionIcon(_ExerciseOption option, ColorScheme scheme) {
    return switch (option) {
      .remove => Icon(Icons.close, color: scheme.error),
      .autoRestTimer => const Icon(Icons.timer_outlined),
      .inspectExercise => const Icon(Icons.info_outline_rounded),
    };
  }

  Future<void> _onTapExerciseOption(BuildContext context, _ExerciseOption option) async {
    buzz();
    switch (option) {
      case .remove:
        return onRemoveExercise(exercise);
      case .autoRestTimer:
        return _selectRestTime(
          context,
          initialValue: Timers.of(context)[exercise.exercise.id],
        );
      case .inspectExercise:
        return onTapExercise(exercise.exercise);
    }
  }

  Future<void> _selectRestTime(BuildContext context, {int? initialValue}) async {
    // the timer is keyed by the exercise's id; its name is only copy here
    final id = exercise.exercise.id;
    final timers = Timers.of(context);
    final restInSeconds = await showDurationPicker(
      context,
      initialValue: initialValue,
      subtitle: L.of(context).forExercise(exercise.exercise.name),
    );

    switch (restInSeconds) {
      case 0: // special Cancel signal
        timers.remove(id);
      case int seconds when seconds > 0:
        timers.setRestTimer(id, seconds);
        // A rest timer is only useful if we may notify — ask now, the first
        // time one is set, rather than up front at launch.
        if (context.mounted) _ensureNotifications(context);
      default:
      // may return null on dialog dismiss, then no-op
    }
  }

  Future<void> _ensureNotifications(BuildContext context) async {
    final enabled = await ensureNotificationPermission(Theme.of(context).platform);
    if (enabled || !context.mounted) return;
    final L(:notificationsDisabledReminder, :settings) = L.of(context);
    remindNotificationsOff(context, message: notificationsDisabledReminder, settingsLabel: settings);
  }
}
