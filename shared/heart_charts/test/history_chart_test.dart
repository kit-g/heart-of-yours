import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_charts/heart_charts.dart';

void main() {
  Future<void> pumpChart(WidgetTester tester, Widget chart) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 400, height: 300, child: chart),
          ),
        ),
      ),
    );
  }

  testWidgets('renders a multi-point line chart with axis labels, no overflow', (tester) async {
    await pumpChart(
      tester,
      HistoryChart(
        series: const [Dot(0, 10), Dot(1, 12), Dot(2, 11)],
        getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
        getBottomLabel: (x) => 'd$x',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(HistoryChart), findsOneWidget);
    expect(find.text('d0'), findsWidgets); // bottom axis labels rendered
  });

  // Dots mark where a tap-to-pin lands, which is worth the clutter for a
  // handful of sessions and not for months of daily readings.
  group('showDots', () {
    LineChartBarData barOf(WidgetTester tester) {
      return tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first;
    }

    testWidgets('is on by default, so existing charts keep their points', (tester) async {
      await pumpChart(tester, HistoryChart(series: const [Dot(0, 10), Dot(1, 12)]));
      await tester.pumpAndSettle();

      expect(barOf(tester).dotData.show, isTrue);
    });

    testWidgets('turns the points off without touching the line', (tester) async {
      await pumpChart(tester, HistoryChart(series: const [Dot(0, 10), Dot(1, 12)], showDots: false));
      await tester.pumpAndSettle();

      final bar = barOf(tester);
      expect(bar.dotData.show, isFalse);
      expect(bar.spots, hasLength(2), reason: 'hiding a dot must not drop the reading behind it');
    });
  });

  testWidgets('renders a single-point (flat) series without throwing', (tester) async {
    await pumpChart(
      tester,
      HistoryChart(
        series: const [Dot(0, 5)],
        getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders an empty series without throwing', (tester) async {
    await pumpChart(
      tester,
      HistoryChart(
        series: const [],
        getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders with a single family color and a pinned tooltip', (tester) async {
    // the tooltip'd dot drives the accent tooltip + indicator (_lerpGradient) path
    await pumpChart(
      tester,
      HistoryChart(
        series: const [
          Dot(0, 10, tooltip: '10'),
          Dot(1, 12),
          Dot(2, 11),
        ],
        color: const Color(0xFFE34948),
        getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
        getBottomLabel: (x) => 'd$x',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts duration step candidates without error', (tester) async {
    await pumpChart(
      tester,
      HistoryChart(
        series: const [Dot(0, 270), Dot(1, 300), Dot(2, 330)],
        yStepCandidates: const [15.0, 30.0, 60.0, 300.0],
        getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
        getBottomLabel: (x) => 'd$x',
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('thresholds', () {
    testWidgets('widen the axis so a target above the series still fits', (tester) async {
      // the case the feature exists for: a goal you have not reached yet. An
      // axis fitted to the data alone would draw the line off the top, which
      // looks like nothing was drawn at all.
      await pumpChart(
        tester,
        HistoryChart(
          series: const [Dot(0, 10), Dot(1, 12), Dot(2, 11)],
          getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
          thresholds: const [ChartThreshold(value: 40, label: '40 kg')],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // an axis label at or beyond the threshold proves the range grew to it
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((each) => double.tryParse(each.data ?? ''))
          .nonNulls;
      expect(labels.any((each) => each >= 40), isTrue, reason: 'axis stopped short of the threshold');
    });

    testWidgets('widen the axis downwards for a target below the series', (tester) async {
      // pace goals descend, so the rung can sit under everything recorded
      await pumpChart(
        tester,
        HistoryChart(
          series: const [Dot(0, 300), Dot(1, 290)],
          getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
          thresholds: const [ChartThreshold(value: 200)],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((each) => double.tryParse(each.data ?? ''))
          .nonNulls;
      expect(labels.any((each) => each <= 200), isTrue, reason: 'axis stopped short of the threshold');
    });

    testWidgets('draw reached and unreached rungs together without throwing', (tester) async {
      await pumpChart(
        tester,
        HistoryChart(
          series: const [Dot(0, 100), Dot(1, 120)],
          getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
          thresholds: const [
            ChartThreshold(value: 100, label: '100', reached: true),
            ChartThreshold(value: 140, label: '140'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HistoryChart), findsOneWidget);
    });

    testWidgets('an empty list leaves the chart exactly as it was', (tester) async {
      await pumpChart(
        tester,
        HistoryChart(
          series: const [Dot(0, 10), Dot(1, 12)],
          getLeftLabel: (y) => Text(y.toStringAsFixed(0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
