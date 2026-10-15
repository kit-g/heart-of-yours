part of 'goals.dart';

/// What a new goal measures, chosen before its target: an exercise's metric,
/// whole workouts, or the sets on a pattern or a muscle (#344).
typedef _Measured = ({Exercise? exercise, GoalMetric metric, GoalSubject? subject});

/// Composes a goal in two steps: what to measure, then the target.
///
/// Single-stage only. A ladder's later rungs are added by editing the goal —
/// building a multi-rung ladder before the first one exists is a decision the
/// user has no basis to make yet.
Future<Goal?> showNewGoalDialog(
  BuildContext context,
  TextEditingController controller,
  FocusNode focus,
) async {
  final L(:newGoal, :workouts, :exercises, :lensPatterns, :lensMuscles) = L.of(context);

  Future<void> pickSubject(Future<GoalSubject?> Function() pick) async {
    final subject = await pick();
    if (subject != null && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop((exercise: null, metric: GoalMetric.sets, subject: subject));
    }
  }

  final measured = await showBrandedDialog<_Measured?>(
    context,
    title: Text(newGoal),
    padding: .zero,
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: .min,
        children: [
          ListTile(
            title: Text(workouts),
            onTap: () => Navigator.of(
              context,
              rootNavigator: true,
            ).pop((exercise: null, metric: GoalMetric.workouts, subject: null)),
          ),
          ListTile(
            title: Text(exercises),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await _pickMeasuredExercise(context, controller, focus);
              if (picked != null && context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(picked);
              }
            },
          ),
          // a goal on what was trained rather than on one lift: "10 sets of
          // presses a week", "chest twice a week"
          ListTile(
            key: AppKeys.newGoalByPattern,
            title: Text(lensPatterns),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pickSubject(() => _pickPattern(context)),
          ),
          ListTile(
            key: AppKeys.newGoalByMuscle,
            title: Text(lensMuscles),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pickSubject(() => _pickMuscle(context)),
          ),
        ],
      ),
    ),
  );

  if (measured == null || !context.mounted) return null;

  final (:exercise, :metric, :subject) = measured;
  return showGoalTargetDialog(context, exercise: exercise, metric: metric, subject: subject);
}

/// The library's patterns, the ones most exercises train first, as the
/// filters list them.
Future<GoalSubject?> _pickPattern(BuildContext context) {
  final l = L.of(context);
  return _pickFrom(
    context,
    title: l.lensPatterns,
    choices: {for (final key in Exercises.of(context).patterns) GoalSubject.pattern(key): patternLabel(key, l)},
  );
}

/// The muscle map's groups: the key the weekly card counts muscles by.
Future<GoalSubject?> _pickMuscle(BuildContext context) {
  final l = L.of(context);
  return _pickFrom(
    context,
    title: l.lensMuscles,
    choices: {for (final group in MuscleGroup.values) GoalSubject.muscle(group.id): group.label(l)},
  );
}

Future<GoalSubject?> _pickFrom(
  BuildContext context, {
  required String title,
  required Map<GoalSubject, String> choices,
}) {
  return showBrandedDialog<GoalSubject?>(
    context,
    title: Text(title),
    padding: .zero,
    content: SizedBox(
      width: double.maxFinite,
      // a list as long as the library's patterns scrolls inside the dialog
      // rather than pushing it past the screen
      height: min(choices.length * 56.0, 360),
      child: ListView(
        children: [
          for (final MapEntry(key: subject, value: label) in choices.entries)
            ListTile(
              title: Text(label),
              onTap: () => Navigator.of(context, rootNavigator: true).pop(subject),
            ),
        ],
      ),
    ),
  );
}

/// Reuses the exercise picker the charts use, then maps the chosen chart
/// dimension straight onto [GoalMetric] — the two vocabularies share their
/// string values exactly, which is the whole point of `GoalMetric.chart`.
Future<_Measured?> _pickMeasuredExercise(
  BuildContext context,
  TextEditingController controller,
  FocusNode focus,
) async {
  final picked = await showExercisePicker(context, controller: controller, focus: focus);
  return switch (picked) {
    (final Exercise exercise, final ChartPreferenceType type) => (
      exercise: exercise,
      metric: GoalMetric.fromString(type.value),
      subject: null,
    ),
    _ => null,
  };
}

/// Also the edit dialog: pass [goal] to prefill it and keep its identity, so
/// what comes back updates that goal rather than creating another.
Future<Goal?> showGoalTargetDialog(
  BuildContext context, {
  required Exercise? exercise,
  required GoalMetric metric,
  GoalSubject? subject,
  Goal? goal,
}) {
  return showBrandedDialog<Goal?>(
    context,
    title: Text(L.of(context).goalTarget),
    content: _GoalTargetForm(exercise: exercise, metric: metric, subject: subject, goal: goal),
  );
}

class _GoalTargetForm extends StatefulWidget {
  final Exercise? exercise;
  final GoalMetric metric;

