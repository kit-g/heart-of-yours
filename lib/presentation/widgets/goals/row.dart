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

  const new({
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

    final goal = widget.goal;
    final exercise = goalExercise(widget.goal, exercises);

    // re-read only when the thing being measured changes, not on every notify
    final key = (goal.id, exercise?.name, goal.cadence, widget.workouts.workoutCount);
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

    return _SwipeToDelete(
      dismissKey: ValueKey('GoalRow.${goal.id}'),
      onDelete: widget.onDelete,
      child: InkWell(
        onTap: widget.onEdit,
        borderRadius: const .all(.circular(8)),
        child: Padding(
          // the row's own inset, inside the full-width swipe background
          padding: const .symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              Text(
                goalTitle(context, widget.goal, exercise),
                style: textTheme.bodyLarge,
                maxLines: 1,
                overflow: .ellipsis,
              ),
              if (converted)
                FutureBuilder<num?>(
                  future: _reading,
                  builder: (_, snapshot) {
                    // the bar plots against converted targets, so it needs the
                    // converted reading; the status line converts its own now
                    final reading = snapshot.data;
                    final current = switch (reading) {
                      final num value => _convert(settings, value),
                      _ => null,
                    };
                    final statusText = goalStatus(context, widget.goal, settings: settings, current: reading);
                    final achievedCount = goal.stages.where((stage) => stage.isAchieved).length;

                    return Column(
                      crossAxisAlignment: .start,
                      spacing: 6,
                      children: [
                        Text(
                          statusText,
                          style: subdued,
                        ),
                        GoalLadderBar(
                          targets: targets,
                          current: current,
                          lowerIsBetter: goal.metric.lowerIsBetter,
                          track: colorScheme.surfaceContainerHighest,
                          fill: colorScheme.primary,
                          achieved: goal.stages.map((stage) => stage.isAchieved).toList(),
                          semanticLabel: goal.stages.isEmpty
                              ? null
                              : L.of(context).goalLadderSummary(achievedCount, goal.stages.length, statusText),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<num?> _read(Exercises exercises) {
    return currentGoalValue(
      widget.goal,
      exercises: exercises,
      workoutCount: workoutCounter(Stats.of(context)),
    );
  }

  double _convert(Preferences settings, num value) {
    return widget.goal.metric.chart?.converter(settings)(value) ?? value.toDouble();
  }
}
