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

  const new({
    super.key,
    required this.workouts,
    this.bounded = false,
    this.headerHeight = 44,
  });

  @override
  State<GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends State<GoalsCard> {
  ({int workouts, LensSetsReader read})? _lens;

  /// One reader for every row, renewed when the rows re-read — on the same
  /// signal [GoalRow] re-reads on, the workout count.
  LensSetsReader _lensSets() {
    final workouts = widget.workouts.workoutCount;
    if (_lens case (workouts: final shared, :final read) when shared == workouts) return read;
    final read = sharedLensSets(Stats.of(context).getLensSets);
    _lens = (workouts: workouts, read: read);
    return read;
  }

  /// Owned here rather than per-dialog. Disposing them when a dialog's future
  /// completes would pull them out from under a field still animating away.
  final _searchController = TextEditingController();
  final _focus = FocusNode();

  /// Which face is up. Local to the card — nothing outside it cares, and it
  /// resets to the live list whenever the profile is rebuilt, which is the
  /// right default every time.
  bool _showsAchieved = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(
      :goals,
      :addGoal,
      :noGoalsYet,
      :goalsAtCapacity,
      :goalsViewAchieved,
      :goalsAchievedTitle,
      :goalsViewActive,
    ) = L.of(
      context,
    );
    final state = Goals.watch(context);
    // what a running program implies, beside what the user set (#353)
    final feeds = programFeeds(context);
    final implied = impliedBy(feeds, state.all);

    // Nothing to turn to, so nothing offers to: the button appears with the
    // first achieved goal and goes with the last.
    if (!state.hasArchived && _showsAchieved) _showsAchieved = false;

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
        child: switch (state.isEmpty && implied.isEmpty) {
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
          false => _rows(state.all, feeds: feeds, implied: implied),
        },
      ),
    );

    final achieved = Container(
      clipBehavior: .antiAlias,
      decoration: BoxDecoration(
        borderRadius: const .all(.circular(12)),
        // tinted rather than neutral: turning the card over should land you
        // somewhere that plainly is not the list you left. Derived from the
        // seed, so it holds under whatever accent the user picked.
        color: colorScheme.secondaryContainer,
      ),
      child: Padding(
        padding: const .symmetric(vertical: 8),
        child: _rows(state.archived),
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
          ConstrainedBox(
            // matches the aggregation chart beside it: the shared height is a
            // floor so the two headings line up, not a clip
            constraints: BoxConstraints(minHeight: widget.headerHeight),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: _flipDuration,
                    switchInCurve: _flipCurve,
                    // the switcher stacks its children centred, which pushed
                    // the heading off the left edge every other tile lines up on
                    layoutBuilder: (current, previous) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [...previous, ?current],
                      );
                    },
                    child: Text(
                      _showsAchieved ? goalsAchievedTitle : goals,
                      key: ValueKey(_showsAchieved),
                      style: textTheme.titleLarge,
                    ),
                  ),
                ),
                // Only ever offered when there is something on the other side.
                if (state.hasArchived)
                  PrimaryButton.shrunk(
                    key: _showsAchieved ? AppKeys.goalsViewActive : AppKeys.goalsViewAchieved,
                    backgroundColor: colorScheme.secondaryContainer,
                    onPressed: () => setState(() => _showsAchieved = !_showsAchieved),
                    child: Text(
                      _showsAchieved ? goalsViewActive : goalsViewAchieved,
                      style: TextStyle(color: colorScheme.onSecondaryContainer),
                    ),
                  ),
                // At the cap the button goes rather than staying and failing:
                // the server refuses the create, and a dead button that reports
                // an error afterwards is worse than one that is not offered.
                // The mark is there for anyone who wonders where it went.
                AnimatedSize(
                  duration: _flipDuration,
                  curve: _flipCurve,
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    duration: _flipDuration,
                    curve: _flipCurve,
                    opacity: _showsAchieved ? 0 : 1,
                    child: switch (_showsAchieved) {
                      // width collapses to nothing, so the flip button slides
                      // across into the space rather than jumping
                      true => const SizedBox.shrink(),
                      // the leading gap lives in here so it collapses too
                      false => switch (state.isAtCapacity) {
                        true => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Tooltip(
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
                        ),
                        false => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: PrimaryButton.shrunk(
                            onPressed: _addGoal,
                            child: Row(
                              spacing: 6,
                              children: [
                                const Icon(Icons.add_rounded, size: 20),
                                Text(addGoal),
                              ],
                            ),
                          ),
                        ),
                      },
                    },
                  ),
                ),
              ],
            ),
          ),
          switch (widget.bounded) {
            true => Expanded(
              child: _FlipCard(showsBack: _showsAchieved, front: body, back: achieved),
            ),
            false => _FlipCard(showsBack: _showsAchieved, front: body, back: achieved),
          },
        ],
      ),
    );
  }

  /// The same rows either way; only who owns the scrolling changes. The
  /// goals running programs imply (#353) come after the user's own, labelled
  /// with their program, and open it rather than a goal.
  Widget _rows(List<Goal> goals, {List<ProgramFeed> feeds = const [], List<ImpliedGoal> implied = const []}) {
    final lensSets = _lensSets();
    // the user's own weekly workouts goal, while a program's cadence
    // overrides it: not shown as a row, never edited, said under the program's
    final running = runningIn(feeds);
    final paused = goals.where((goal) => pausedByPrograms(goal, running)).toList();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final rows = [
      for (final goal in goals.where((goal) => !paused.contains(goal)))
        GoalRow(
          key: AppKeys.goalRow(goal.id),
          goal: goal,
          workouts: widget.workouts,
          lensSets: lensSets,
          feeds: feeds,
          onEdit: () => _openGoal(goal),
          onDelete: () => Goals.of(context).remove(goal),
        ),
      for (final ImpliedGoal(:goal, :program) in implied)
        GoalRow(
          key: AppKeys.goalRow(goal.id),
          goal: goal,
          workouts: widget.workouts,
          lensSets: lensSets,
          feeds: feeds,
          from: program.name,
          onEdit: () => HeartRouter.of(context).pushProgramOver(program.id!),
        ),
      for (final ImpliedGoal(:goal, :program) in implied)
        if (goal.metric == .workouts && goal.cadence == .week)
          for (final own in paused)
            Padding(
              key: AppKeys.goalSetAside(own.id),
              padding: const .fromLTRB(16, 0, 16, 8),
              child: Text(
                L.of(context).goalPausedByProgram(own.stages.firstOrNull?.target.toInt() ?? 0, program.name),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
    ];

    return switch (widget.bounded) {
      true => ListView(
        padding: .zero,
        children: rows,
      ),
      false => Column(
        crossAxisAlignment: .start,
        children: rows,
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
