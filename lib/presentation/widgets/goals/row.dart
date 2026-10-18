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

  /// Where a pattern or muscle goal reads its sets: shared by the rows of one
  /// card, so a refresh reads each window once ([sharedLensSets]).
  final LensSetsReader lensSets;

  /// Opens the goal, or its program; absent where there is nowhere to go.
  final VoidCallback? onEdit;

  /// Swiping the row away deletes the goal; absent for a goal a program
  /// implies (#353), which is the program's to drop, not the user's.
  final VoidCallback? onDelete;

  /// The program a derived goal comes from, by name (#353).
  final String? from;

  /// The running programs, which forecast a goal whose weight one of them
  /// grows (#353); empty while Programs is off.
  final List<ProgramFeed> feeds;

  const new({
    super.key,
    required this.goal,
    required this.workouts,
    required this.lensSets,
    this.onEdit,
    this.onDelete,
    this.from,
    this.feeds = const [],
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
    final scale = goalScale(goal, exercises);

    // re-read only when the thing being measured changes, not on every notify
    // the week a weekly goal is read over moves with the user's first day
    final key = (
      goal.id,
      exercise?.name,
      goal.cadence,
      widget.workouts.workoutCount,
      settings.firstWeekday,
      // a program's count moves with its own sessions
      widget.feeds.map((feed) => feed.position.thisWeek).join(','),
    );
    if (key != _key) {
      _key = key;
      _reading = _read(exercises, settings.firstWeekday);
    }

    // Preferences loads from disk without being awaited at startup, and its
    // unit fields are `late` — reading one before [Preferences.isInitialized]
    // throws. This card paints as soon as there are goals, which can be before
    // that lands, so hold back everything that needs a unit. `watch` brings us
    // straight back when it does. The chart grid never hits this because it
    // waits on `charts.initialized` first.
    final converted = settings.isInitialized;
    final targets = switch (converted) {
      true => goal.stages.map((stage) => goal.convert(settings, scale, stage.target)).toList(),
      false => const <double>[],
    };
    final subdued = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    final row = InkWell(
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
            if (widget.from case final String program)
              Text(L.of(context).goalFromProgram(program), style: subdued, maxLines: 1, overflow: .ellipsis),
            if (converted)
              FutureBuilder<num?>(
                future: _reading,
                builder: (_, snapshot) {
                  // the bar plots against converted targets, so it needs the
                  // converted reading; the status line converts its own now
                  final reading = snapshot.data;
                  final current = switch (reading) {
                    final num value => goal.convert(settings, scale, value),
                    _ => null,
                  };
                  final status = goalStatus(
                    context,
                    widget.goal,
                    settings: settings,
                    scale: scale,
                    current: reading,
                  );
                  // where a running program takes it, beside where it is
                  final statusText = switch (forecastFrom(widget.feeds, goal, reading)) {
                    final GoalForecast forecast => '$status · ${forecastLabel(L.of(context), forecast)}',
                    null => status,
                  };
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
    );

    return switch (widget.onDelete) {
      final VoidCallback onDelete => _SwipeToDelete(
        dismissKey: ValueKey('GoalRow.${goal.id}'),
        onDelete: onDelete,
        child: row,
      ),
      null => row,
    };
  }

  Future<num?> _read(Exercises exercises, int firstWeekday) {
    // a program's own sessions a week counts that program's sessions — the
    // same count its card and page say — not every workout of the week
    if (widget.goal case Goal(:final String id, metric: .workouts, cadence: .week) when id.startsWith('program:')) {
      if (widget.feeds.where((feed) => id.startsWith('program:${feed.program.id}:')).firstOrNull case final feed?) {
        return Future.value(feed.position.thisWeek);
      }
    }
    return currentGoalValue(
      widget.goal,
      exercises: exercises,
      firstWeekday: firstWeekday,
      workoutCount: workoutCounter(Stats.of(context), firstWeekday: firstWeekday),
      lensSets: widget.lensSets,
    );
  }
}
