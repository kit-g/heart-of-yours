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
  final AddWarmups? onAddWarmups;

  /// Whether the warm-ups' one offer (#158), or the notice after a no, sits
  /// under this exercise's sets.
  final bool offersWarmups;
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
    this.onAddWarmups,
    this.offersWarmups = false,
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
    final preferences = Preferences.watch(context);

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
                      _ExerciseOptionsButton(
                        key: WorkoutDetailKeys.exerciseOptionsFor(exercise.exercise.id),
                        options: () => _options(context, exercises, preferences),
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
                      if ((onAddWarmups, offersWarmups) case (final add?, true))
                        Padding(
                          padding: const .symmetric(horizontal: 16, vertical: 4),
                          child: _WarmupsPrompt(exercise: exercise, onAdd: add),
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

  /// The open slot's pattern (#349), a Programs thing: with the plan not
  /// shown, an exercise that came with one is replaced like any other.
  String? get _slot {
    return switch (showsPlan) {
      true => exercise.pattern,
      false => null,
    };
  }

  /// The exercise's ⋯ (#488), most used first: what happens between this
  /// exercise's sets, then its note, then how it sits on the sheet, then its
  /// unit and its page. Removing it comes last, set apart.
  List<PopupMenuEntry<_ExerciseAction>> _options(BuildContext context, Exercises exercises, Preferences preferences) {
    final l = L.of(context);
    final id = exercise.exercise.id;
    return [
      _option(
        icon: Icons.timer_outlined,
        label: l.restTimer,
        onPick: (_) {
          buzz();
          _selectRestTime(context, initialValue: restFor(context, exercise));
        },
      ),
      if ((onAddWarmups, preferences.isOn(.warmups)) case (final add?, true))
        if (_warmupsFor(exercise, preferences, exercises) case final sets when sets.isNotEmpty)
          _option(
            key: WorkoutDetailKeys.addWarmupsFor(id),
            icon: Feature.warmups.icon,
            label: l.addWarmups,
            onPick: (_) {
              buzz();
              add(exercise, sets);
            },
          ),
      if (onNoteChanged != null) ...[
        _option(
          icon: Icons.edit_note_rounded,
          label: switch (exercise.note) {
            String _ => l.editExerciseNote,
            null => l.addExerciseNote,
          },
          onPick: (_) => _editNote(context),
        ),
        if (exercises.canPinNote && exercises.noteFor(id) != null)
          _option(
            icon: Icons.push_pin_outlined,
            label: l.unpinExerciseNote,
            onPick: (_) => _unpinNote(context),
          ),
      ],
      ..._groupOptions(context),
      if ((onReplaceExercise, exercise.isStarted) case (final onReplace?, false))
        switch (_slot) {
          final String pattern => _option(
            key: WorkoutDetailKeys.swapExerciseFor(id),
            icon: Icons.swap_horiz_rounded,
            label: l.swapExercise,
            onPick: (_) => _replace(context, pattern, onReplace),
          ),
          null => _option(
            key: WorkoutDetailKeys.replaceExerciseFor(id),
            icon: Icons.find_replace_rounded,
            label: l.replaceExercise,
            onPick: (_) => _replaceAny(context, onReplace),
          ),
        },
      if (_unit(context, exercises, preferences) case (final label, final current))
        _option(
          icon: Icons.straighten,
          label: label,
          value: _unitCopy(l, current),
          onPick: (anchor) => _pickUnit(context, anchor, current),
        ),
      _option(
        icon: Icons.info_outline_rounded,
        label: l.aboutExercise,
        onPick: (_) {
          buzz();
          onTapExercise(exercise.exercise);
        },
      ),
      _removeOption(context, l.removeExercise),
    ];
  }

  /// The one destructive row: in the error colour, under a hairline that
  /// sets it apart from the rows that keep the exercise.
  PopupMenuItem<_ExerciseAction> _removeOption(BuildContext context, String label) {
    final ColorScheme(:error, :outlineVariant) = Theme.of(context).colorScheme;
    return PopupMenuItem<_ExerciseAction>(
      key: WorkoutDetailKeys.removeExerciseFor(exercise.exercise.id),
      padding: .zero,
      value: (_) {
        buzz();
        onRemoveExercise(exercise);
      },
      child: Container(
        width: _exerciseMenuWidth,
        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
        alignment: .centerStart,
        padding: const .symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: outlineVariant, width: .5)),
        ),
        child: _OptionRow(icon: Icons.close, label: label, color: error),
      ),
    );
  }

  PopupMenuItem<_ExerciseAction> _option({
    Key? key,
    required IconData icon,
    required String label,
    String? value,
    required _ExerciseAction onPick,
  }) {
    return PopupMenuItem<_ExerciseAction>(
      key: key,
      value: onPick,
      child: _OptionRow(icon: icon, label: label, value: value),
    );
  }

  /// A superset with the exercise either side, unless it already shares this
  /// one's (#159), and leaving the one this exercise is in. The neighbour's
  /// name wraps inside the menu's width rather than widening it.
  List<PopupMenuEntry<_ExerciseAction>> _groupOptions(BuildContext context) {
    final l = L.of(context);
    return [
      if (onGroup case final join?)
        for (final neighbour in [?before, ?after])
          if (!group.contains(neighbour))
            _option(
              key: WorkoutDetailKeys.groupWith(exercise.exercise.id, neighbour.exercise.id),
              icon: Icons.link_rounded,
              label: l.supersetWith(neighbour.exercise.name),
              onPick: (_) => join(exercise, neighbour),
            ),
      if ((onLeaveGroup, group.length) case (final leave?, > 1))
        _option(
          key: WorkoutDetailKeys.leaveGroup(exercise.exercise.id),
          icon: Icons.link_off_rounded,
          label: switch (group.length) {
            2 => l.leaveSuperset,
            _ => l.leaveCircuit,
          },
          onPick: (_) => leave(exercise),
        ),
    ];
  }

  /// The per-exercise unit's row, for weight- or distance-based exercises
  /// only (duration and reps have no unit): its label, and the unit in force
  /// — the global setting for this dimension when there's no override of the
  /// exercise's own, so the row always names one.
  (String, MeasurementUnit)? _unit(BuildContext context, Exercises exercises, Preferences prefs) {
    final l = L.of(context);
    final override = exercises.unitFor(exercise.exercise.id);
    return switch (exercise.exercise.category) {
      .duration || .repsOnly => null,
      .cardio => (l.distanceUnitLabel, override ?? prefs.distanceUnit),
      .barbell ||
      .dumbbell ||
      .machine ||
      .weightedBodyWeight ||
      .assistedBodyWeight ||
      .weightedDistance ||
      .weightedDuration => (l.weightUnitLabel, override ?? prefs.weightUnit),
    };
  }

  String _unitCopy(L l, MeasurementUnit unit) {
    return switch (unit) {
      .imperial => l.imperial,
      .metric => l.metric,
    };
  }

  /// The unit's two choices, in a popup of their own where the menu was:
  /// writes through [Exercises.setUnit] (per user).
  Future<void> _pickUnit(BuildContext context, RelativeRect anchor, MeasurementUnit current) async {
    final l = L.of(context);
    final exercises = Exercises.of(context);
    final picked = await showMenu<MeasurementUnit>(
      context: context,
      position: anchor,
      constraints: const BoxConstraints(minWidth: _exerciseMenuWidth, maxWidth: _exerciseMenuWidth),
      items: [
        for (final unit in MeasurementUnit.values)
          PopupMenuItem<MeasurementUnit>(
            value: unit,
            child: Semantics(
              selected: unit == current,
              child: _OptionRow(
                icon: unit == current ? Icons.check : null,
                label: _unitCopy(l, unit),
              ),
            ),
          ),
      ],
    );
    if (picked == null) return;
    buzz();
    exercises.setUnit(exercise.exercise, picked);
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

/// The exercise menu's one width (#488): rows wrap a long exercise name
/// inside it rather than widening the menu past the screen's edge, as the old
/// menu did with "Superset with Triceps Pushdown (Cable - Straight Bar)". A
/// multiple of 56, the step a popup menu rounds its width up to, or the rows
/// stop short of its right edge.
const _exerciseMenuWidth = 280.0;

/// What a row of the exercise menu does once the menu has closed. [anchor] is
/// where the menu stood, for a row that opens a choice of its own there.
typedef _ExerciseAction = void Function(RelativeRect anchor);

/// An exercise's ⋯: the app's popup, as the workout's own ⋯ is, hung under
/// the button with its right edge on the button's.
class _ExerciseOptionsButton extends StatefulWidget {
  final List<PopupMenuEntry<_ExerciseAction>> Function() options;

  const new({super.key, required this.options});

  @override
  State<_ExerciseOptionsButton> createState() => _ExerciseOptionsButtonState();
}

class _ExerciseOptionsButtonState extends State<_ExerciseOptionsButton> {
  final _anchor = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: _anchor,
      tooltip: L.of(context).exerciseOptions,
      style: const ButtonStyle(
        visualDensity: VisualDensity(vertical: 0, horizontal: -2),
      ),
      icon: const Icon(Icons.more_horiz),
      onPressed: _open,
    );
  }

  Future<void> _open() async {
    RelativeRect anchor() => menuUnderValue(context, _anchor, width: _exerciseMenuWidth);
    final picked = await showMenu<_ExerciseAction>(
      context: context,
      position: anchor(),
      constraints: const BoxConstraints(minWidth: _exerciseMenuWidth, maxWidth: _exerciseMenuWidth),
      items: widget.options(),
    );
    if (!mounted) return;
    picked?.call(anchor());
  }
}

/// One row of the exercise menu: an icon and up to two lines of copy, and,
/// for a setting, the value in force at its end.
class const _OptionRow({
  final IconData? icon,
  required final String label,
  final String? value,
  final Color? color,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Row(
      spacing: 12,
      children: [
        SizedBox(width: 24, child: Icon(icon, color: color)),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: .ellipsis,
            style: textTheme.titleSmall?.copyWith(color: color),
          ),
        ),
        if (value case final String value)
          Text(value, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
