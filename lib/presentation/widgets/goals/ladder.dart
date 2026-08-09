part of 'goals.dart';

/// The rungs of a goal, in the order they are climbed.
///
/// This is where a ladder is actually built: the summary row can show the one
/// you are working toward, but adding a second rung, giving it a deadline or
/// seeing when an earlier one fell needs a list.
///
/// Achieved rungs are stated, not celebrated — a date and a muted tick.
class GoalLadder extends StatelessWidget {
  final Goal goal;
  final Preferences settings;

  const GoalLadder({
    super.key,
    required this.goal,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final l = L.of(context);

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(16, 0, 16, 4),
          child: Text(l.goalLadder, style: textTheme.titleMedium),
        ),
        for (final (index, stage) in goal.stages.indexed)
          _Rung(
            key: AppKeys.ladderRung(stage.id ?? '$index'),
            goal: goal,
            stage: stage,
            settings: settings,
            // a recurring goal has one standing target; there is no ladder to
            // take a rung out of
            onRemove: switch (goal.cadence == null && goal.stages.length > 1) {
              true => () => _removeRung(context, stage),
              false => null,
            },
          ),
        if (goal.cadence == null)
          Align(
            alignment: .centerLeft,
            child: Padding(
              padding: const .fromLTRB(16, 8, 16, 0),
              child: PrimaryButton.shrunk(
                key: AppKeys.addRung,
                onPressed: () => _addRung(context),
                child: Row(
                  spacing: 6,
                  children: [
                    const Icon(Icons.add_rounded, size: 20),
                    Text(l.goalAddRung),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addRung(BuildContext context) async {
    final goals = Goals.of(context);
    final exercise = goalExercise(goal, Exercises.of(context));

    final rung = await showRungDialog(context, goal: goal, exercise: exercise);
    if (rung == null) return;

    if (!context.mounted) return;

    // Appended as typed; [Goals.inDeadlineOrder] puts it where it falls due.
    await _amend(context, () => goals.update(goal.copyWith(stages: [...goal.stages, rung])));
  }

  Future<void> _removeRung(BuildContext context, GoalStage stage) {
    final stages = goal.stages.where((each) => each.id != stage.id).toList();
    final goals = Goals.of(context);
    return _amend(context, () => goals.update(goal.copyWith(stages: stages)));
  }
}

class _Rung extends StatelessWidget {
  final Goal goal;
  final GoalStage stage;
  final Preferences settings;
  final VoidCallback? onRemove;

  const _Rung({
    super.key,
    required this.goal,
    required this.stage,
    required this.settings,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final l = L.of(context);

    final unit = goal.metric.chart?.unitLabel(context, settings);
    final target = goal.convert(settings, stage.target).trimmed();
    final isCurrent = stage.id == goal.currentStage?.id;

    final row = InkWell(
      onTap: () => _edit(context),
      borderRadius: const .all(.circular(8)),
      child: Padding(
        // matches the sheet's own inset; the swipe background behind this runs
        // the full width, the way it does on the goals card
        padding: const .symmetric(horizontal: 16, vertical: 10),
        child: Row(
          spacing: 12,
          children: [
            Icon(
              // circled, to pair with the empty circle an unmet rung shows —
              // filled against outline reads as done without celebrating it
              stage.isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              // achieved reads as settled, not as a prize
              color: stage.isAchieved ? colorScheme.onSurfaceVariant : dividerColor,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 2,
                children: [
                  Text(
                    switch (unit) {
                      final String unit => '$target $unit',
                      null => target,
                    },
                    style: switch (isCurrent) {
                      true => textTheme.bodyLarge,
                      false => textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    },
                  ),
                  Text(
                    _state(l),
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // A goal needs a rung, so the last one cannot be swiped away — offering the
    // gesture and then refusing it would be worse than not offering it.
    return switch (onRemove) {
      final VoidCallback remove => _SwipeToDelete(
        dismissKey: ValueKey('GoalRung.${stage.id}'),
        onDelete: remove,
        child: row,
      ),
      null => row,
    };
  }

  /// Achieved beats due: once a rung has fallen, when it fell is the fact worth
  /// stating, and its old deadline stops mattering.
  String _state(L l) {
    return switch ((stage.achievedAt, stage.dueOn)) {
      (final DateTime at, _) => l.goalAchievedOn(DateFormat.yMMMd().format(at)),
      (_, final DateTime due) => l.goalDue(DateFormat.yMMMd().format(due)),
      _ => l.goalNoDeadline,
    };
  }

  Future<void> _edit(BuildContext context) async {
    final goals = Goals.of(context);
    final exercise = goalExercise(goal, Exercises.of(context));

    final edited = await showRungDialog(context, goal: goal, exercise: exercise, stage: stage);
    if (edited == null) return;

    final stages = goal.stages.map((each) => each.id == stage.id ? edited : each).toList();
    if (!context.mounted) return;
    await _amend(context, () => goals.update(goal.copyWith(stages: stages)));
  }
}
