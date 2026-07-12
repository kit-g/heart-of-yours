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
        series: const [Dot(0, 10, tooltip: '10'), Dot(1, 12), Dot(2, 11)],
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
}
