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
      .compact => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const .symmetric(horizontal: 16.0, vertical: 2),
            child: _Chart(
              preference: charts[index],
              settings: preferences,
              l: l,
              exercises: exercises,
              onDelete: (chart) => charts.removePreference(chart),
              exerciseHistoryService: service,
            ),
          ),
          childCount: length,
        ),
      ),
      .wide => SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _Chart(
            preference: charts[index],
            settings: preferences,
            exercises: exercises,
            onDelete: (chart) => charts.removePreference(chart),
            l: l,
            exerciseHistoryService: service,
          ),
          childCount: length,
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

  const _Chart({
    required this.preference,
    required this.settings,
    required this.l,
    required this.exercises,
    required this.onDelete,
    required this.exerciseHistoryService,
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

    // the exercise catalog may still be loading; the chart data is queried by
    // name (no Exercise object needed), but the empty/error states are — show a
    // per-card loader until it lands, then this rebuilds via the watch
    return switch (exercises.lookup(exerciseName)) {
      null => const SizedBox(height: 300, child: _LoadingState()),
      final exercise => ExerciseChart(
        emptyState: _EmptyState(
          exercise: exercise,
          exerciseHistoryService: exerciseHistoryService,
          onDelete: onDelete,
          iconColor: dividerColor,
          l: l,
          preference: preference,
          textTheme: textTheme,
          axisConverter: converter,
        ),
        callback: () => exercises.getChartExerciseMetics(preference.type, exerciseName),
        customLabel: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Text('$exerciseName - ${preference.type.title(context, settings)}'),
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
        ),
        loadingState: const _LoadingState(),
      ),
    };
  }
}
