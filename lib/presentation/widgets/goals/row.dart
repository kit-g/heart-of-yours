part of 'goals.dart';

/// A single goal: what it measures, where the user is, and what is next.
///
/// Deliberately quiet — no percentage in large type, no badge on an achieved
/// stage. The numbers are the content.
///
/// Stateful for one reason: the current value is a database read, and it must
/// be cached. Every inherited lookup happens in [build] and is passed down —
/// resolving a provider inside an async helper registers a dependency from a
/// subtree that may already be on its way out, which throws during a route
/// teardown (`_dependents.isEmpty`).
class GoalRow extends StatefulWidget {
  final Goal goal;
  final WorkoutAggregation workouts;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GoalRow({
    super.key,
    required this.goal,
    required this.workouts,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<GoalRow> createState() => _GoalRowState();
}

class _GoalRowState extends State<GoalRow> {
  Future<num?>? _reading;
  Object? _key;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final settings = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    final l = L.of(context);

    final goal = widget.goal;
    final exercise = goalExercise(widget.goal, exercises);

    // re-read only when the thing being measured changes, not on every notify
    final key = (goal.id, exercise?.name, goal.cadence, widget.workouts.length);
    if (key != _key) {
      _key = key;
      _reading = _read(exercises);
    }

    // Preferences loads from disk without being awaited at startup, and its
    // unit fields are `late` — reading one before [Preferences.isInitialized]
    // throws. This card paints as soon as there are goals, which can be before
    // that lands, so hold back everything that needs a unit. `watch` brings us
    // straight back when it does. The chart grid never hits this because it
    // waits on `charts.initialized` first.
    final converted = settings.isInitialized;
    final targets = switch (converted) {
      true => goal.stages.map((stage) => _convert(settings, stage.target)).toList(),
      false => const <double>[],
    };
    final subdued = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: widget.onEdit,
      borderRadius: const .all(.circular(8)),
      child: Padding(
        padding: const .symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 4,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title(context, l, exercise),
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
                // bare, like the chart card's — the app does not ask twice
                FeedbackButton.circular(
                  key: AppKeys.deleteGoal(goal.id),
                  tooltip: l.delete,
                  onPressed: widget.onDelete,
                  child: Padding(
                    padding: const .all(1.0),
                    child: Icon(Icons.close_rounded, size: 18, color: dividerColor),
                  ),
                ),
              ],
            ),
            if (converted)
              FutureBuilder<num?>(
                future: _reading,
                builder: (_, snapshot) {
                  final current = switch (snapshot.data) {
                    final num value => _convert(settings, value),
                    _ => null,
                  };

                  return Column(
                    crossAxisAlignment: .start,
                    spacing: 6,
                    children: [
                      Text(_status(context, l, settings, current), style: subdued),
                      GoalLadderBar(
                        targets: targets,
                        current: current,
                        lowerIsBetter: goal.metric.lowerIsBetter,
                        track: colorScheme.surfaceContainerHighest,
                        fill: colorScheme.primary,
                        achieved: goal.stages.map((stage) => stage.isAchieved).toList(),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// "Workouts", or "Bench Press (Barbell) — Estimated 1RM".
  String _title(BuildContext context, L l, Exercise? exercise) {
    if (widget.goal.metric.isWholeWorkout) return l.workouts;

    final metric = widget.goal.metric.chart?.label(context);
    return switch ((exercise?.name, metric)) {
      (final String name, final String metric) => '$name — $metric',
      (final String name, _) => name,
      _ => metric ?? '',
    };
  }

  /// The line under the title: where the user is, and the deadline if there is
  /// one. A cadence goal says "1 / 4 · per week"; a ladder says what is next.
  String _status(BuildContext context, L l, Preferences settings, double? current) {
    final goal = widget.goal;
    final stage = goal.currentStage;
    if (stage == null) return l.goalComplete;

    final unit = goal.metric.chart?.unitLabel(context, settings) ?? '';
    final suffix = unit.isEmpty ? '' : ' $unit';

    final progress = switch (current) {
      final double value => '${value.trimmed()} / ',
      _ => '',
    };

    final cadence = switch (goal.cadence) {
      .week => ' · ${l.goalPerWeek}',
      .month => ' · ${l.goalPerMonth}',
      null => switch (stage.dueOn) {
        final DateTime due => ' · ${l.goalDue(DateFormat.yMMMd().format(due))}',
        _ => '',
      },
    };

    return '$progress${_convert(settings, stage.target).trimmed()}$suffix$cadence';
  }

  Future<num?> _read(Exercises exercises) {
    return currentGoalValue(widget.goal, exercises: exercises, workouts: widget.workouts);
  }

  double _convert(Preferences settings, num value) {
    return widget.goal.metric.chart?.converter(settings)(value) ?? value.toDouble();
  }
}
