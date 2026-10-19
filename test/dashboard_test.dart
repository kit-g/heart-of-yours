// Coverage for lib/presentation/routes/profile/dashboard.dart: `_Dashboard`'s
// own layout branches (the compact reorderable list vs. the wide reorderable
// grid) and `_Chart`'s label/delete, sitting above `GoalsCard` (covered
// elsewhere) — not the charts themselves (heart_charts/exercise_chart.dart),
// just what this file composes around them.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:reorderable_grid/reorderable_grid.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  /// Charts a test adds after the two exercise charts.
  var extraRows = <Map<String, Object?>>[];

  setUp(() {
    extraRows = [];
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);

    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
    when(api.getExercises()).thenAnswer((_) async => [bench]);
    when(db.getChartRows(any)).thenAnswer(
      (_) async => [
        // A stored chart always carries the id the database assigned it —
        // `ChartPreference.exercise` (the client-side "new" factory, `id:
        // null`) is not what a *read* returns, and `Charts.removePreference`
        // is a no-op without one.
        ChartPreference.create(id: 'pref-1', type: .topSetWeight, data: {'exerciseName': bench.id}).toRow(),
        // no exercise in the catalog has this id — the fallback path
        ChartPreference.create(
          id: 'pref-2',
          type: .totalVolume,
          data: {'exerciseName': 'not-a-real-exercise-id'},
        ).toRow(),
        ...extraRows,
      ],
    );
    // `_Chart`'s own customLabel (the `resolved?.name ?? '…'` line this file
    // is under test for) only renders on `ExerciseChart`'s "data" phase —
    // empty/error/loading each carry their own header instead (charts.dart's
    // `_EmptyState` et al.). Unstubbed this is `null`, a nice-mock dummy
    // `ExerciseChart` has no phase for at all (not loading, not an error, not
    // a List), so a non-empty list is what actually exercises this file's code.
    when(
      db.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
    ).thenAnswer((_) async => [(100, DateTime(2024, 1, 1)), (110, DateTime(2024, 1, 8))]);
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes(10);

    // Real startup loads these from `_initApp`, which runs in `Zone.root` —
    // a zone the fake-async clock this binding uses never drives (see
    // a11y_test.dart's restTimers case for the same workaround). `userId` is
    // already set by `onUserChange`, which runs outside that zone.
    final context = tester.element(find.byType(MaterialApp));
    await Charts.of(context).init();
    await Exercises.of(context).init();
    await tester.pumpTimes(10);
  }

  testWidgets(
    'the wide layout (the default test surface, >= the 600 breakpoint) lays charts out in a reorderable grid',
    (
      tester,
    ) async {
      await pumpProfile(tester);

      expect(find.byType(SliverReorderableGrid), findsOneWidget);
      expect(find.byType(SliverReorderableList), findsNothing);
      // the resolved exercise's real name, and the fallback's placeholder for
      // the one the catalog does not have
      expect(find.textContaining('Bench Press'), findsOneWidget);
      expect(find.textContaining('…'), findsOneWidget);
    },
  );

  testWidgets('the compact layout (below the breakpoint) lays the same charts out in a reorderable list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpProfile(tester);

    expect(find.byType(SliverReorderableList), findsOneWidget);
    expect(find.byType(SliverReorderableGrid), findsNothing);
    expect(find.textContaining('Bench Press'), findsOneWidget);
  });

  testWidgets("a chart's delete button removes its preference", (tester) async {
    // Tall enough that the charts section (well below the goals card and the
    // week's workouts) is laid out without needing a scroll to reach it.
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(db.deleteChartPreference(any, any)).thenAnswer((_) async {});
    await pumpProfile(tester);

    final context = tester.element(find.byType(MaterialApp));
    expect(Charts.of(context).length, 2);

    // The close icon sits beside the label in the same customLabel row; find
    // it scoped to that row rather than a global icon search, since the
    // empty/error/loading chart states carry a close affordance of their own.
    final label = find.textContaining('Bench Press');
    final row = find.ancestor(of: label, matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.close_rounded)).first);
    await tester.pumpTimes();

    expect(Charts.of(context).length, 1);
    verify(db.deleteChartPreference(any, 'u1')).called(1);
  });

  group('training-wide charts (#137)', () {
    final now = DateTime.now();

    setUp(() {
      extraRows = [
        const TrainingChart(id: 'volume', metric: .volume).toRow(),
        FrequencyChart(id: 'days', exerciseId: bench.id).toRow(),
        // a kind from a newer build: skipped, and the dashboard still draws
        {'id': 'future', 'type': 'fromTheFuture', 'data': '{}'},
      ];
      when(db.getTrainingTotals(any, any, userId: anyNamed('userId'))).thenAnswer(
        (_) async => [
          (start: now, duration: const Duration(minutes: 50), sets: 12, volume: 4200.0),
          (
            start: now.subtract(const Duration(days: 7)),
            duration: const Duration(minutes: 40),
            sets: 9,
            volume: 3100.0,
          ),
        ],
      );
      when(db.getLensSets(any, any, userId: anyNamed('userId'))).thenAnswer(
        (_) async => [
          (
            workoutId: 'w1',
            exerciseId: bench.id,
            start: now,
            movement: Movement.empty(),
            muscles: MuscleTagging.empty(),
            target: Target.chest,
            sets: 4,
          ),
        ],
      );
      when(db.updateChartData(any, any, any)).thenAnswer((_) async {});
    });

    Future<void> tall(WidgetTester tester, {double width = 800}) async {
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('a volume chart and a days-trained heatmap sit among the exercise charts', (tester) async {
      await tall(tester);
      await pumpProfile(tester);

      final context = tester.element(find.byType(MaterialApp));
      final l = L.of(tester.element(find.byType(Scaffold).first));
      expect(Charts.of(context).length, 4);
      final summary = l.chartFrequencySummary(bench.name, 1, frequencyWeeks);
      expect(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == summary),
        findsOneWidget,
      );
    });

    testWidgets("switching a training chart to months stores it in the chart's place", (tester) async {
      await tall(tester);
      await pumpProfile(tester);

      final context = tester.element(find.byType(MaterialApp));
      final l = L.of(tester.element(find.byType(Scaffold).first));
      await tester.tap(find.byTooltip(l.chartPeriod(l.chartByWeek)));
      await tester.pumpTimes();
      await tester.tap(find.text(l.chartByMonth));
      await tester.pumpTimes();

      expect((Charts.of(context).elementAt(2) as TrainingChart).period, ChartPeriod.month);
      verify(db.updateChartData('volume', '{"period":"month"}', 'u1')).called(1);
    });

    testWidgets('on a phone the training cards keep to their row and do not overflow', (tester) async {
      await tall(tester, width: 390);
      await pumpProfile(tester);

      expect(find.byType(SliverReorderableList), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
