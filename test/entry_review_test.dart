// Suspicious entries (#428): the mark beside a flagged entry, the decision it
// opens, the list of every one, and the feature off.
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/entry_review.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';

/// The mirror: what is resolved stays resolved. The remote leg stays closed.
class _Store implements LocalAnomalyService {
  final rows = <String, Anomaly>{};

  new(Iterable<Anomaly> anomalies) {
    rows.addEntries(anomalies.map((each) => MapEntry(each.id, each)));
  }

  @override
  Future<List<Anomaly>> getAnomalies(String userId) async => rows.values.toList();

  @override
  Future<List<Anomaly>> unsyncedAnomalies(String userId) async => const [];

  @override
  Future<void> storeAnomalies(Iterable<Anomaly> anomalies, String userId) async {}

  @override
  Future<void> storeAnomaly(Anomaly anomaly, String userId) async => rows[anomaly.id] = anomaly;

  @override
  Future<void> resolveAnomaly(String anomalyId, AnomalyStatus status, {required DateTime at}) async {
    rows[anomalyId] = Anomaly.fromJson({...rows[anomalyId]!.toMap(), 'status': status.value});
  }
}

Anomaly _anomaly(
  String id, {
  String? setId = 's2',
  String reason = 'outlier_weight',
  String status = 'pending',
  Map<String, dynamic> observed = const {'weight': 630, 'reps': 5},
}) {
  return Anomaly.fromJson({
    'id': id,
    'workoutId': 'w1',
    'workoutStart': '2026-10-01T08:00:00.000Z',
    'setId': ?setId,
    'exerciseName': 'Bench Press',
    'reason': reason,
    'observed': observed,
    'typical': 100,
    'status': status,
    'detectedAt': '2026-10-02T03:37:00.000Z',
  });
}

void main() {
  late Preferences preferences;
  late Anomalies anomalies;
  late Exercises exercises;

  Future<void> setUpWith(Iterable<Anomaly> rows, {bool on = true}) async {
    SharedPreferences.setMockInitialValues({if (on) 'feature-entryReview': 'on'});
    preferences = Preferences();
    await preferences.init();
    final store = _Store(rows);
    anomalies = Anomalies(service: store, remoteService: MockApi(), remote: RemoteAccess(allowed: false))
      ..userId = 'muffin';
    await anomalies.init();
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Anomalies>.value(value: anomalies),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  /// A past workout's page, as far as the marks go: the set s2 and the
  /// workout's duration.
  Widget page() {
    return EntryReviewScope(
      workoutId: 'w1',
      child: Builder(
        builder: (context) => Column(
          children: [
            if (EntryReviewScope.ofSet(context, 's2') case final Anomaly anomaly) AnomalyMark(anomaly: anomaly),
            if (EntryReviewScope.ofDuration(context) case final Anomaly anomaly) AnomalyMark(anomaly: anomaly),
          ],
        ),
      ),
    );
  }

  testWidgets('a flagged set is marked with its reason, and the mark says what it is', (tester) async {
    final semantics = tester.ensureSemantics();
    await setUpWith([_anomaly('a1')]);
    await pump(tester, page());

    expect(find.text('Unusual weight'), findsOneWidget);
    expect(find.bySemanticsLabel('Unusual weight: decide what to do with this entry'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('leaving it out keeps it marked, as left out, and counts it out', (tester) async {
    await setUpWith([_anomaly('a1')]);
    await pump(tester, page());

    await tester.tap(find.byKey(AppKeys.anomalyMark('a1')));
    await tester.pumpAndSettle();
    expect(find.text('630 kg is far from the 100 kg you usually lift on this exercise.'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.anomalyDecision('leaveOut')));
    await tester.pumpAndSettle();

    expect(find.text('Left out'), findsOneWidget);
    expect(anomalies.discardedSets, {'s2'});
  });

  testWidgets('a kept entry carries no mark: the question was answered', (tester) async {
    await setUpWith([_anomaly('a1')]);
    await pump(tester, page());

    await tester.tap(find.byKey(AppKeys.anomalyMark('a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.anomalyDecision('keep')));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.anomalyMark('a1')), findsNothing);
    expect(anomalies.single.status, AnomalyStatus.valid);
  });

  testWidgets('a reason this build does not know still reads, as something that looks off', (tester) async {
    await setUpWith([_anomaly('a1', reason: 'duplicate_session')]);
    await pump(tester, page());

    expect(find.text('Looks off'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.anomalyMark('a1')));
    await tester.pumpAndSettle();
    expect(find.text('Something about this entry looks unusual.'), findsOneWidget);
  });

  testWidgets('a workout left running is marked on its duration, in hours', (tester) async {
    await setUpWith([
      _anomaly('a1', setId: null, reason: 'duration_left_running', observed: {'seconds': 7 * 3600 + 12 * 60}),
    ]);
    await pump(tester, page());

    expect(find.text('Left running?'), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.anomalyMark('a1')));
    await tester.pumpAndSettle();
    expect(find.text('This workout ran for 7 h 12 min. Was the timer left on?'), findsOneWidget);
  });

  testWidgets('off, nothing is marked, and a discarded set is still kept', (tester) async {
    await setUpWith([_anomaly('a1', status: 'invalid')], on: false);
    await pump(tester, page());

    expect(find.byType(AnomalyMark), findsNothing);
    expect(anomalies.discardedSets, {'s2'}, reason: 'off hides; it never forgets');

    preferences.setFeature(.entryReview, on: true);
    await tester.pump();
    expect(find.text('Left out'), findsOneWidget);
  });

  testWidgets('the list holds what is still to look at, then what was decided, and opens the workout', (tester) async {
    await setUpWith([
      _anomaly('a1'),
      _anomaly('a2', setId: 's3', status: 'invalid'),
      _anomaly('a3', setId: null, reason: 'duration_left_running', observed: {'seconds': 30000}),
    ]);
    String? opened;
    await pump(tester, EntryReviewPage(onOpenWorkout: (id) => opened = id));
    await tester.pumpAndSettle();

    expect(find.text('TO LOOK AT'), findsOneWidget);
    expect(find.text('DECIDED'), findsOneWidget);
    expect(find.text('Workout duration'), findsOneWidget);
    expect(find.textContaining('Left out'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.anomalyRow('a1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.anomalyDecision('open')));
    await tester.pumpAndSettle();
    expect(opened, 'w1');
  });

  testWidgets('on a tablet the list keeps a measure rather than the pane\'s width', (tester) async {
    tester.view.physicalSize = const Size(1194, 834);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setUpWith([_anomaly('a1'), _anomaly('a2', setId: 's3', status: 'valid')]);

    await pump(tester, EntryReviewPage(onOpenWorkout: (_) {}));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(AppKeys.entryReviewPage)).width, readableWidth);
    expect(tester.getSize(find.byKey(AppKeys.anomalyRow('a1'))).width, readableWidth);
  });
}
