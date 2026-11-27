// Suspicious entries (#428) through the real app: asked once in History when
// the server has one pending, the whole feature on a yes, one notice on a
// no, and the counts told which way the switch points.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_models/heart_models.dart' as models show Page;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  final pending = Anomaly.fromJson({
    'id': 'a1',
    'workoutId': 'w1',
    'workoutStart': '2026-10-01T08:00:00.000Z',
    'setId': 's1',
    'exerciseName': 'Bench Press',
    'reason': AnomalyReason.outlierWeight,
    'observed': {'weight': 630, 'reps': 5},
    'typical': 100,
    'status': 'pending',
    'detectedAt': '2026-10-02T03:37:00.000Z',
  });

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.getAnomalies(any)).thenAnswer((_) async => [pending]);
    when(db.unsyncedAnomalies(any)).thenAnswer((_) async => []);
    when(db.storeAnomalies(any, any)).thenAnswer((_) async {});
    when(
      api.getAnomalies(userId: anyNamed('userId'), cursor: anyNamed('cursor'), limit: anyNamed('limit')),
    ).thenAnswer((_) async => models.Page(items: [pending], hasMore: false));
  });

  Future<BuildContext> openHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await const TestAppHarness().pumpHeartApp(
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
    await tester.pumpTimes();
    final context = tester.element(find.byType(MaterialApp));
    // `_initApp` never gets this far in a widget test
    await Anomalies.of(context).init();
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
    return context;
  }

  testWidgets('a yes turns it on: the offer goes, and History gets its way to the list', (tester) async {
    final context = await openHistory(tester);

    expect(find.byKey(AppKeys.entryReviewOffer), findsOneWidget);
    expect(find.byKey(AppKeys.entryReviewButton), findsNothing, reason: 'unasked is off');

    await tester.tapByKey(AppKeys.entryReviewAccept);
    await tester.pumpTimes();

    expect(Preferences.of(context).isOn(.entryReview), isTrue);
    expect(find.byKey(AppKeys.entryReviewOffer), findsNothing);
    expect(find.tooltip('Second look: 1 to look at'), findsOneWidget);
    // the counts leave discarded entries out from here on
    verify(db.leavesOutDiscarded = true).called(1);
  });

  testWidgets('a no earns the one notice, and History is as it was', (tester) async {
    final context = await openHistory(tester);

    await tester.tapByKey(AppKeys.entryReviewDecline);
    await tester.pumpTimes();

    expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
    expect(find.byKey(AppKeys.entryReviewButton), findsNothing);
    expect(Preferences.of(context).featureAnswer(.entryReview), FeatureAnswer.off);
    verifyNever(db.leavesOutDiscarded = true);
  });

  testWidgets('the switch is live both ways, and off is never asked again', (tester) async {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-entryReview': 'on'});
    final context = await openHistory(tester);
    expect(find.byKey(AppKeys.entryReviewButton), findsOneWidget);

    Preferences.of(context).setFeature(.entryReview, on: false);
    await tester.pumpTimes();

    expect(find.byKey(AppKeys.entryReviewButton), findsNothing);
    expect(find.byKey(AppKeys.entryReviewOffer), findsNothing);
    verify(db.leavesOutDiscarded = false).called(greaterThan(0));
  });
}