  /// A pattern or a muscle, for a goal counting the sets or sessions on it.
  final GoalSubject? subject;

  /// The goal being edited, or null when composing a new one.
  final Goal? goal;

  const new({
    required this.exercise,
    required this.metric,
    this.subject,
    this.goal,
  });

  @override
  State<_GoalTargetForm> createState() => _GoalTargetFormState();
}

class _GoalTargetFormState extends State<_GoalTargetForm> {
  /// Owned by the form, not by the caller. A controller disposed as soon as the
  /// dialog's future completes is still attached to a field that has not been
  /// unmounted yet — the route is only starting its exit animation.
  late final _input = GoalTargetInput(
    widget.metric.chart,
    scale: switch (widget.exercise) {
      Exercise(:final id, :final category) => (unit: Exercises.of(context).unitFor(id), category: category),
      null => (unit: null, category: null),
    },
  );

  GoalCadence? _cadence = GoalCadence.week;

  /// Sets or sessions, for a goal on a pattern or a muscle; [widget.metric]
  /// for every other goal, and never changed.
  late final _metric = ValueNotifier(widget.metric);

  @override
  void dispose() {
    _metric.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    switch (widget.goal) {
      // editing: show what is already set, in the user's own units
      case final Goal goal:
        _cadence = goal.cadence;
        final target = goal.currentStage?.target ?? goal.stages.last.target;
        _input.prefill(Preferences.of(context), target);
      // A whole-workout goal is a rate ("4 a week"); a lift is a milestone.
      // Both are changeable below — this only picks the likelier one.
      case null:
        _cadence = widget.metric.isWholeWorkout || widget.metric.countsSubject ? .week : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = Preferences.watch(context);
    final (:unit, :category) = _input.scale;
    final suffix = widget.metric.chart?.unitLabel(context, settings, unit: unit, category: category);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 16,
      children: [
        TextField(
          controller: _input.controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Per dimension: a duration types as mm:ss, reps are whole, the rest
          // decimal. Without these the field took any character and the button
          // simply stayed disabled, with nothing saying why.
          inputFormatters: _input.formatters,
          // no `border`: the app's InputDecorationTheme already fills the
          // field and removes the side, which is what every other input in
          // the app looks like — see `SearchField`
          decoration: InputDecoration(suffixText: suffix),
        ),
        if (widget.metric.countsSubject)
          ValueListenableBuilder<GoalMetric>(
            valueListenable: _metric,
            builder: (_, metric, _) {
              return SettingSwitcher<GoalMetric>(
                key: AppKeys.goalCountedMetric,
                value: metric,
                children: {
                  GoalMetric.sets: Text(l.sets),
                  GoalMetric.sessions: Text(l.sessions),
                },
                onValueChanged: (picked) => _metric.value = picked ?? metric,
              );
            },
          ),
        SegmentedButton<GoalCadence?>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: null, label: Text(l.goalMilestone)),
            ButtonSegment(value: GoalCadence.week, label: Text(l.goalWeekly)),
            ButtonSegment(value: GoalCadence.month, label: Text(l.goalMonthly)),
          ],
          selected: {_cadence},
          onSelectionChanged: (selection) => setState(() => _cadence = selection.first),
        ),
        Row(
          mainAxisAlignment: .end,
          children: [
            // Disabled until the field holds a usable target. It used to look
            // live and silently do nothing, which reads as the app ignoring
            // you rather than as "this is not filled in yet".
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _input.controller,
              builder: (_, _, _) {
                return PrimaryButton.shrunk(
                  onPressed: switch (_target) {
                    null => null,
                    _ => _submit,
                  },
                  child: Text(widget.goal == null ? l.addGoal : l.save),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  /// The typed target in display units, or null while the field cannot yield
  /// one.
  double? get _target => _input.typed;

  /// Targets are stored canonically metric, so a value typed in pounds or miles
  /// is converted back on the way in — the same direction `set_item.dart` takes.
  void _submit() {
    final typed = _target;
    if (typed == null) return;

    final settings = Preferences.of(context);
    final target = _input.toStored(settings, typed);

    // Editing rewrites the rung being worked toward and leaves the rest of the
    // ladder — and every stage id — alone, so achievements already recorded on
    // the server survive the edit.
    final stages = switch (widget.goal) {
      final Goal goal => goal.stages.map((stage) {
        final rung = goal.currentStage ?? goal.stages.last;
        return stage.id == rung.id ? stage.copyWith(target: target) : stage;
      }).toList(),
      null => [GoalStage(target: target)],
    };

    Navigator.of(context, rootNavigator: true).pop(
      Goal(
        id: widget.goal?.id,
        metric: _metric.value,
        exerciseId: widget.exercise?.id,
        pattern: switch (widget.subject) {
          PatternSubject(:final key) => key,
          _ => null,
        },
        muscle: switch (widget.subject) {
          MuscleSubject(:final key) => key,
          _ => null,
        },
        cadence: _cadence,
        stages: stages,
      ),
    );
  }
}
