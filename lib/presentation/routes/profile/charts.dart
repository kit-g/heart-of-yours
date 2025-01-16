part of 'profile.dart';

class WorkoutsAggregationChart extends StatefulWidget {
  final WorkoutAggregation workouts;
  final double? opacity;

  const WorkoutsAggregationChart({
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
            Expanded(
              child: Opacity(
                opacity: widget.opacity ?? 1,
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
                            maxY: widget.workouts.max.toDouble() + 1,
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
                                  getTitlesWidget: _xTitles,
                                  reservedSize: 32,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1.0,
                                  reservedSize: 32,
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
                              checkToShowHorizontalLine: (v) {
                                return v % 1 == 0;
                              },
                            ),
                          ),
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
      colors: [
        color,
        color.withValues(alpha: .7)
      ],
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
      showingTooltipIndicators: [0],
    );
  }

  Widget _xTitles(double value, TitleMeta meta) {
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

  Widget _yTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
      meta: meta,
      space: 12,
      child: switch (value.toInt() % 2 == 0) {
        false => const SizedBox.shrink(),
        true => Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                value.toInt().toString(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
      },
    );
  }
}
