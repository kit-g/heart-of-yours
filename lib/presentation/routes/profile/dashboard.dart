part of 'profile.dart';

class _Dashboard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final layout = LayoutProvider.of(context);
    final charts = Charts.watch(context);
    final preferences = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    // watched, not read: a rung reached or a goal deleted redraws the lines
    // across every chart it applies to
    final goals = Goals.watch(context);
    final l = L.of(context);
    final length = charts.length;
    final service = FakeExerciseHistoryService();

    if (!charts.initialized) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: .symmetric(vertical: 16),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return switch (layout) {
      // drag a card by the handle in its title bar; order persists via Charts.reorder
      .compact => SliverReorderableList(
        itemCount: length,
        onReorderItem: charts.reorder,
        itemBuilder: (context, index) {
          return Padding(
            key: ValueKey(charts[index].id),
            padding: const .symmetric(horizontal: 16.0, vertical: 2),
            child: _Chart(
              preference: charts[index],
              settings: preferences,
              l: l,
              exercises: exercises,
              goals: goals,
              onDelete: (chart) => charts.removePreference(chart),
              exerciseHistoryService: service,
              dragWrap: (child) => ReorderableDragStartListener(index: index, child: child),
            ),
          );
        },
      ),
      // same handle-drag reorder for the iPad/laptop grid; the horizontal inset
      // matches the rest of the profile column (16)
      .wide => SliverPadding(
        padding: const .only(left: 16, right: 16, bottom: 8),
        // Counted from the width the grid is handed rather than the device's
        // orientation. Orientation says nothing about a browser window being
        // dragged wider, and nothing about how much of the window this grid
        // actually got. At iPad sizes it lands on the same 2 and 3 the
        // orientation switch produced.
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            return SliverReorderableGrid(
              itemCount: length,
              onReorder: charts.reorder,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnsFor(constraints.crossAxisExtent, maxExtent: _maxChartCardWidth),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (_, index) {
                return _Chart(
                  key: ValueKey(charts[index].id),
                  preference: charts[index],
                  settings: preferences,
                  exercises: exercises,
                  goals: goals,
                  onDelete: (chart) => charts.removePreference(chart),
                  l: l,
                  exerciseHistoryService: service,
                  dragWrap: (child) => ReorderableGridDragStartListener(index: index, child: child),
                );
              },
            );
          },
        ),
      ),
    };
  }
}

class _Chart extends StatelessWidget {
  final ChartPreference preference;
  final Preferences settings;
  final Exercises exercises;

  /// Every goal the user has; the ones this chart's metric and exercise match
  /// are drawn across it.
  final Iterable<Goal> goals;

  final void Function(ChartPreference) onDelete;
  final ExerciseHistoryService exerciseHistoryService;
  final L l;

  /// Wraps a widget in the layout's drag-start listener (list vs grid). The
  /// title bar becomes the drag handle so it doesn't fight the chart's own
  /// touch handling on the plot.
  final Widget Function(Widget child)? dragWrap;

  const new({
    super.key,
    required this.preference,
    required this.settings,
    required this.l,
    required this.exercises,
    required this.goals,
    required this.onDelete,
    required this.exerciseHistoryService,
    this.dragWrap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:dividerColor) = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: .all(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: Padding(
        padding: const .all(8.0),
        child: _chart(context),
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);
    final exerciseName = preference.exerciseName!;
    final converter = _converter(preference.type, settings);

    // A chart's data is keyed by exercise *name* (see the metrics queries), not
    // the exercise catalog — which is remote-authoritative and can lag a launch
    // behind on first run. So never block the card on the lookup: fall back to a
    // name-only placeholder that just backs the empty/error decorations (the
    // ghost service ignores its other fields). Once the catalog arrives, the
    // watch rebuild swaps in the real exercise.
    final exercise = exercises.lookup(exerciseName) ?? Exercise(name: exerciseName, category: .barbell, target: .other);

    return ExerciseChart(
      // the rung being worked toward, per goal on this exercise and metric.
      // The axis grows to include it (see HistoryChart), so a target still far
      // off says so by how much of the plot it leaves below it.
      thresholds: [
        for (final goal in goalsOnChart(
          goals,
          exerciseName: exerciseName,
          metric: preference.type,
          exercises: exercises,
        ))
          ...goalThresholds(context, goal, metric: preference.type, settings: settings, nextOnly: true),
      ],
      emptyState: _EmptyState(
        exercise: exercise,
        exerciseHistoryService: exerciseHistoryService,
        onDelete: onDelete,
        iconColor: dividerColor,
        l: l,
        preference: preference,
        textTheme: textTheme,
        axisConverter: converter,
        dragWrap: dragWrap,
      ),
      callback: () => exercises.getChartExerciseMetics(preference.type, exerciseName),
      refreshKey: (exerciseName, preference.type),
      customLabel: Row(
        children: [
          if (dragWrap case final wrap?) ...[
            wrap(Icon(Icons.drag_indicator, size: 20, color: dividerColor)),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              '$exerciseName - ${preference.type.title(context, settings)}',
              maxLines: 1,
              overflow: .ellipsis,
            ),
          ),
          FeedbackButton.circular(
            tooltip: l.delete,
            onPressed: () => onDelete(preference),
            child: Padding(
              padding: const .all(1.0),
              child: Icon(
                Icons.close_rounded,
                size: 20,
                color: dividerColor,
              ),
            ),
          ),
        ],
      ),
      converter: converter,
      getLeftLabel: _getLeftLabel(preference.type, textTheme.bodySmall),
      getTooltip: preference.type.tooltip,
      yStepCandidates: preference.type.yStepCandidates,
      color: preference.type.color(context),
      errorState: _ErrorState(
        exercise: exercise,
        exerciseHistoryService: exerciseHistoryService,
        onDelete: onDelete,
        iconColor: dividerColor,
        l: l,
        preference: preference,
        textTheme: textTheme,
        axisConverter: converter,
        dragWrap: dragWrap,
      ),
      loadingState: const _LoadingState(),
    );
  }
}
