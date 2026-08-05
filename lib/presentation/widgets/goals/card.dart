part of 'goals.dart';

/// One card listing every goal, rather than one card per goal — a handful of
/// goals would otherwise fill the dashboard with near-empty tiles.
class GoalsCard extends StatefulWidget {
  final WorkoutAggregation workouts;

  /// Whether the card has been given a fixed height and must scroll its list
  /// rather than grow. True in the tablet row, false in the phone column.
  final bool bounded;

  /// Height of the heading row. The caller sets it because the card sits beside
  /// other tiles whose headings must start their content on the same line, and
  /// this one is taller by itself — it carries a button and they carry a title.
  final double headerHeight;

  const GoalsCard({
    super.key,
    required this.workouts,
    this.bounded = false,
    this.headerHeight = 44,
  });

  @override
  State<GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends State<GoalsCard> {
  /// Owned here rather than per-dialog. Disposing them when a dialog's future
  /// completes would pull them out from under a field still animating away.
  final _searchController = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(:goals, :addGoal, :noGoalsYet) = L.of(context);
    final state = Goals.watch(context);

    final body = Container(
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        color: colorScheme.surfaceContainer,
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 12, vertical: 8),
        child: switch (state.isEmpty) {
          true => Align(
            alignment: .topLeft,
            child: Padding(
              padding: const .symmetric(vertical: 8),
              child: Text(
                noGoalsYet,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          false => _rows(state.all),
        },
      ),
    );

    // Same skeleton as the aggregation chart it sits beside — a title in
    // `titleLarge` over a filled, rounded block. An outlined box with the title
    // inside read as a different kind of object entirely, side by side.
    return Padding(
      // vertical only: whoever lays the tiles out owns the horizontal inset, so
      // the gutter between them can match the chart grid's
      padding: const .symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          SizedBox(
            height: widget.headerHeight,
            child: Row(
              children: [
                Expanded(
                  child: Text(goals, style: textTheme.titleLarge),
                ),
                PrimaryButton.shrunk(
                  onPressed: _addGoal,
                  child: Row(
                    spacing: 6,
                    children: [
                      const Icon(Icons.add_rounded, size: 20),
                      Text(addGoal),
                    ],
                  ),
                ),
              ],
            ),
          ),
          switch (widget.bounded) {
            true => Expanded(child: body),
            false => body,
          },
        ],
      ),
    );
  }

  /// The same rows either way; only who owns the scrolling changes.
  Widget _rows(List<Goal> goals) {
    final rows = goals.map(
      (goal) => GoalRow(
        key: ValueKey(goal.id),
        goal: goal,
        workouts: widget.workouts,
        onEdit: () => _editGoal(goal),
        onDelete: () => Goals.of(context).remove(goal),
      ),
    );

    return switch (widget.bounded) {
      true => ListView(
        padding: .zero,
        children: rows.toList(),
      ),
      false => Column(
        crossAxisAlignment: .start,
        children: rows.toList(),
      ),
    };
  }

  Future<void> _editGoal(Goal goal) async {
    final state = Goals.of(context);
    final exercise = goalExercise(goal, Exercises.of(context));

    final edited = await showGoalTargetDialog(
      context,
      exercise: exercise,
      metric: goal.metric,
      goal: goal,
    );
    if (edited != null) await state.update(edited);
  }

  Future<void> _addGoal() async {
    final state = Goals.of(context);
    final goal = await showNewGoalDialog(context, _searchController, _focus);
    if (goal != null) await state.create(goal);
  }
}
