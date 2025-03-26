import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'spot.dart';

class HistoryChart extends StatefulWidget {
  final Color gradientColor1;
  final Color gradientColor2;
  final Color gradientColor3;
  final Color indicatorStrokeColor;
  final LineSeries series;
  final TextStyle? bottomAxisLabelStyle;
  final String Function(int x)? getBottomLabel;

  HistoryChart({
    super.key,
    required Iterable<Dot> series,
    this.bottomAxisLabelStyle,
    this.getBottomLabel,
    Color? gradientColor1,
    Color? gradientColor2,
    Color? gradientColor3,
    Color? indicatorStrokeColor,
  })  : series = LineSeries(dots: series),
        gradientColor1 = gradientColor1 ?? ChartColors.contentColorBlue,
        gradientColor2 = gradientColor2 ?? ChartColors.contentColorPink,
        gradientColor3 = gradientColor3 ?? ChartColors.contentColorRed,
        indicatorStrokeColor = indicatorStrokeColor ?? ChartColors.mainTextColor1;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  LineSeries get series => widget.series;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: series,
      builder: (_, __) {
        final lineBarsData = [
          LineChartBarData(
            showingIndicators: series.tooltipIndices,
            spots: series.map((each) => FlSpot(each.x, each.y)).toList(),
            isCurved: true,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  widget.gradientColor1.withValues(alpha: 0.4),
                  widget.gradientColor2.withValues(alpha: 0.4),
                  widget.gradientColor3.withValues(alpha: 0.4),
                ],
              ),
            ),
            dotData: const FlDotData(show: true),
            gradient: LinearGradient(
              colors: [widget.gradientColor1, widget.gradientColor2, widget.gradientColor3],
              stops: const [0.1, 0.4, 0.9],
            ),
          ),
        ];
        final tooltipsOnBar = lineBarsData[0];

        return LayoutBuilder(
          builder: (context, constraints) {
            return LineChart(
              LineChartData(
                showingTooltipIndicators: series.tooltipIndices.map(
                  (index) {
                    return ShowingTooltipIndicators(
                      [
                        LineBarSpot(
                          tooltipsOnBar,
                          lineBarsData.indexOf(tooltipsOnBar),
                          tooltipsOnBar.spots[index],
                        ),
                      ], //
                    );
                  }, //
                ).toList(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: false,
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    switch ((event, response)) {
                      case (FlTapUpEvent(), LineTouchResponse(:List<TouchLineBarSpot> lineBarSpots)):
                        final index = lineBarSpots.first.spotIndex;
                        if (series.tooltipIndices.contains(index)) {
                          series.removeTooltipAt(index);
                        } else {
                          series.addTooltipAt(index);
                        }
                    }
                  },
                  mouseCursorResolver: (FlTouchEvent event, LineTouchResponse? response) {
                    if (response == null || response.lineBarSpots == null) {
                      return SystemMouseCursors.basic;
                    }
                    return SystemMouseCursors.click;
                  },
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map(
                      (index) {
                        return TouchedSpotIndicatorData(
                          const FlLine(color: Colors.pink),
                          FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 8,
                              color: _lerpGradient(barData.gradient!.colors, barData.gradient!.stops!, percent / 100),
                              strokeWidth: 2,
                              strokeColor: widget.indicatorStrokeColor,
                            ),
                          ),
                        );
                      },
                    ).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.pink,
                    tooltipRoundedRadius: 8,
                    getTooltipItems: (List<LineBarSpot> lineBarsSpot) {
                      return lineBarsSpot.map(
                        (lineBarSpot) {
                          return LineTooltipItem(
                            lineBarSpot.y.toString(),
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          );
                        },
                      ).toList();
                    },
                  ),
                ),
                lineBarsData: lineBarsData,
                minY: series.lowerBoundaryY - 1,
                maxY: series.upperBoundaryY + 1,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    axisNameWidget: Text('count'),
                    axisNameSize: 24,
                    sideTitles: SideTitles(showTitles: false, reservedSize: 0),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: switch (widget.getBottomLabel) {
                        String Function(int) callback => (value, meta) {
                            return SideTitleWidget(
                              meta: meta,
                              angle: -pi / 4,
                              child: Text(
                                callback(value.toInt()),
                                style: widget.bottomAxisLabelStyle,
                              ),
                            );
                          },
                        null => defaultGetTitle,
                      },
                      reservedSize: 30,
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    axisNameWidget: Text('count'),
                    sideTitles: SideTitles(showTitles: false, reservedSize: 0),
                  ),
                  topTitles: const AxisTitles(
                    axisNameWidget: Text('Wall clock', textAlign: TextAlign.left),
                    axisNameSize: 24,
                    sideTitles: SideTitles(showTitles: true, reservedSize: 0),
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            );
          },
        );
      },
    );
  }
}

class ChartColors {
  static const primary = contentColorCyan;
  static const menuBackground = Color(0xFF090912);
  static const itemsBackground = Color(0xFF1B2339);
  static const pageBackground = Color(0xFF282E45);
  static const mainTextColor1 = Colors.white;
  static const mainTextColor2 = Colors.white70;
  static const mainTextColor3 = Colors.white38;
  static const mainGridLineColor = Colors.white10;
  static const borderColor = Colors.white54;
  static const gridLinesColor = Color(0x11FFFFFF);

  static const contentColorBlack = Colors.black;
  static const contentColorWhite = Colors.white;
  static const contentColorBlue = Color(0xFF2196F3);
  static const contentColorYellow = Color(0xFFFFC300);
  static const contentColorOrange = Color(0xFFFF683B);
  static const contentColorGreen = Color(0xFF3BFF49);
  static const contentColorPurple = Color(0xFF6E1BFF);
  static const contentColorPink = Color(0xFFFF3AF2);
  static const contentColorRed = Color(0xFFE80054);
  static const contentColorCyan = Color(0xFF50E4FF);
}

Color _lerpGradient(List<Color> colors, List<double> stops, double t) {
  assert(colors.isNotEmpty, '"Colors" cannot be empty');

  if (colors.length == 1) {
    return colors.first;
  }

  final normalized = switch (stops.length == colors.length) {
    true => stops,
    false => List.generate(colors.length, (i) => i / (colors.length - 1)),
  };

  return Iterable<int>.generate(colors.length - 1)
      .map(
        (s) => (
          leftStop: normalized[s],
          rightStop: normalized[s + 1],
          leftColor: colors[s],
          rightColor: colors[s + 1],
        ),
      )
      .firstWhere(
        (segment) => t <= segment.rightStop,
        orElse: () => (
          leftStop: normalized.last,
          rightStop: normalized.last,
          leftColor: colors.last,
          rightColor: colors.last,
        ),
      )
      .let(
        (segment) => t <= segment.leftStop
            ? segment.leftColor
            : Color.lerp(
                segment.leftColor,
                segment.rightColor,
                (t - segment.leftStop) / (segment.rightStop - segment.leftStop),
              )!,
      );
}

extension Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
