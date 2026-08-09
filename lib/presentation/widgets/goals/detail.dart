part of 'goals.dart';

/// Everything about one goal, which is more than a row can hold.
///
/// The summary row answers "where am I"; this answers "against what". The chart
/// carries each rung as a line across it, so how far up the ladder you are is
/// read from the picture rather than from a sentence, and the ladder below is
/// where rungs are actually edited.
class GoalDetail extends StatefulWidget {
  final Goal goal;
  final WorkoutAggregation workouts;

  /// Null while the goal is being shown outside a route that can close.
  final VoidCallback? onClose;

  /// The sheet's controller, so dragging the list drags the sheet.
  final ScrollController? scrollController;

  const GoalDetail({
    super.key,
    required this.goal,
    required this.workouts,
    this.onClose,
    this.scrollController,
  });

  @override
  State<GoalDetail> createState() => _GoalDetailState();
}

class _GoalDetailState extends State<GoalDetail> {
  Future<num?>? _reading;
  Object? _key;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final settings = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    final l = L.of(context);

    // the goal as the notifier currently holds it, so an edit made here is
    // reflected without this widget owning a copy that can go stale
    final goal = Goals.watch(context).firstWhere(
      (each) => each.id == widget.goal.id,
      orElse: () => widget.goal,
    );
    final exercise = goalExercise(goal, exercises);

    final key = (goal.id, exercise?.name, widget.workouts.length);
    if (key != _key) {
      _key = key;
      _reading = currentGoalValue(
        goal,
        exercises: exercises,
        workouts: widget.workouts,
        workoutsThisMonth: () => Stats.of(context).getMonthlyWorkoutCount(DateTime.now()),
      );
    }

    // see GoalRow: units are `late` until Preferences has loaded
    if (!settings.isInitialized) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _header(context, l, goal, exercise, textTheme, colorScheme),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            // no horizontal inset here: a rung's swipe background runs the full
            // width of the sheet, so the inset belongs to what sits inside
            padding: const .only(bottom: 16),
            children: [
              if (!goal.metric.isWholeWorkout && exercise != null)
                Padding(
                  padding: const .symmetric(horizontal: 16),
                  child: _chart(context, goal, exercise, settings, colorScheme),
                ),
              const SizedBox(height: 8),
              GoalLadder(goal: goal, settings: settings),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    L l,
    Goal goal,
    Exercise? exercise,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const .fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: .start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 4,
              children: [
                Text(goalTitle(context, goal, exercise), style: textTheme.titleLarge),
                FutureBuilder<num?>(
                  future: _reading,
                  builder: (_, snapshot) {
                    return Text(
                      goalStatus(context, goal, settings: Preferences.watch(context), current: snapshot.data),
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    );
                  },
                ),
              ],
            ),
          ),
          if (widget.onClose case final VoidCallback close)
            FeedbackButton.circular(
              key: AppKeys.closeGoalDetail,
              tooltip: l.close,
              onPressed: close,
              child: const Padding(
                padding: .all(1.0),
                child: Icon(Icons.close_rounded, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  /// The metric's history with every rung drawn across it.
  Widget _chart(
    BuildContext context,
    Goal goal,
    Exercise exercise,
    Preferences settings,
    ColorScheme colorScheme,
  ) {
    final metric = goal.metric.chart;
    if (metric == null) return const SizedBox.shrink();

    final convert = metric.converter(settings);

    return SizedBox(
      height: 300,
      child: ExerciseChart(
        // the whole ladder: there is room for it here, unlike on a dashboard card
        thresholds: goalThresholds(context, goal, metric: metric, settings: settings),
        callback: () => Exercises.of(context).getChartExerciseMetics(metric, exercise.name),
        refreshKey: (exercise.name, metric, goal.stages.length),
        converter: convert,
        getLeftLabel: metric.leftLabel(Theme.of(context).textTheme.bodySmall),
        getTooltip: metric.tooltip,
        yStepCandidates: metric.yStepCandidates,
        color: metric.color(context),
        emptyState: const SizedBox.shrink(),
        errorState: const SizedBox.shrink(),
        loadingState: const SizedBox(height: 300),
      ),
    );
  }
}
