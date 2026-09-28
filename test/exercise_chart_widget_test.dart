// Direct widget tests for ExerciseChart, the fetch/phase wrapper the
// exercises detail page's Charts tab (and the profile dashboard) both build
// on top of `HistoryChart`/`TimelineChart`. No providers are needed here —
// the widget only reads its own constructor callbacks and `L.of(context)`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/exercise_chart.dart';
import 'package:heart/presentation/widgets/timeline_chart.dart';
import 'package:heart_charts/heart_charts.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Future<List<(num, DateTime)>?> Function() callback,
  bool timeline = false,
  Object? refreshKey,
  Widget emptyState = const Text('empty'),
  Widget errorState = const Text('error'),
  Widget? loadingState,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(
        body: ExerciseChart(
          callback: callback,
          emptyState: emptyState,
          errorState: errorState,
          loadingState: loadingState,
          converter: (v) => v.toDouble(),
          label: 'Weight',
          timeline: timeline,
          refreshKey: refreshKey,
        ),
      ),
    ),
  );
}

void main() {
  final now = DateTime(2024, 6, 1);
  final series = [
    (100.0, now),
    (90.0, now.subtract(const Duration(days: 7))),
    (80.0, now.subtract(const Duration(days: 14))),
  ];

  testWidgets('shows the loading widget while the future is in flight', (tester) async {
    final completer = Completer<List<(num, DateTime)>?>();
    await _pump(tester, callback: () => completer.future);

    expect(find.text('empty'), findsNothing);
    expect(find.text('error'), findsNothing);
    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('a custom loading widget replaces the default SizedBox', (tester) async {
    final completer = Completer<List<(num, DateTime)>?>();
    await _pump(tester, callback: () => completer.future, loadingState: const Text('loading'));

    expect(find.text('loading'), findsOneWidget);
    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('an empty result renders the empty state', (tester) async {
    await _pump(tester, callback: () async => []);
    await tester.pumpAndSettle();

    expect(find.text('empty'), findsOneWidget);
  });

  testWidgets('a failed future renders the error state', (tester) async {
    await _pump(tester, callback: () async => throw StateError('boom'));
    await tester.pumpAndSettle();

    expect(find.text('error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data renders HistoryChart with an accessible summary, off the timeline', (tester) async {
    await _pump(tester, callback: () async => series);
    await tester.pumpAndSettle();

    expect(find.byType(HistoryChart), findsOneWidget);
    expect(find.byType(TimelineChart), findsNothing);
    // the trend is upward (80 -> 100), and the summary is the a11y stand-in
    // for a line no screen reader can otherwise perceive
    final semantics = tester.widget<Semantics>(
      find.ancestor(of: find.byType(HistoryChart), matching: find.byType(Semantics)).first,
    );
    expect(semantics.properties.label, contains('Weight'));
  });

  testWidgets('data renders TimelineChart when timeline is on', (tester) async {
    await _pump(tester, callback: () async => series, timeline: true);
    await tester.pumpAndSettle();

    // TimelineChart is itself built on HistoryChart internally, so only the
    // outer widget is the meaningful assertion here.
    expect(find.byType(TimelineChart), findsOneWidget);
  });

  testWidgets('refreshKey change re-invokes the callback; a plain rebuild does not', (tester) async {
    var calls = 0;
    Future<List<(num, DateTime)>?> callback() async {
      calls++;
      return series;
    }

    await _pump(tester, callback: callback, refreshKey: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    // same refreshKey: rebuilding must not flicker back through the loader
    await _pump(tester, callback: callback, refreshKey: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    // changed refreshKey: the caller is signalling the underlying data moved
    await _pump(tester, callback: callback, refreshKey: 2);
    await tester.pumpAndSettle();
    expect(calls, 2);
  });
}
