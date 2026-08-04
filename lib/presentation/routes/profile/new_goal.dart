part of 'profile.dart';

/// Composes a goal in two steps: what to measure, then the target.
///
/// Single-stage only. A ladder's later rungs are added by editing the goal —
/// building a multi-rung ladder before the first one exists is a decision the
/// user has no basis to make yet.
Future<Goal?> _showNewGoalDialog(
  BuildContext context,
  TextEditingController controller,
  FocusNode focus,
) async {
  final L(:newGoal, :workouts, :exercises) = L.of(context);

  final measured = await showBrandedDialog<(Exercise?, GoalMetric)?>(
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
            onTap: () => Navigator.of(context, rootNavigator: true).pop((null, GoalMetric.workouts)),
          ),
          ListTile(
            title: Text(exercises),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await _showGoalExercise(context, controller, focus);
              if (picked != null && context.mounted) {
                Navigator.of(context, rootNavigator: true).pop(picked);
              }
            },
          ),
        ],
      ),
    ),
  );

  if (measured == null || !context.mounted) return null;

  final (exercise, metric) = measured;
  return _showTargetDialog(context, exercise: exercise, metric: metric);
}

/// Reuses the exercise picker the charts use, then maps the chosen chart
/// dimension straight onto [GoalMetric] — the two vocabularies share their
/// string values exactly, which is the whole point of `GoalMetric.chart`.
Future<(Exercise, GoalMetric)?> _showGoalExercise(
  BuildContext context,
  TextEditingController controller,
  FocusNode focus,
) async {
  final picked = await _showExercises(context, controller, focus);
  return switch (picked) {
    (final Exercise exercise, final ChartPreferenceType type) => (exercise, GoalMetric.fromString(type.value)),
    _ => null,
  };
}

/// Also the edit dialog: pass [goal] to prefill it and keep its identity, so
/// what comes back updates that goal rather than creating another.
Future<Goal?> _showTargetDialog(
  BuildContext context, {
  required Exercise? exercise,
  required GoalMetric metric,
  Goal? goal,
}) {
  return showBrandedDialog<Goal?>(
    context,
    title: Text(L.of(context).goalTarget),
    content: _TargetForm(exercise: exercise, metric: metric, goal: goal),
  );
}

class _TargetForm extends StatefulWidget {
  final Exercise? exercise;
  final GoalMetric metric;

  /// The goal being edited, or null when composing a new one.
  final Goal? goal;

  const _TargetForm({
    required this.exercise,
    required this.metric,
    this.goal,
  });

  @override
  State<_TargetForm> createState() => _TargetFormState();
}

class _TargetFormState extends State<_TargetForm> {
  /// Owned by the form, not by the caller. A controller disposed as soon as the
  /// dialog's future completes is still attached to a field that has not been
  /// unmounted yet — the route is only starting its exit animation.
  final _controller = TextEditingController();

  GoalCadence? _cadence = GoalCadence.week;

  @override
  void dispose() {
    _controller.dispose();
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
        // units are `late` until Preferences has loaded; an unconverted field
        // would be worse than an empty one, so only prefill once it is safe
        final settings = Preferences.of(context);
        if (settings.isInitialized) {
          final shown = goal.metric.chart?.converter(settings)(target) ?? target.toDouble();
          // run it through the field's own formatters so a duration arrives as
          // mm:ss rather than a raw count of seconds
          _controller.value = _formatters.fold(
            TextEditingValue(text: _trim(shown)),
            (value, formatter) => formatter.formatEditUpdate(TextEditingValue.empty, value),
          );
        }
      // A whole-workout goal is a rate ("4 a week"); a lift is a milestone.
      // Both are changeable below — this only picks the likelier one.
      case null:
        _cadence = widget.metric.isWholeWorkout ? .week : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final settings = Preferences.watch(context);
    final unit = widget.metric.chart?.unitLabel(context, settings);

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 16,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          // Per dimension: a duration types as mm:ss, reps are whole, the rest
          // decimal. Without these the field took any character and the button
          // simply stayed disabled, with nothing saying why.
          inputFormatters: _formatters,
          // no `border`: the app's InputDecorationTheme already fills the
          // field and removes the side, which is what every other input in
          // the app looks like — see `SearchField`
          decoration: InputDecoration(suffixText: unit),
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
              valueListenable: _controller,
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

  /// A whole-workout goal is a count of workouts; every other metric brings its
  /// own rules from [ChartDimension].
  List<TextInputFormatter> get _formatters {
    return widget.metric.chart?.formatters ??
        [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)];
  }

  /// The typed target in display units, or null while the field cannot yield
  /// one. A goal with a target of zero is not a goal, so that counts as "not
  /// filled in" and leaves the button disabled.
  double? get _target {
    final text = _controller.text;
    final typed = widget.metric.chart?.parseTyped(text) ?? double.tryParse(text.trim());
    return switch (typed) {
      final double value when value > 0 => value,
      _ => null,
    };
  }

  /// Targets are stored canonically metric, so a value typed in pounds or miles
  /// is converted back on the way in — the same direction `set_item.dart` takes.
  void _submit() {
    final typed = _target;
    if (typed == null) return;

    final settings = Preferences.of(context);
    final target = widget.metric.chart?.storedValue(settings, typed) ?? typed;

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
        metric: widget.metric,
        exerciseId: widget.exercise?.id,
        cadence: _cadence,
        stages: stages,
      ),
    );
  }
}
