part of 'profile.dart';

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final layout = LayoutProvider.of(context);
    final charts = Charts.watch(context);
    final preferences = Preferences.watch(context);
    final exercises = Exercises.watch(context);
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
        sliver: SliverReorderableGrid(
          itemCount: length,
          onReorder: charts.reorder,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: switch (MediaQuery.orientationOf(context)) {
              .portrait => 2,
              .landscape => 3,
            },
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
              onDelete: (chart) => charts.removePreference(chart),
              l: l,
              exerciseHistoryService: service,
              dragWrap: (child) => ReorderableGridDragStartListener(index: index, child: child),
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
  final void Function(ChartPreference) onDelete;
  final ExerciseHistoryService exerciseHistoryService;
  final L l;

  /// Wraps a widget in the layout's drag-start listener (list vs grid). The
  /// title bar becomes the drag handle so it doesn't fight the chart's own
  /// touch handling on the plot.
  final Widget Function(Widget child)? dragWrap;

  const _Chart({
    super.key,
    required this.preference,
    required this.settings,
    required this.l,
    required this.exercises,
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
