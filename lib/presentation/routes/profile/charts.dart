part of 'profile.dart';

/// Tall enough to read a bar chart, short enough to leave the dashboard below
/// it visible without scrolling.
const _maxChartHeight = 360.0;

/// Height of a profile tile's heading.
///
/// Fixed, and shared by the aggregation chart and the goals card, because the
/// goals heading carries an "Add goal" button and a bare title does not — left
/// to their natural heights the two blocks below them start on different lines.
const _tileHeaderHeight = 44.0;

/// Width of one `MM-DD` label on the weekly chart's x axis, and of the gutter the
/// y-axis labels sit in. Together they decide how many dates the axis can show
/// without them touching — see `_labelStride`.
const _xLabelWidth = 44.0;
const _yAxisWidth = 28.0;

/// Widest a dashboard chart card gets before the grid adds a column instead.
///
/// These cards are summaries — the detail lives behind a tap — so the
/// dashboard is worth keeping dense. Lands on 3 columns in iPad landscape and
/// 2 in portrait, and sits mid-band rather than near a boundary so a change in
/// rail width or padding does not flip the count.
const _maxChartCardWidth = 440.0;

class WorkoutsAggregationChart extends StatefulWidget {
  final WorkoutAggregation workouts;
  final double? opacity;

  const new({
    super.key,
    required this.workouts,
    this.opacity,
  });

  @override
  State<StatefulWidget> createState() => _WorkoutsAggregationChartState();
}

class _WorkoutsAggregationChartState extends State<WorkoutsAggregationChart> with HasHaptic<WorkoutsAggregationChart> {
  final animDuration = const Duration(milliseconds: 250);

  final _pointedAtBar = ValueNotifier<int>(-1);

  @override
  void dispose() {
    _pointedAtBar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final L(:workoutsPerWeek) = L.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          // 5:4 is right on a phone and absurd on a tablet: this is a
          // full-bleed sliver, so at 1850pt wide the ratio alone asked for a
          // 1480pt-tall chart, pushing the rest of the profile off screen.
          // Past the cap, extra width makes the chart wider, not taller.
          height: min(constraints.maxWidth * 4 / 5, _maxChartHeight),
          child: Padding(
            // vertical only: the row this sits in owns the horizontal inset, so
            // the gutter between tiles can match the chart grid's below
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: _tileHeaderHeight,
                  child: Align(
                    alignment: .centerLeft,
                    child: Text(
                      workoutsPerWeek,
                      style: textTheme.titleLarge,
                    ),
                  ),
                ),
                Expanded(
                  child: Opacity(
                    opacity: widget.opacity ?? 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        // the fill tone, like the goals panel below: visible
                        // as the same quiet inset in both brightnesses,
                        // where a surface panel vanished on the light ground
                        color: colorScheme.surfaceContainer,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _pointedAtBar,
                          builder: (_, _, _) {
                            // Measured, not assumed: how many date labels fit is a
                            // question about the width this chart was handed, and on a
                            // tablet that is a pane rather than the window.
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final stride = _labelStride(constraints.maxWidth);
                                final axis = _yAxis(widget.workouts.max);
                                return BarChart(
                                  duration: animDuration,
                                  BarChartData(
                                    maxY: axis.max,
                                    minY: 0,
                                    barTouchData: BarTouchData(
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (_) => Colors.transparent,
                                        tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                                        tooltipMargin: 0,
                                        getTooltipItem: _tooltip,
                                      ),
                                      touchCallback: _onTouch,
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) => _xTitles(value, meta, stride),
                                          reservedSize: 32,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          interval: axis.interval,
                                          // room for the widest number the axis
                                          // will draw, so three figures are not
                                          // clipped into the plot
                                          reservedSize: 20 + 8.0 * '${axis.max.toInt()}'.length,
                                          minIncluded: false,
                                          maxIncluded: true,
                                          getTitlesWidget: _yTitles,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: widget.workouts.indexed.map(
                                      (record) {
                                        final (index, summary) = record;
                                        return _bar(index, summary);
                                      },
                                    ).toList(),
                                    gridData: FlGridData(
                                      show: true,
                                      drawHorizontalLine: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: axis.interval,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTouch(FlTouchEvent event, BarTouchResponse? barTouchResponse) {
    if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
      _pointedAtBar.value = -1;
      return;
    }
    buzz();
    _pointedAtBar.value = barTouchResponse.spot!.touchedBarGroupIndex;
  }

  BarTooltipItem? _tooltip(
    BarChartGroupData group,
    int groupIndex,
    BarChartRodData rod,
    int rodIndex,
  ) {
    final summary = widget.workouts.toList()[group.x];
    return BarTooltipItem(
      summary.length.toString(),
      Theme.of(context).textTheme.titleMedium!,
    );
  }

  BarChartGroupData _bar(int index, WeekSummary summary) {
    final isPointedAt = _pointedAtBar.value == index;
    final dy = summary.length.toDouble();
    final ThemeData(:colorScheme) = Theme.of(context);
    final color = isPointedAt ? colorScheme.tertiary : colorScheme.primary;
    final gradient = LinearGradient(
      colors: [color, color.withValues(alpha: .7)],
      end: Alignment.topCenter,
      begin: Alignment.bottomCenter,
    );

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: isPointedAt ? dy + .1 : dy,
          gradient: gradient,
          width: 22,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ],
      // shows only when
      showingTooltipIndicators: switch (summary.length) {
        > 0 => [0],
        _ => null,
      },
    );
  }

  /// How many weeks share one date label.
  ///
  /// Eight weeks of `MM-DD` in a phone-width card leaves about 41pt a bar, and
  /// the label wants [_xLabelWidth]. The boxes overlapped, so the dates ran into
  /// each other and the axis read as one long smear.
  int _labelStride(double width) {
    final weeks = widget.workouts.length;
    if (weeks == 0) return 1;

    final slot = (width - _yAxisWidth) / weeks;
    if (slot <= 0) return 1;

    return (_xLabelWidth / slot).ceil().clamp(1, weeks);
  }

  Widget _xTitles(double value, TitleMeta meta, int stride) {
    final index = value.toInt();
    final weeks = widget.workouts.toList();

    // Thinned from the most recent week backwards, so the newest bar keeps its
    // label whatever the stride — it is the one the user came to read, and
    // counting from the left would drop it exactly when the axis is tightest.
    if ((weeks.length - 1 - index) % stride != 0) return const SizedBox.shrink();

    final summary = weeks[index];
    return SideTitleWidget(
      meta: meta,
      space: 12,
      child: SizedBox(
        width: 44,
        child: Center(
          child: Text(
            L.of(context).dayAndMonth(summary.startDate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }

  /// Steps the count axis is allowed to take. Whole workouts, and coarse
  /// enough that a busy week cannot ask for a label per workout: the axis used
  /// to be pinned at `interval: 1` and drew every even integer, which reads
  /// fine at 7 a week and collapsed into an unreadable column of digits at 175
  /// (heart-of-yours#113).
  static const _ySteps = <double>[1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000];

  /// The axis for a bar chart of counts: a whole-number step, and a floor
  /// pinned at zero.
  ///
  /// [niceYAxis] leaves half a step of headroom at each end so a line's dot
  /// marker never touches the frame. Bars grow from the baseline and have no
  /// such problem, and a negative number of workouts is not a thing — so the
  /// minimum it suggests is dropped and only the top and the step are kept.
  ({double max, double interval}) _yAxis(int max) {
    final axis = niceYAxis(0, max.toDouble(), stepCandidates: _ySteps);
    return (max: axis.max, interval: axis.interval);
  }

  Widget _yTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        value.toInt().toString(),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
