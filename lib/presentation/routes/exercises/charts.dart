part of 'exercises.dart';

class _Charts extends StatelessWidget {
  final Exercise exercise;

  const new({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final prefs = Preferences.watch(context);
    final exercises = Exercises.of(context);
    final unit = Exercises.watch(context).unitFor(exercise.id);
    // watched: reaching a rung redraws the line on the chart that measures it
    final goals = Goals.watch(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final style = textTheme.bodySmall;

    // Every metric relevant to this exercise's category — the same set the
    // dashboard offers when adding a chart, now surfaced per exercise.
    final types = ChartPreferenceType.chartsByExerciseCategory(exercise.category);
    // a program the user follows trains it: said once, above the charts
    final program = _programOf(context);

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: types.length + (program == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, item) {
        if (program != null && item == 0) return _InProgram(program: program);
        final index = program == null ? item : item - 1;
        final type = types[index];
        final title = type.title(context, prefs, unit: unit, category: exercise.category);
        return ExerciseChart(
          // the rung being worked toward, for every goal on this exercise and
          // metric. Converted on this exercise's own scale, the one the series
          // beside it is plotted in — the user default would land elsewhere.
          thresholds: [
            for (final goal in goalsOnChart(goals, exerciseId: exercise.id, metric: type))
              ...goalThresholds(
                context,
                goal,
                metric: type,
                settings: prefs,
                unit: unit,
                category: exercise.category,
                nextOnly: true,
              ),
          ],
          // only the first chart carries the full "no data yet" hint; the rest
          // stay quiet so an empty exercise doesn't repeat it N times
          emptyState: index == 0 ? const _EmptyState() : const SizedBox.shrink(),
          callback: () => exercises.getChartExerciseMetics(type, exercise.id, limit: _exerciseHistoryLimit),
          timeline: true,
          firstWeekday: prefs.firstWeekday,
          refreshKey: (type, exercise.id),
          // the string still travels as [label] — it feeds the chart's
          // spoken summary — while the row adds the dashboard toggle
          label: title,
          customLabel: Row(
            children: [
              Expanded(
                child: Text(title, style: textTheme.titleMedium, maxLines: 1, overflow: .ellipsis),
              ),
              _DashboardToggle(exercise: exercise, type: type),
            ],
          ),
          converter: type.converter(prefs, unit: unit, category: exercise.category),
          getLeftLabel: type.leftLabel(style),
          getTooltip: type.tooltip,
          yStepCandidates: type.yStepCandidates,
          color: type.color(context),
          errorState: const _ErrorState(),
        );
      },
    );
  }
}

extension on _Charts {
  /// The first program the user follows whose sessions hold [exercise]; null
  /// while Programs is off or none does.
  Program? _programOf(BuildContext context) {
    if (!Preferences.watch(context).isOn(.programs)) return null;
    final following = {for (final program in Programs.watch(context).following) program.id: program};
    return Templates.watch(context)
        .where((session) => following.containsKey(session.programId))
        .where((session) => session.any((each) => each.exercise.id == exercise.id))
        .map((session) => following[session.programId])
        .nonNulls
        .firstOrNull;
  }
}

/// A quiet line over the charts: this exercise is in a program the user
/// follows, and the way to it.
class _InProgram extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = colorScheme.onSurfaceVariant;
    return Semantics(
      link: true,
      child: InkWell(
        key: AppKeys.exerciseInProgram,
        borderRadius: const .all(.circular(8)),
        onTap: () => HeartRouter.of(context).pushProgramOver(program.id!),
        child: Padding(
          padding: const .symmetric(horizontal: 8, vertical: 8),
          child: Row(
            spacing: 8,
            children: [
              Icon(Icons.event_repeat_rounded, size: 16, color: muted),
              Expanded(
                child: Text(
                  L.of(context).exerciseInProgram(program.name),
                  style: textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puts this exercise+metric chart on the profile dashboard, or takes it back
/// off — the same [ChartPreference] the profile's "New chart" dialog builds,
/// minus the two-step picker, offered right where the metric is on screen.
class _DashboardToggle extends StatelessWidget {
  final Exercise exercise;
  final ChartPreferenceType type;

  const new({required this.exercise, required this.type});

  @override
  Widget build(BuildContext context) {
    // watched: adding or removing the card flips this button in place
    final charts = Charts.watch(context);
    final L(:addChartToProfile, :removeChartFromProfile, :chartAddedToProfile) = L.of(context);

    // the dashboard card this chart would duplicate, if it is already there.
    // The preference's getter keeps its stale name — the value is the
    // exercise id, the identity that survives localization.
    final existing = charts.exerciseCharts
        .where((each) => each.exerciseName == exercise.id && each.type == type)
        .firstOrNull;

    return switch (existing) {
      null => FeedbackButton.circular(
        tooltip: addChartToProfile,
        onPressed: () {
          charts.addPreference(.exercise(exercise.id, type));
          // the result lives on another tab, so confirm it landed
          snack(context, chartAddedToProfile);
        },
        child: const Padding(
          padding: .all(2.0),
          child: Icon(Icons.addchart_rounded, size: 20),
        ),
      ),
      final preference => FeedbackButton.circular(
        tooltip: removeChartFromProfile,
        onPressed: () => charts.removePreference(preference),
        child: Padding(
          padding: const .all(2.0),
          child: Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    };
  }
}

/// Sessions fetched for a per-exercise chart.
///
/// Was 30 — a few weeks for anyone training seriously, which made the chart a
/// snapshot rather than a history. The chart travels through time now, so the
/// cap only has to stay ahead of what anyone can plausibly have logged: five
/// sessions a week for a decade is 2600.
const _exerciseHistoryLimit = 5000;
