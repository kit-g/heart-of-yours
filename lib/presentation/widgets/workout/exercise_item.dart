part of 'workout_detail.dart';

class _WorkoutExerciseItem extends StatelessWidget with HasHaptic<_WorkoutExerciseItem> {
  final Future<void> Function(WorkoutExercise, String?)? onNoteChanged;
  final int index;
  final String copy;
  final WorkoutExercise exercise;
  final void Function(WorkoutExercise) onAddSet;
  final void Function(WorkoutExercise, ExerciseSet) onRemoveSet;
  final void Function(WorkoutExercise, ExerciseSet)? onSetDone;
  final void Function(ExerciseSet, SetType)? onSetType;
  final void Function(ExerciseSet, double?)? onSetRpe;
  final void Function(ExerciseSet, SetTarget?)? onSetTarget;
  final bool showsPlan;
  final ReplaceExercise? onReplaceExercise;
  final void Function(WorkoutExercise exercise, WorkoutExercise neighbour)? onGroup;
  final void Function(WorkoutExercise)? onLeaveGroup;

  /// The superset [exercise] is in (#159), or [exercise] alone.
  final List<WorkoutExercise> group;

  /// The exercises either side of [exercise] on the sheet, its candidates for
  /// a superset.
  final WorkoutExercise? before;
  final WorkoutExercise? after;
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
    this.onNoteChanged,
    required this.exercise,
    required this.onAddSet,
    required this.onRemoveSet,
    this.onSetDone,
    this.onSetType,
    this.onSetRpe,
    this.onSetTarget,
    this.showsPlan = false,
    this.onReplaceExercise,
    this.onGroup,
    this.onLeaveGroup,
    this.group = const [],
    this.before,
    this.after,
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
    final exercises = Exercises.watch(context);

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
                      Builder(
                        builder: (context) {
                          final timer = restFor(context, exercise, listen: true);
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
                                        tooltip: L.of(context).restTimer,
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
                          if (onNoteChanged != null &&
                              exercises.canPinNote &&
                              exercises.noteFor(exercise.exercise.id) != null)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.push_pin_outlined),
                              onPressed: () => _unpinNote(context),
                              child: Text(L.of(context).unpinExerciseNote, style: textTheme.titleSmall),
                            ),
                          if (onNoteChanged != null)
                            MenuItemButton(
                              leadingIcon: const Icon(Icons.edit_note_rounded),
                              onPressed: () => _editNote(context),
                              child: Text(switch (exercise.note) {
                                String _ => L.of(context).editExerciseNote,
                                null => L.of(context).addExerciseNote,
                              }, style: textTheme.titleSmall),
                            ),
                          if ((onReplaceExercise, _slot, exercise.isStarted) case (
                            final onReplace?,
                            final String pattern,
                            false,
                          ))
                            MenuItemButton(
                              key: WorkoutDetailKeys.swapExerciseFor(exercise.exercise.id),
                              leadingIcon: const Icon(Icons.swap_horiz_rounded),
                              onPressed: () => _replace(context, pattern, onReplace),
                              child: Text(L.of(context).swapExercise, style: textTheme.titleSmall),
                            ),
                          if ((onReplaceExercise, _slot, exercise.isStarted) case (
                            final onReplace?,
                            null,
                            false,
                          ))
                            MenuItemButton(
                              key: WorkoutDetailKeys.replaceExerciseFor(exercise.exercise.id),
                              leadingIcon: const Icon(Icons.find_replace_rounded),
                              onPressed: () => _replaceAny(context, onReplace),
                              child: Text(L.of(context).replaceExercise, style: textTheme.titleSmall),
                            ),
                          ..._groupOptions(context, textTheme),
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
                      if (showsPlan)
                        if (planLine(context, exercise, nameOf: (id) => exercises.lookup(id)?.name ?? '')
                            case final String line)
                          _PlanLine(line),
                      if (_slot case final String pattern)
                        _OpenSlot(
                          pattern: pattern,
                          exerciseId: exercise.exercise.id,
                          onSwap: switch ((onReplaceExercise, exercise.isStarted)) {
                            (final onReplace?, false) => () => _replace(context, pattern, onReplace),
                            _ => null,
                          },
                        ),
                      if (exercise.note case String note when note.isNotEmpty)
                        _ExerciseNote(
                          exercise: exercise,
                          onChanged: onNoteChanged,
                          onEdit: () => _editNote(context),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: _setColumnWidth,
                              child: _ColumnLabel(firstColumnCopy),
                            ),
                            Expanded(
                              flex: 3,
                              child: _ColumnLabel(secondColumnCopy),
                            ),
                            ..._buttonsHeader(context, previous),
                            SizedBox(
                              width: _fixedColumnWidth,
                              child: switch (allowCompleting) {
                                true => _ColumnHeader(
                                  key: WorkoutDetailKeys.tickAllFor(exercise.exercise.id),
                                  tooltip: switch (exercise.every((set) => set.isCompleted)) {
                                    true => L.of(context).untickAllSets,
                                    false => L.of(context).tickAllSets,
                                  },
                                  onTap: () => _tickAll(context),
                                  child: const Icon(Icons.done, size: 18),
                                ),
                                false => const Center(child: Icon(Icons.lock_outline_rounded, size: 18)),
                              },
                            ),
                          ],
                        ),
                      ),
                      ...exercise.indexed.map(
                        (set) {
                          return _ExerciseSetItem(
                            index: set.$1 + 1,
                            number: exercise.take(set.$1).where((each) => each.setType == .normal).length + 1,
                            set: set.$2,
                            onSetType: onSetType,
                            onSetRpe: onSetRpe,
                            onSetTarget: onSetTarget,
                            exercise: exercise,
                            onRemoveSet: onRemoveSet,
                            isLocked: !allowCompleting,
                            onSetDone: onSetDone,
                            previousValue: previous.matching(exercise, set.$1),
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

  /// Fills the open slot with another exercise of its [pattern] (#349): the
  /// picker greys the rest, and says why when one is tapped.
  Future<void> _replace(BuildContext context, String pattern, ReplaceExercise onReplace) async {
    final l = L.of(context);
    final takes = PatternFilter(pattern).label(l);
    final picked = await showSingleExercisePicker(
      context,
      except: exercise.exercise.id,
      refuses: (candidate) => switch (candidate.movement.groups.contains(pattern)) {
        true => null,
        false => l.swapOutsidePattern(takes, candidate.name),
      },
    );
    if (picked != null) await onReplace(exercise, picked, suggested: false);
  }

  /// Puts another exercise in this one's place (#354): the same movement
  /// pattern suggested first, nearest in load after, and only exercises whose
  /// sets can take these offered — the rest greyed, saying why when tapped.
  Future<void> _replaceAny(BuildContext context, ReplaceExercise onReplace) async {
    final l = L.of(context);
    final source = exercise.exercise;
    final suggested = replacementsInWorkout(context, source);
    final picked = await showSingleExercisePicker(
      context,
      except: source.id,
      suggested: suggested,
      refuses: (candidate) => switch (logsAlike(candidate, source)) {
        true => null,
        false => l.replaceIncompatible(candidate.name, source.name),
      },
    );
    if (picked != null) await onReplace(exercise, picked, suggested: suggested.contains(picked));
  }

  Future<void> _unpinNote(BuildContext context) async {
    try {
      await Exercises.of(context).setNote(exercise.exercise.id, null);
    } catch (_) {
      if (context.mounted) _noteError(context);
    }
  }

  Future<void> _editNote(BuildContext context) async {
    final onChanged = onNoteChanged;
    if (onChanged == null) return;
    final note = await showBrandedDialog<String>(
      context,
      title: Text(L.of(context).exerciseNote),
      content: _NoteEditor(initial: exercise.note),
    );
    if (note == null) return;
    try {
      await onChanged(exercise, note.isEmpty ? null : note);
    } catch (_) {
      if (context.mounted) _noteError(context);
    }
  }

  /// Fills [column] in every set not yet ticked, from its header (#225): see
  /// [columnFill]. The rows follow what [Workouts.editSet] says.
  void _fill(BuildContext context, SetColumn column, PreviousExercises previous) {
    final fill = columnFill(exercise, column, previous: (index) => previous.matching(exercise, index));
    if (fill.isEmpty) return;
    buzz();
    final workouts = Workouts.of(context);
    for (final MapEntry(key: set, :value) in fill.entries) {
      switch (column) {
        case .weight:
          workouts.editSet(set, weight: value.toDouble());
        case .reps:
          workouts.editSet(set, reps: value.toInt());
        case .distance:
          workouts.editSet(set, distance: value.toDouble());
        case .duration:
          workouts.editSet(set, duration: value.toInt());
      }
    }
  }

  /// Ticks every set that can be ticked, or, when all of them already are,
  /// unticks them all (#225). Through the same path a single tick takes, so a
  /// screen with its own ([onSetDone]: the History editor) keeps it; no rest
  /// timer starts — nobody rests after logging a whole exercise at once.
  Future<void> _tickAll(BuildContext context) async {
    final untick = exercise.every((set) => set.isCompleted);
    final workouts = Workouts.of(context);
    if (!untick) {
      // a ghost row's tick takes its target as the set (#173), as one row's does
      for (final set in exercise.where((set) => !set.isCompleted).toList()) {
        await workouts.acceptTarget(set);
      }
    }
    final targets = exercise.where(
      (set) => switch (untick) {
        true => true,
        false => !set.isCompleted && set.canBeCompleted,
      },
    );
    if (targets.isEmpty) return;
    buzz();
    for (final set in targets.toList()) {
      switch ((onSetDone, untick)) {
        case (var toggle?, _):
          toggle(exercise, set);
        case (null, true):
          workouts.markSetAsIncomplete(exercise, set);
        case (null, false):
          // a tick is the user's say-so, as a single row's is
          workouts.markEdited(set);
          workouts.markSetAsComplete(exercise, set);
      }
    }
  }

  List<Widget> _buttonsHeader(BuildContext context, PreviousExercises previous) {
    final l = L.of(context);
    final prefs = Preferences.watch(context);
    final override = Exercises.watch(context).unitFor(exercise.exercise.id);
    String label(SetColumn column) => _columnLabel(l, prefs, override, exercise.exercise.category, column);

    final columns = SetColumn.of(exercise.exercise.category);
    return [
      for (final column in columns)
        Expanded(
          // a lone column takes both slots
          flex: 3 - columns.length,
          // a program's session: the plan worked these values out, and a fill
          // would write over every one of them with no way back
          child: switch (showsPlan) {
            true => _ColumnLabel(label(column)),
            false => _ColumnHeader(
              key: WorkoutDetailKeys.fillFor(exercise.exercise.id, column.key),
              tooltip: l.fillColumn(label(column)),
              onTap: () => _fill(context, column, previous),
              child: _ColumnLabel(label(column)),
            ),
          },
        ),
    ];
  }

  String _exerciseOptionCopy(BuildContext context, _ExerciseOption option) {
    return switch (option) {
      .autoRestTimer => L.of(context).restTimer,
      .remove => L.of(context).removeExercise,
      .inspectExercise => L.of(context).aboutExercise,
    };
  }

  /// The open slot's pattern (#349), a Programs thing: with the plan not
  /// shown, an exercise that came with one is replaced like any other.
  String? get _slot {
    return switch (showsPlan) {
      true => exercise.pattern,
      false => null,
    };
  }

  /// A superset with the exercise either side, unless it already shares this
  /// one's (#159), and leaving the one this exercise is in.
  List<Widget> _groupOptions(BuildContext context, TextTheme textTheme) {
    final l = L.of(context);
    return [
      if (onGroup case final join?)
        for (final neighbour in [?before, ?after])
          if (!group.contains(neighbour))
            MenuItemButton(
              key: WorkoutDetailKeys.groupWith(exercise.exercise.id, neighbour.exercise.id),
              leadingIcon: const Icon(Icons.link_rounded),
              onPressed: () => join(exercise, neighbour),
              child: Text(l.supersetWith(neighbour.exercise.name), style: textTheme.titleSmall),
            ),
      if ((onLeaveGroup, group.length) case (final leave?, > 1))
        MenuItemButton(
          key: WorkoutDetailKeys.leaveGroup(exercise.exercise.id),
          leadingIcon: const Icon(Icons.link_off_rounded),
          onPressed: () => leave(exercise),
          child: Text(switch (group.length) {
            2 => l.leaveSuperset,
            _ => l.leaveCircuit,
          }, style: textTheme.titleSmall),
        ),
    ];
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
    final isCardio = exercise.exercise.category == .cardio;
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
          initialValue: restFor(context, exercise),
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
    final enabled = await ensureNotificationPermission(
      Theme.of(context).platform,
      analytics: Analytics.of(context),
    );
    if (enabled || !context.mounted) return;
    final L(:notificationsDisabledReminder, :settings) = L.of(context);
    remindNotificationsOff(context, message: notificationsDisabledReminder, settingsLabel: settings);
  }
}

/// One column header of the set table, on one line whatever language it is in.
///
/// The columns are sized for the values under them — a set number, a weight,
/// a rep count — and several of the headers are longer words than any value
/// they sit over. Left to wrap, Spanish's "Serie" broke as "Seri / e" in a
/// 32pt column and Russian's "Повторения" split in two. Shrinking the label
/// is the smaller loss: the header is a hint, and the figures below it are
/// what the eye is actually reading.
class _ColumnLabel extends StatelessWidget {
  final String label;

  const new(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: .scaleDown,
        child: Text(label, maxLines: 1, softWrap: false),
      ),
    );
  }
}

/// A column header that acts on its column (#225): the value columns fill it,
/// the ✓ ticks it. The whole cell answers the tap, and says what it does.
class const _ColumnHeader({
  super.key,
  required final String tooltip,
  required final VoidCallback onTap,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // merged, so the tooltip lands on the node the tap does
    return MergeSemantics(
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          child: InkWell(
            borderRadius: const .all(.circular(6)),
            onTap: onTap,
            child: Padding(
              padding: const .symmetric(vertical: 2),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
