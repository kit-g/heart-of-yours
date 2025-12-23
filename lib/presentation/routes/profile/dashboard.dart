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
    Widget weightLabel(double y) {
      return switch (y % 2) {
        0 => Text(
          y.toInt().toString(),
          style: textTheme.bodySmall,
        ),
        _ => const SizedBox.shrink(),
      };
    }

    switch (preference.type) {
      case .exerciseWeight:
        final exerciseName = preference.exerciseName!;
        final exercise = exercises.lookup(exerciseName)!;
        return ExerciseChart(
          emptyState: _EmptyState(
            exercise: exercise,
            exerciseHistoryService: exerciseHistoryService,
            onDelete: onDelete,
            iconColor: dividerColor,
            l: l,
            preference: preference,
            textTheme: textTheme,
          ),
          callback: () => exercises.getWeightHistory(exercise),
          customLabel: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text('$exerciseName - ${l.weightUnit}'),
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
          converter: (v) => settings.weightValue(v),
          getLeftLabel: weightLabel,
          errorState: const _ErrorState(),
        );
      case .exerciseReps:
        return throw UnimplementedError();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final Exercise exercise;
  final ChartPreference preference;
  final ExerciseHistoryService exerciseHistoryService;
  final Color? iconColor;
  final void Function(ChartPreference) onDelete;
  final L l;
  final TextTheme? textTheme;

  const _EmptyState({
    required this.exercise,
    required this.preference,
    required this.exerciseHistoryService,
    required this.onDelete,
    required this.l,
    required this.iconColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: .center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: .4),
            BlendMode.modulate,
          ),
          child: ExerciseChart(
            emptyState: const SizedBox.shrink(),
            callback: () => exerciseHistoryService.getWeightHistory('', exercise),
            converter: (v) => v.toDouble(),
            errorState: const SizedBox.shrink(),
            customLabel: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text('${exercise.name} - ${l.weightUnit}'),
                FeedbackButton.circular(
                  tooltip: l.delete,
                  onPressed: () => onDelete(preference),
                  child: Padding(
                    padding: const .all(1.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const .all(32.0),
          child: Column(
            children: [
              Text(
                l.emptyChartStateTitle,
                textAlign: .center,
                style: textTheme?.titleMedium,
              ),
              Text(
                l.emptyChartStateBody,
                textAlign: .center,
                style: textTheme?.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Text('error');
  }
}
