import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'nice_axis.dart';
import 'spot.dart';
import 'threshold.dart';

/// Width reserved for the left (y-axis) labels. Exposed so callers can align a
/// top title over the plot, which sits to the right of this inset.
const double historyChartLeftAxisSize = 60;

class HistoryChart extends StatefulWidget {
  final Color gradientColor1;
  final Color gradientColor2;
  final Color gradientColor3;
  final Color indicatorStrokeColor;
  final LineSeries series;
  final TextStyle? bottomAxisLabelStyle;
  final String Function(int x)? getBottomLabel;
  final Widget Function(double y)? getLeftLabel;
  final String Function(double x, double y)? getTooltip;
  final Widget? topLabel;

  /// Preferred y-axis tick steps (ascending). When set, the axis snaps to the
  /// smallest of these that keeps the tick count reasonable — e.g. duration
  /// charts pass `[15, 30, 60, 300, …]` so ticks read 30s/1m rather than 20s.
  /// When null, a generic 1/2/5·10ⁿ step is chosen from the data range.
  final List<double>? yStepCandidates;

  /// When set, the line, fill and tooltip all use this single hue — the
  /// meaningful per-family color. When null, falls back to the legacy 3-stop
  /// gradient (the `gradientColor*` args).
  final Color? color;

  /// Stroke of the plotted line.
  ///
  /// The default suits a series of workout sessions. Dense data wants it
  /// thinner: at 4pt a year of daily readings overlaps itself into a solid
  /// block, and the shape it was drawn to show disappears inside its own line.
  final double barWidth;

  /// Width reserved for the y-axis labels.
  ///
  /// Defaults to [historyChartLeftAxisSize], which is sized for the longest
  /// labels in the app (`1:30:00`). Charts with short labels can claw the
  /// difference back for the plot — left at the default, the reserve reads as
  /// the whole chart being pushed to the right.
  final double leftAxisSize;

  /// Whether every point wears a dot.
  ///
  /// On by default, because a dot is where a tap-to-pin lands and a series of
  /// workout sessions is short enough for that to read. Turn it off for daily
  /// data over months: ninety dots on a 4pt line stop marking anything and
  /// merge into a thicker, noisier line. Tapping still works without them.
  final bool showDots;

  /// Values to mark across the plot — a goal's rungs, say.
  ///
  /// They widen the y-axis as well as drawing: a target is normally *above*
  /// anything the series contains, and an axis fitted to the data alone would
  /// put the line off the top of the chart, hiding it in exactly the case it
  /// exists for.
  final List<ChartThreshold> thresholds;

  new({
    super.key,
    required Iterable<Dot> series,
    this.bottomAxisLabelStyle,
    this.getBottomLabel,
    this.getLeftLabel,
    this.topLabel,
    this.getTooltip,
    this.yStepCandidates,
    this.color,
    this.showDots = true,
    this.barWidth = 4,
    this.leftAxisSize = historyChartLeftAxisSize,
    this.thresholds = const [],
    Color? gradientColor1,
    Color? gradientColor2,
    Color? gradientColor3,
    Color? indicatorStrokeColor,
  }) : series = LineSeries(dots: series),
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
  void dispose() {
    series.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: series,
      builder: (_, _) {
        final accent = widget.color;
        // a solid family hue when provided; otherwise the legacy 3-stop gradient
        final lineGradient = switch (accent) {
          Color color => LinearGradient(colors: [color, color], stops: const [0.0, 1.0]),
          null => LinearGradient(
            colors: [widget.gradientColor1, widget.gradientColor2, widget.gradientColor3],
            stops: const [0.1, 0.4, 0.9],
          ),
        };
        final fillGradient = switch (accent) {
          Color color => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
          ),
          null => LinearGradient(
            colors: [
              widget.gradientColor1.withValues(alpha: 0.4),
              widget.gradientColor2.withValues(alpha: 0.4),
              widget.gradientColor3.withValues(alpha: 0.4),
            ],
          ),
        };

        final lineBarsData = [
          LineChartBarData(
            showingIndicators: series.tooltipIndices,
            spots: series.map((each) => FlSpot(each.x, each.y)).toList(),
            isCurved: true,
            preventCurveOverShooting: true,
            barWidth: widget.barWidth,
            belowBarData: BarAreaData(show: true, gradient: fillGradient),
            // a dot on every point — they mark where the tap-to-pin targets are
            dotData: FlDotData(show: widget.showDots),
            gradient: lineGradient,
          ),
        ];
        final tooltipsOnBar = lineBarsData[0];

        final marks = widget.thresholds.map((each) => each.value);
        final yAxis = niceYAxis(
          [series.lowerBoundaryY, ...marks].reduce(min),
          [series.upperBoundaryY, ...marks].reduce(max),
          stepCandidates: widget.yStepCandidates,
        );

        return LayoutBuilder(
          builder: (_, constraints) {
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
                          FlLine(color: accent ?? Colors.pink),
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
                    getTooltipColor: (touchedSpot) => accent ?? Colors.pink,
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItems: (lineBarsSpot) {
                      return lineBarsSpot.map(
                        (spot) {
                          return LineTooltipItem(
                            widget.getTooltip?.call(spot.x, spot.y) ?? spot.y.toString(),
                            TextStyle(color: _readableOn(accent ?? Colors.pink, scheme), fontWeight: FontWeight.bold),
                          );
                        },
                      ).toList();
                    },
                  ),
                ),
                lineBarsData: lineBarsData,
                extraLinesData: ExtraLinesData(
                  horizontalLines: widget.thresholds.map(
                    (each) {
                      final color = each.color ?? accent ?? scheme.outline;
                      return HorizontalLine(
                        y: each.value,
                        color: color.withValues(alpha: each.reached ? .9 : .5),
                        strokeWidth: 1.5,
                        // dashed while it is still ahead of you, solid once met
                        dashArray: each.reached ? null : const [6, 4],
                        label: switch (each.label) {
                          final String text => HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
                            labelResolver: (_) => text,
                          ),
                          null => HorizontalLineLabel(),
                        },
                      );
                    },
                  ).toList(),
                ),
                minY: yAxis.min,
                maxY: yAxis.max,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      interval: yAxis.interval,
                      getTitlesWidget: switch (widget.getLeftLabel) {
                        Widget Function(double) callback => (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                            child: callback(value),
                          );
                        },
                        null => defaultGetTitle,
                      },
                      showTitles: true,
                      reservedSize: widget.leftAxisSize,
                      maxIncluded: false,
                      minIncluded: false,
                    ),
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
                            // nudge the first/last date inward so the rotated
                            // label isn't clipped at the chart edge
                            fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
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
                    sideTitles: SideTitles(showTitles: false, reservedSize: 0),
                  ),
                  topTitles: switch (widget.topLabel) {
                    Widget label => AxisTitles(
                      axisNameWidget: label,
                      axisNameSize: 22,
                      sideTitles: const SideTitles(showTitles: true, reservedSize: 0),
                    ),
                    null => const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  },
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

/// The theme ink — dark or light — that reads better on [background] (the WCAG
/// luminance crossover), so tooltip text stays legible on any family hue. The
/// two poles come from the color scheme rather than hardcoded black/white.
Color _readableOn(Color background, ColorScheme scheme) {
  final (dark, light) = scheme.onSurface.computeLuminance() < scheme.surface.computeLuminance()
      ? (scheme.onSurface, scheme.surface)
      : (scheme.surface, scheme.onSurface);
  return switch (background.computeLuminance() > 0.179) {
    true => dark,
    false => light,
  };
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
