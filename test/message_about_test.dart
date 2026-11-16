import 'package:clock/clock.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/messages/messages.dart' show ThreadPage;
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A student writing to their coach about a workout of theirs (#556): from
/// its card in History, the conversation opens with the next message about
/// it. Only with a coach, Your coach on, and somewhere to keep keys.
void main() {
  late MockLocalDatabase db;
  late MockApi api;

  final squat = Exercise.fromJson({'id': 'squat', 'name': 'Squat', 'category': 'Barbell', 'target': 'Legs'});
  final now = DateTime(2026, 11, 20, 12);
  final dayA = () {
    final workout = Workout(name: 'Day A')..start = DateTime(2026, 11, 18, 9);
    workout.add(squat);
    workout.completeAllSets();
    return workout..finish(DateTime(2026, 11, 18, 10));
  }();

  final coach = Connection(
    targetId: 'alex',
    role: .student,
    domain: .fitness,
    status: .active,
    createdAt: DateTime.utc(2026, 11, 8),
    connectionId: 'c1',
    acceptedAt: DateTime.utc(2026, 11, 8),
    name: 'Alex',
  );
  final thread = Thread(id: 't1', connectionId: 'c1', otherId: 'alex', otherName: 'Alex');

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    stubStartup(db, api);
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [dayA]);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat]));
    when(api.getHiddenWorkouts()).thenAnswer((_) async => []);
    when(api.openThread('c1')).thenAnswer((_) async => thread);
    when(api.getThreads()).thenAnswer((_) async => [thread]);
    when(api.getThreadItems('t1', limit: anyNamed('limit')))
        .thenAnswer((_) async => (items: <ThreadItem>[], cursor: null));
  });

  final strength = Connection(
    targetId: 'sam',
    role: .student,
    domain: .running,
    status: .active,
    createdAt: DateTime.utc(2026, 11, 9),
    connectionId: 'c2',
    acceptedAt: DateTime.utc(2026, 11, 9),
    name: 'Sam',
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool coached,
    KeyVault? keyVault,
    List<Connection>? coaches,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    when(api.getConnections()).thenAnswer((_) async => coaches ?? (coached ? [coach] : <Connection>[]));
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-yourCoach': 'on'});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'muffin', email: 'muffin@test'),
        signedIn: true,
      ),
      keyVault: keyVault,
      settle: false,
    );
    await tester.tapByKey(AppKeys.historyStack);
    await tester.pumpTimes();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(HistoryPage), matching: find.byTooltip('More options')).first);
    await tester.pumpTimes();
  }

  testWidgets("a workout's menu writes to the coach about it", (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, coached: true, keyVault: MemoryKeyVault());
      await openMenu(tester);

      await tester.tapByKey(AppKeys.messageCoachAbout);
      await tester.pumpTimes();

      expect(find.byType(ThreadPage), findsOneWidget);
      final messages = Messages.of(tester.element(find.byType(ThreadPage)));
      expect(messages.about('c1'), MessageSubject(.workout, dayA.id));
      expect(find.textContaining('About Day A'), findsOneWidget, reason: 'one of their own, named over the box');
    });
  });

  testWidgets('with no coach, or nowhere to keep keys, the menu offers nothing of the kind', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, coached: false, keyVault: MemoryKeyVault());
      await openMenu(tester);
      expect(find.byKey(AppKeys.messageCoachAbout), findsNothing);
    });
  });

  testWidgets('without a vault, as on the web, there is no message to write either', (tester) async {
    await withClock(Clock.fixed(now), () async {
      await pump(tester, coached: true);
      await openMenu(tester);
      expect(find.byKey(AppKeys.messageCoachAbout), findsNothing);
    });
  });

  testWidgets('with a coach in each of two domains, the one to write to is picked', (tester) async {
    await withClock(Clock.fixed(now), () async {
      final second = Thread(id: 't2', connectionId: 'c2', otherId: 'sam', otherName: 'Sam');
      when(api.openThread('c2')).thenAnswer((_) async => second);
      when(api.getThreads()).thenAnswer((_) async => [thread, second]);
      when(api.getThreadItems('t2', limit: anyNamed('limit')))
          .thenAnswer((_) async => (items: <ThreadItem>[], cursor: null));
      await pump(tester, coached: true, keyVault: MemoryKeyVault(), coaches: [coach, strength]);
      await openMenu(tester);

      await tester.tapByKey(AppKeys.messageCoachAbout);
      await tester.pumpTimes();
      expect(find.text('Alex'), findsOneWidget);
      await tester.tapByKey(AppKeys.messageCoachPick('c2'));
      await tester.pumpTimes();

      final messages = Messages.of(tester.element(find.byType(ThreadPage)));
      expect(messages.about('c2'), MessageSubject(.workout, dayA.id));
      expect(messages.about('c1'), isNull);
    });
  });

  testWidgets("a message about one's own workout opens it over the conversation, and Back returns there", (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final item = ThreadItem(
        id: 'i1',
        threadId: 't1',
        senderId: 'alex',
        kind: 'message',
        subjectType: 'workout',
        subjectId: dayA.id,
        content: 'm1.session.ciphertext',
        commitment: 'c',
        tag: 't',
        tagKey: 'k',
        at: DateTime.utc(2026, 11, 19, 9),
        createdAt: DateTime.utc(2026, 11, 19, 9),
        cursor: 'c1',
      );
      when(api.getThreadItems('t1', limit: anyNamed('limit'))).thenAnswer((_) async => (items: [item], cursor: null));
      final stored = <String, StoredItem>{};
      when(db.getThreads(any)).thenAnswer((_) async => []);
      when(db.storeThreads(any, any)).thenAnswer((_) async {});
      when(db.storeThread(any, any)).thenAnswer((_) async {});
      when(db.storeThreadItems(any, any)).thenAnswer((invocation) async {
        for (final each in invocation.positionalArguments[1] as Iterable<StoredItem>) {
          stored[each.item.id] = each;
        }
      });
      when(db.getThreadItems(any, any)).thenAnswer((_) async => stored.values.toList());
      await pump(tester, coached: true, keyVault: MemoryKeyVault());
      HeartRouter.of(tester.element(find.byType(HistoryPage))).openThread('c1');
      await tester.pumpTimes();

      expect(find.textContaining('About Day A'), findsOneWidget);
      await tester.tapByKey(AppKeys.messageSubject);
      await tester.pumpTimes();
      expect(find.byType(WorkoutEditor), findsOneWidget);

      await tester.pageBack();
      await tester.pumpTimes();
      expect(find.byType(ThreadPage), findsOneWidget);
    });
  });
}
