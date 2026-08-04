part of 'profile.dart';

/// The profile's own zone: cards the page decides on, above the exercise chart
/// grid the user curates.
///
/// It exists to give the workouts-per-week chart somewhere to live that is not
/// a full-width band. On a phone that changes little; on a tablet it halves the
/// chart and puts the goals card in the space that was empty before. Health
/// cards belong here too, alongside goals rather than among the exercise charts.
class _ProfileArea extends StatelessWidget {
  final WorkoutAggregation workouts;
  final Widget emptyState;

  const _ProfileArea({
    required this.workouts,
    required this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    final chart = workouts.isEmpty ? emptyState : WorkoutsAggregationChart(workouts: workouts);

    // The row owns the insets so this band lines up with the chart grid below
    // it: 16 at the outer edges, 10 between. Letting each tile pad itself put
    // the outer edges at 32 and the gutter at 32, against the grid's 16 and 10.
    return SliverToBoxAdapter(
      child: switch (LayoutProvider.of(context)) {
        // in a scrolling column the card can be as tall as it likes
        .compact => Padding(
          padding: const .symmetric(horizontal: 16),
          child: Column(
            children: [
              chart,
              _GoalsCard(workouts: workouts),
            ],
          ),
        ),
        // Side by side, so the chart stops owning a whole row on its own. The
        // card takes the chart's height rule, which lines the two titles up
        // and — more importantly — stops the card growing without limit as
        // goals are added. Past that height its list scrolls.
        .wide => Padding(
          padding: const .symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: .start,
            spacing: 10,
            children: [
              Expanded(child: chart),
              Expanded(
                child: LayoutBuilder(
                  // the chart's own height rule, so the two tiles are the same
                  // box; a part-empty panel beside it beats a short one floating
                  builder: (_, constraints) => SizedBox(
                    height: min(constraints.maxWidth * 4 / 5, _maxChartHeight),
                    child: _GoalsCard(workouts: workouts, bounded: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

/// One card listing every goal, rather than one card per goal — a handful of
/// goals would otherwise fill the dashboard with near-empty tiles.
class _GoalsCard extends StatefulWidget {
  final WorkoutAggregation workouts;

  /// Whether the card has been given a fixed height and must scroll its list
  /// rather than grow. True in the tablet row, false in the phone column.
  final bool bounded;

  const _GoalsCard({required this.workouts, this.bounded = false});

  @override
  State<_GoalsCard> createState() => _GoalsCardState();
}

class _GoalsCardState extends State<_GoalsCard> {
  /// Owned here rather than per-dialog, the way [_ProfilePageState] owns the
  /// ones the chart picker uses. Disposing them when a dialog's future
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
    // `titleLarge` over a filled, rounded block, both inside a 16 inset. An
    // outlined box with the title inside read as a different kind of object
    // entirely when the two were side by side.
    return Padding(
      // vertical only — see the aggregation chart; `_ProfileArea` insets the row
      padding: const .symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          SizedBox(
            height: _tileHeaderHeight,
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
      (goal) => _GoalRow(
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
    final exercises = Exercises.of(context);
    final exercise = switch (goal.exerciseId) {
      final String id => exercises.where((each) => each.id == id).firstOrNull,
      _ => null,
    };

    final edited = await _showTargetDialog(
      context,
      exercise: exercise,
      metric: goal.metric,
      goal: goal,
    );
    if (edited != null) await state.update(edited);
  }

  Future<void> _addGoal() async {
    final state = Goals.of(context);
    final goal = await _showNewGoalDialog(context, _searchController, _focus);
    if (goal != null) await state.create(goal);
  }
}

/// A single goal: what it measures, where the user is, and what is next.
///
/// Deliberately quiet — no percentage in large type, no badge on an achieved
/// stage. The numbers are the content.
///
/// Stateful for one reason: the current value is a database read, and it must
/// be cached. Every inherited lookup happens in [build] and is passed down —
/// resolving a provider inside an async helper registers a dependency from a
/// subtree that may already be on its way out, which throws during a route
/// teardown (`_dependents.isEmpty`).
class _GoalRow extends StatefulWidget {
  final Goal goal;
  final WorkoutAggregation workouts;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalRow({
    super.key,
    required this.goal,
    required this.workouts,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_GoalRow> createState() => _GoalRowState();
}

class _GoalRowState extends State<_GoalRow> {
  Future<num?>? _reading;
  Object? _key;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final settings = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    final l = L.of(context);

    final goal = widget.goal;
    final exercise = _exercise(exercises);
    final metric = goal.metric.chart;

    // re-read only when the thing being measured changes, not on every notify
    final key = (goal.id, exercise?.name, goal.cadence, widget.workouts.length);
    if (key != _key) {
      _key = key;
      _reading = _read(exercises, exercise, metric);
    }

    // Preferences loads from disk without being awaited at startup, and its
    // unit fields are `late` — reading one before [Preferences.isInitialized]
    // throws. This card paints as soon as there are goals, which can be before
    // that lands, so hold back everything that needs a unit. `watch` brings us
    // straight back when it does. The chart grid never hits this because it
    // waits on `charts.initialized` first.
    final converted = settings.isInitialized;
    final targets = switch (converted) {
      true => goal.stages.map((stage) => _convert(settings, stage.target)).toList(),
      false => const <double>[],
    };
    final subdued = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: widget.onEdit,
      borderRadius: const .all(.circular(8)),
      child: Padding(
        padding: const .symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 4,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title(context, l, exercise),
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
                // bare, like the chart card's — the app does not ask twice
                FeedbackButton.circular(
                  key: AppKeys.deleteGoal(goal.id),
                  tooltip: l.delete,
                  onPressed: widget.onDelete,
                  child: Padding(
                    padding: const .all(1.0),
                    child: Icon(Icons.close_rounded, size: 18, color: dividerColor),
                  ),
                ),
              ],
            ),
            if (converted)
              FutureBuilder<num?>(
                future: _reading,
                builder: (_, snapshot) {
                  final current = switch (snapshot.data) {
                    final num value => _convert(settings, value),
                    _ => null,
                  };

                  return Column(
                    crossAxisAlignment: .start,
                    spacing: 6,
                    children: [
                      Text(_status(context, l, settings, current), style: subdued),
                      _LadderBar(
                        targets: targets,
                        current: current,
                        lowerIsBetter: goal.metric.lowerIsBetter,
                        track: colorScheme.surfaceContainerHighest,
                        fill: colorScheme.primary,
                        achieved: goal.stages.map((stage) => stage.isAchieved).toList(),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// "Workouts", or "Bench Press (Barbell) — Estimated 1RM".
  String _title(BuildContext context, L l, Exercise? exercise) {
    if (widget.goal.metric.isWholeWorkout) return l.workouts;

    final metric = widget.goal.metric.chart?.label(context);
    return switch ((exercise?.name, metric)) {
      (final String name, final String metric) => '$name — $metric',
      (final String name, _) => name,
      _ => metric ?? '',
    };
  }

  /// The line under the title: where the user is, and the deadline if there is
  /// one. A cadence goal says "1 / 4 · per week"; a ladder says what is next.
  String _status(BuildContext context, L l, Preferences settings, double? current) {
    final goal = widget.goal;
    final stage = goal.currentStage;
    if (stage == null) return l.goalComplete;

    final unit = goal.metric.chart?.unitLabel(context, settings) ?? '';
    final suffix = unit.isEmpty ? '' : ' $unit';

    final progress = switch (current) {
      final double value => '${_trim(value)} / ',
      _ => '',
    };

    final cadence = switch (goal.cadence) {
      .week => ' · ${l.goalPerWeek}',
      .month => ' · ${l.goalPerMonth}',
      null => switch (stage.dueOn) {
        final DateTime due => ' · ${l.goalDue(DateFormat.yMMMd().format(due))}',
        _ => '',
      },
    };

    return '$progress${_trim(_convert(settings, stage.target))}$suffix$cadence';
  }

  /// Where the user is right now, in stored units.
  ///
  /// Only read where it can be read *correctly*: the weekly workout count comes
  /// from the aggregation the page already has, and a per-exercise milestone is
  /// its latest observed value. A per-exercise goal with a cadence would need a
  /// period-bounded aggregate that no query provides yet, so it shows its target
  /// and no progress rather than a number that is wrong.
  Future<num?> _read(Exercises exercises, Exercise? exercise, ChartPreferenceType? metric) async {
    final goal = widget.goal;

    if (goal.metric.isWholeWorkout) {
      return switch (goal.cadence) {
        .week => widget.workouts.isEmpty ? null : widget.workouts.last.length,
        _ => null,
      };
    }

    if (goal.cadence != null || metric == null || exercise == null) return null;

    final history = await exercises.getChartExerciseMetics(metric, exercise.name, limit: 1);
    return switch (history) {
      [(final num value, _), ...] => value,
      _ => null,
    };
  }

  /// Goals address an exercise by its server id; the app's catalog is keyed by
  /// name, so this is a scan rather than a lookup.
  Exercise? _exercise(Exercises exercises) {
    if (widget.goal.exerciseId case final String id) {
      for (final exercise in exercises) {
        if (exercise.id == id) return exercise;
      }
    }
    return null;
  }

  double _convert(Preferences settings, num value) {
    return widget.goal.metric.chart?.converter(settings)(value) ?? value.toDouble();
  }
}

/// The ladder as a number line: a tick per stage, filled to where the user is.
///
/// A bar, not a ring — a ring can only show one target, and a ladder has
/// several. Achieved stages are marked by a filled tick rather than a check or
/// a colour change, so the row reads the same under any accent hue.
class _LadderBar extends StatelessWidget {
  final List<double> targets;
  final List<bool> achieved;
  final double? current;
  final bool lowerIsBetter;
  final Color track;
  final Color fill;

  const _LadderBar({
    required this.targets,
    required this.achieved,
    required this.current,
    required this.lowerIsBetter,
    required this.track,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        painter: _LadderPainter(
          targets: targets,
          achieved: achieved,
          current: current,
          lowerIsBetter: lowerIsBetter,
          track: track,
          fill: fill,
        ),
        size: const Size(double.infinity, 12),
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  final List<double> targets;
  final List<bool> achieved;
  final double? current;
  final bool lowerIsBetter;
  final Color track;
  final Color fill;

  const _LadderPainter({
    required this.targets,
    required this.achieved,
    required this.current,
    required this.lowerIsBetter,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targets.isEmpty) return;

    final y = size.height / 2;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), line..color = track);

    // The domain runs from the origin to the furthest point in play, so ticks
    // sit where the targets actually are relative to one another — an evenly
    // spaced stepper would imply the rungs are equal effort, and they are not.
    final span = [...targets, ?current].reduce((a, b) => a > b ? a : b);
    if (span <= 0) return;

    double x(double value) => (value / span).clamp(0.0, 1.0) * size.width;

    if (current case final double value) {
      // Progress is only filled where "more" means "closer". For pace — the one
      // metric where progress goes down — a bar filling rightwards would read
      // exactly backwards, so that case gets a position marker and no fill.
      switch (lowerIsBetter) {
        case false:
          canvas.drawLine(Offset(0, y), Offset(x(value), y), line..color = fill);
        case true:
          canvas.drawLine(
            Offset(x(value), 0),
            Offset(x(value), size.height),
            Paint()
              ..color = fill
              ..strokeWidth = 2,
          );
      }
    }

    for (final (index, target) in targets.indexed) {
      final isAchieved = index < achieved.length && achieved[index];
      canvas.drawCircle(
        Offset(x(target).clamp(3.0, size.width - 3), y),
        3.5,
        Paint()
          ..color = isAchieved ? fill : track
          ..style = isAchieved ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_LadderPainter old) {
    return old.current != current || old.targets != targets || old.fill != fill || old.track != track;
  }
}

String _trim(num value) {
  final fixed = value.toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}
