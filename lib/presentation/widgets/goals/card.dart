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
    final L(:goals, :addGoal, :noGoalsYet, :goalsAtCapacity) = L.of(context);
    final state = Goals.watch(context);

    final body = Container(
      // clipped: a swiping row paints edge to edge now, and without this the
      // red would square off the block's top and bottom corners
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        color: colorScheme.surfaceContainer,
      ),
      child: Padding(
        // vertical only: a swiping row's background runs the full width of this
        // block, so the inset it sits inside belongs to the row, not to here
        padding: const .symmetric(vertical: 8),
        child: switch (state.isEmpty) {
          true => Align(
            alignment: .topLeft,
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
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
                // At the cap the button goes rather than staying and failing:
                // the server refuses the create, and a dead button that reports
                // an error afterwards is worse than one that is not offered.
                // The mark is there for anyone who wonders where it went.
                switch (state.isAtCapacity) {
                  true => Tooltip(
                    key: AppKeys.goalsAtCapacity,
                    message: goalsAtCapacity,
                    // tap, not hover: on a phone there is nothing to hover with
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  false => PrimaryButton.shrunk(
                    onPressed: _addGoal,
                    child: Row(
                      spacing: 6,
                      children: [
                        const Icon(Icons.add_rounded, size: 20),
                        Text(addGoal),
                      ],
                    ),
                  ),
                },
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
        key: AppKeys.goalRow(goal.id),
        goal: goal,
        workouts: widget.workouts,
        onEdit: () => _openGoal(goal),
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

  /// Opens the goal rather than a field to edit: a ladder, its deadlines and
  /// what has already fallen do not fit in a dialog.
  ///
  /// A sheet on both layouts rather than a route, so the card it came from
  /// stays behind it — on a tablet the goal is one tile of a dashboard, and
  /// replacing the whole screen to look at it loses that context.
  Future<void> _openGoal(Goal goal) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      // `isScrollControlled` lets the sheet reach the very top of the screen,
      // which on a phone with a cutout means the title sits under the island.
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          maxChildSize: .95,
          builder: (context, controller) {
            return GoalDetail(
              goal: goal,
              workouts: widget.workouts,
              scrollController: controller,
              onClose: () => Navigator.of(context).pop(),
            );
          },
        );
      },
    );
  }

  Future<void> _addGoal() async {
    final state = Goals.of(context);
    final goal = await showNewGoalDialog(context, _searchController, _focus);
    if (goal == null) return;

    try {
      await state.create(goal);
    } on GoalRejected catch (rejection) {
      // The goal is already gone again — a refused create is undone rather than
      // left to retry — so this is the only chance to say why it vanished. The
      // cap is the one refusal a correct request can hit, when another device
      // filled the account up.
      if (!mounted) return;
      snack(
        context,
        switch (rejection.isAtCapacity) {
          true => L.of(context).goalsAtCapacity,
          false => rejection.toString(),
        },
      );
    }
  }
}
