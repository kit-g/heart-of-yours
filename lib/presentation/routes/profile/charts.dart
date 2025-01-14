part of 'profile.dart';

// how many weeks of workouts the chart will display
const _maxWorkoutBars = 8;

class WorkoutsAggregationChart extends StatefulWidget {
  final WorkoutAggregation workouts;

  const WorkoutsAggregationChart({
    super.key,
    required this.workouts,
  });

  @override
  State<StatefulWidget> createState() => _WorkoutsAggregationChartState();
}

class _WorkoutsAggregationChartState extends State<WorkoutsAggregationChart> {
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
    return AspectRatio(
      aspectRatio: 5 / 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              workoutsPerWeek,
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: colorScheme.primaryContainer,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _pointedAtBar,
                    builder: (_, __, ___) {
                      return BarChart(
                        duration: animDuration,
                        BarChartData(
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (_) => colorScheme.onTertiary,
                              tooltipHorizontalAlignment: FLHorizontalAlignment.right, // todo
                              tooltipMargin: -6 * 20, // todo
                              getTooltipItem: _tooltip,
                            ),
                            touchCallback: (FlTouchEvent event, barTouchResponse) {
                              if (!event.isInterestedForInteractions || // todo
                                  barTouchResponse == null ||
                                  barTouchResponse.spot == null) {
                                _pointedAtBar.value = -1;
                                return;
                              }
                              _pointedAtBar.value = barTouchResponse.spot!.touchedBarGroupIndex;
                            },
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
                                getTitlesWidget: _titles,
                                reservedSize: 32,
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: widget.workouts.take(_maxWorkoutBars).indexed.map(
                            (record) {
                              final (index, summary) = record;
                              return _bar(index, summary);
                            },
                          ).toList(),
                          gridData: const FlGridData(
                            show: true,
                            drawHorizontalLine: true,
                            drawVerticalLine: false,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarTooltipItem? _tooltip(
    BarChartGroupData group,
    int groupIndex,
    BarChartRodData rod,
    int rodIndex,
  ) {
    final summary = widget.workouts.toList()[group.x];
    return BarTooltipItem(
      summary.workouts.map((each) => each.name).join('\n'),
      Theme.of(context).textTheme.titleMedium!,
    );
  }

  BarChartGroupData _bar(int index, WeekSummary summary) {
    final isPointedAt = _pointedAtBar.value == index;
    final dy = summary.length.toDouble();
    final ThemeData(:colorScheme) = Theme.of(context);

    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: isPointedAt ? dy + 1 : dy,
          color: isPointedAt ? colorScheme.tertiary : colorScheme.primary,
          width: 22,
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _titles(double value, TitleMeta meta) {
    final summary = widget.workouts.toList()[value.toInt()];
    return SideTitleWidget(
      meta: meta,
      space: 12,
      child: Text(
        DateFormat('d/M').format(summary.startDate),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
