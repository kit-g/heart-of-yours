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

    Widget card(DashboardChart chart, Widget Function(Widget child) dragWrap) {
      return switch (chart) {
        ExerciseMetricChart(:final preference) => _Chart(
          preference: preference,
          settings: preferences,
          l: l,
          exercises: exercises,
          goals: goals,
          onDelete: charts.removePreference,
          exerciseHistoryService: service,
          dragWrap: dragWrap,
        ),
        TrainingChart chart => _TrainingCard(
          chart: chart,
          settings: preferences,
          onDelete: () => charts.remove(chart),
          onPeriod: (period) => charts.update(chart.withPeriod(period)),
          dragWrap: dragWrap,
        ),
        FrequencyChart chart => _FrequencyCard(
          chart: chart,
          exercises: exercises,
          onDelete: () => charts.remove(chart),
          dragWrap: dragWrap,
        ),
      };
    }

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
            child: card(
              charts[index],
              (child) => ReorderableDragStartListener(index: index, child: child),
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
                return KeyedSubtree(
                  key: ValueKey(charts[index].id),
                  child: card(
                    charts[index],
                    (child) => ReorderableGridDragStartListener(index: index, child: child),
                  ),
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
    return _CardFrame(child: _chart(context));
  }

  Widget _chart(BuildContext context) {
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);
    // the getter keeps its stale name until the next heart_models major: the
    // value is the exercise id, which is what the metrics queries key on
    final exerciseId = preference.exerciseName!;

    // The catalog is remote-authoritative and can lag a launch behind on first
    // run, so never block the card on the lookup: fall back to a placeholder
    // that just backs the empty/error decorations (the ghost service ignores
    // its other fields). Once the catalog arrives, the watch rebuild swaps in
    // the real exercise.
    final resolved = exercises.lookup(exerciseId);
    final exercise = resolved ?? Exercise(name: exerciseId, category: .barbell, target: .other);
    // the scale the exercise's own chart page plots on: its unit override, and
    // its category, which puts a carry in metres. Unresolved, the user's
    // defaults, until the catalog lands and the watch rebuilds this
    final unit = exercises.unitFor(exerciseId);
    final category = resolved?.category;
    final converter = preference.type.converter(settings, unit: unit, category: category);

    return ExerciseChart(
      // the rung being worked toward, per goal on this exercise and metric.
      // The axis grows to include it (see HistoryChart), so a target still far
      // off says so by how much of the plot it leaves below it.
      thresholds: [
        for (final goal in goalsOnChart(
          goals,
          exerciseId: exerciseId,
          metric: preference.type,
        ))
          ...goalThresholds(
            context,
            goal,
            metric: preference.type,
            settings: settings,
            unit: unit,
            category: category,
            nextOnly: true,
          ),
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
      callback: () => exercises.getChartExerciseMetics(preference.type, exerciseId),
      refreshKey: (exerciseId, preference.type),
      customLabel: _CardHeader(
        // before the catalog resolves there is no name worth showing — an id
        // is not copy
        title: '${resolved?.name ?? '…'} - ${preference.type.title(context, settings, unit: unit, category: category)}',
        onDelete: () => onDelete(preference),
        dragWrap: dragWrap,
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

/// The outline every dashboard card sits in.
class _CardFrame extends StatelessWidget {
  final Widget child;

  const new({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: .all(color: Theme.of(context).dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: Padding(
        padding: const .all(8.0),
        child: child,
      ),
    );
  }
}

/// A dashboard card's title bar: the drag handle, what the card shows, and
/// the button that takes it off the dashboard.
class _CardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onDelete;
  final Widget Function(Widget child)? dragWrap;

  /// A control of the card's own, beside the close button.
  final Widget? action;

  const new({required this.title, required this.onDelete, this.dragWrap, this.action});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    return Row(
      children: [
        if (dragWrap case final wrap?) ...[
          wrap(Icon(Icons.drag_indicator, size: 20, color: color)),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(title, maxLines: 1, overflow: .ellipsis),
        ),
        ?action,
        FeedbackButton.circular(
          tooltip: L.of(context).delete,
          onPressed: onDelete,
          child: Padding(
            padding: const .all(1.0),
            child: Icon(Icons.close_rounded, size: 20, color: color),
          ),
        ),
      ],
    );
  }
}

/// The height a dashboard card's plot is given, the one [ExerciseChart] uses:
/// a grid cell shorter than this squeezes it, a list row never stretches it.
const _cardHeight = 300.0;

/// A total across every exercise, per week or per month (#137): volume,
/// working sets, or the average workout's length.
class _TrainingCard extends StatelessWidget {
  final TrainingChart chart;
  final Preferences settings;
  final VoidCallback onDelete;
  final ValueChanged<ChartPeriod> onPeriod;
  final Widget Function(Widget child)? dragWrap;

  const new({
    required this.chart,
    required this.settings,
    required this.onDelete,
    required this.onPeriod,
    this.dragWrap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final TrainingChart(:metric, :period) = chart;
    final firstWeekday = firstWeekdayOf(context, listen: true);
    // replaced whenever a workout is finished or deleted: the totals go stale
    final workouts = context.select<Stats, WorkoutAggregation>((stats) => stats.workouts);
    final title = '${l.chartAllExercises} - ${metric.title(context, settings)}';

    // one line, as every card's is: the plot gives its title a fixed strip,
    // and a grid cell has no height to spare for a row of choices
    final header = _CardHeader(
      title: title,
      onDelete: onDelete,
      dragWrap: dragWrap,
      action: _PeriodButton(period: period, onPeriod: onPeriod),
    );

    Widget quiet(String heading, String body) {
      return SizedBox(
        height: _cardHeight,
        child: Column(
          children: [
            header,
            Expanded(
              child: Center(
                child: Padding(
                  padding: const .symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Text(heading, textAlign: .center, style: textTheme.titleMedium),
                      Text(body, textAlign: .center, style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _CardFrame(
      child: ExerciseChart(
        label: title,
        customLabel: header,
        callback: () => Stats.of(context).getTrainingSeries(metric, period, firstWeekday: firstWeekday),
        refreshKey: (metric, period, firstWeekday, workouts),
        converter: metric.converter(settings),
        getLeftLabel: metric.leftLabel(context, textTheme.bodySmall),
        getTooltip: metric.tooltip(context),
        yStepCandidates: metric.yStepCandidates,
        color: metric.color(context),
        dateLabel: switch (period) {
          .week => l.dayAndMonth,
          .month => DateFormat.MMM(Localizations.localeOf(context).toString()).format,
        },
        emptyState: quiet(l.emptyChartStateTitle, l.emptyChartStateBody),
        errorState: quiet(l.errorExerciseHistoryTitle, l.errorExerciseHistoryBody),
        loadingState: const _LoadingState(),
      ),
    );
  }
}

/// A training chart's week-or-month choice: a menu off the card's title bar,
/// its icon saying which one the chart shows.
class _PeriodButton extends StatelessWidget {
  final ChartPeriod period;
  final ValueChanged<ChartPeriod> onPeriod;

  const new({required this.period, required this.onPeriod});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final color = Theme.of(context).dividerColor;
    String copy(ChartPeriod each) {
      return switch (each) {
        .week => l.chartByWeek,
        .month => l.chartByMonth,
      };
    }

    return FeedbackButton.circular(
      // the choice the chart is showing, so a screen reader says what it is
      tooltip: l.chartPeriod(copy(period)),
      onPressed: () async {
        final box = context.findRenderObject()! as RenderBox;
        final corner = box.localToGlobal(Offset(0, box.size.height));
        final picked = await showMenu<ChartPeriod>(
          context: context,
          position: RelativeRect.fromLTRB(corner.dx, corner.dy, corner.dx + box.size.width, corner.dy),
          constraints: const BoxConstraints.tightFor(width: 168),
          items: [
            for (final each in ChartPeriod.values)
              CheckedPopupMenuItem<ChartPeriod>(value: each, checked: each == period, child: Text(copy(each))),
          ],
        );
        if (picked case ChartPeriod picked when picked != period) onPeriod(picked);
      },
      child: Padding(
        padding: const .all(1.0),
        child: Icon(
          switch (period) {
            .week => Icons.view_week_outlined,
            .month => Icons.calendar_month_outlined,
          },
          size: 20,
          color: color,
        ),
      ),
    );
  }
}

/// The days one exercise was trained on over the last [frequencyWeeks] weeks,
/// as a calendar heatmap (#137): a column a week, the user's first weekday on
/// top, each day shaded by its working sets.
class _FrequencyCard extends StatefulWidget {
  final FrequencyChart chart;
  final Exercises exercises;
  final VoidCallback onDelete;
  final Widget Function(Widget child)? dragWrap;

  const new({
    required this.chart,
    required this.exercises,
    required this.onDelete,
    this.dragWrap,
  });

  @override
  State<_FrequencyCard> createState() => _FrequencyCardState();
}

class _FrequencyCardState extends State<_FrequencyCard> {
  Future<Map<DateTime, int>>? _days;
  Object? _readFor;

  /// One read per exercise, week and history: a rebuild for anything else
  /// (theme, a sibling card) keeps the cells it has.
  Future<Map<DateTime, int>> _read(int firstWeekday, WorkoutAggregation workouts) {
    final key = (widget.chart.exerciseId, firstWeekday, workouts);
    if (key != _readFor) {
      _readFor = key;
      _days = Stats.of(context).getExerciseDays(widget.chart.exerciseId, firstWeekday: firstWeekday);
    }
    return _days!;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final firstWeekday = firstWeekdayOf(context, listen: true);
    final workouts = context.select<Stats, WorkoutAggregation>((stats) => stats.workouts);
    // an id is not copy: until the catalog resolves, the name waits
    final name = widget.exercises.lookup(widget.chart.exerciseId)?.name ?? '…';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeks = lastWeeksOf(frequencyWeeks, now: now, firstWeekday: firstWeekday);

    return _CardFrame(
      child: SizedBox(
        height: _cardHeight,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            _CardHeader(
              title: '$name - ${l.chartFrequency}',
              onDelete: widget.onDelete,
              dragWrap: widget.dragWrap,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<Map<DateTime, int>>(
                future: _read(firstWeekday, workouts),
                builder: (context, snapshot) {
                  return switch (snapshot.data) {
                    Map<DateTime, int> days => Semantics(
                      label: l.chartFrequencySummary(name, days.length, frequencyWeeks),
                      child: ExcludeSemantics(
                        child: _DaysHeatmap(weeks: weeks, days: days, today: today),
                      ),
                    ),
                    null => const SizedBox.shrink(),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gap between two heatmap cells.
const _cellGap = 3.0;

/// The largest a heatmap cell gets: past it, a wide card centres the grid
/// rather than growing squares the size of buttons.
const _maxCell = 28.0;

/// Room for the weekday initials beside the grid.
const _weekdayGutter = 20.0;

class _DaysHeatmap extends StatelessWidget {
  /// The first day of each week shown, oldest first.
  final List<DateTime> weeks;

  /// Working sets per local day; a day missing was not trained.
  final Map<DateTime, int> days;
  final DateTime today;

  const new({required this.weeks, required this.days, required this.today});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final most = days.values.fold(0, max);
    final initial = DateFormat('EEEEE', Localizations.localeOf(context).toString());

    // measured: in a grid cell the card is a fraction of the window, and the
    // squares are whatever both directions leave room for, capped
    return LayoutBuilder(
      builder: (context, constraints) {
        final across = (constraints.maxWidth - _weekdayGutter) / weeks.length;
        final down = constraints.maxHeight / DateTime.daysPerWeek;
        final cell = [across, down, _maxCell].reduce(min) - _cellGap;
        if (cell <= 0) return const SizedBox.shrink();

        Widget square(DateTime day) {
          final sets = days[day] ?? 0;
          return SizedBox.square(
            dimension: cell,
            child: switch ((day.isAfter(today), sets)) {
              (true, _) => null,
              (false, 0) => Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: heatmapEmpty(colorScheme), shape: .circle),
                  child: const SizedBox.square(dimension: 3),
                ),
              ),
              (false, _) => DecoratedBox(
                decoration: BoxDecoration(
                  color: heatmapShade(colorScheme, colorScheme.surface, sets / most),
                  borderRadius: const .all(.circular(4)),
                ),
              ),
            },
          );
        }

        return Center(
          child: Row(
            mainAxisSize: .min,
            children: [
              SizedBox(
                width: _weekdayGutter,
                child: Column(
                  mainAxisSize: .min,
                  children: List.generate(DateTime.daysPerWeek, (row) {
                    return Padding(
                      padding: const .all(_cellGap / 2),
                      child: SizedBox(
                        height: cell,
                        child: Center(
                          child: Text(
                            initial.format(weeks.first.add(Duration(days: row))),
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              for (final week in weeks)
                Column(
                  mainAxisSize: .min,
                  children: List.generate(DateTime.daysPerWeek, (row) {
                    return Padding(
                      padding: const .all(_cellGap / 2),
                      child: square(DateTime(week.year, week.month, week.day + row)),
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }
}
