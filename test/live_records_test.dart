// Live records (#160): opt-in. A ticked working set that beats a previous
// best gets a quiet note and the pills, from the fold the Done page runs; an
// untick withdraws both. The first set that would have been a record is where
// the feature is offered. The sheet's pieces are private to
// `workout_detail.dart`, so the widget half drives the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);

  RecordSet past(double weight, int reps, String workoutId, String at) {
    return RecordSet(weight: weight, reps: reps, duration: null, distance: null, workoutId: workoutId, at: at);
  }

  final history = [
    past(100, 3, 'w1', '2026-09-01T10:00:00Z'),
    past(90, 8, 'w1', '2026-09-01T10:00:00Z'),
    past(95, 5, 'w2', '2026-09-08T10:00:00Z'),
    past(60, 12, 'w2', '2026-09-08T10:00:00Z'),
  ];

  group('the fold', () {
    ExerciseSet done(double weight, int reps, {SetType type = .normal}) {
      return ExerciseSet(bench, weight: weight, reps: reps)
        ..isCompleted = true
        ..setType = type;
    }

    /// What the Done page says: every set, today's last, folded whole.
    RecordMarks doneMarks(Workout workout) {
      final today = [
        for (final set in workout.expand((entry) => entry))
          if (set.isCompleted && set.setType != .warmup)
            RecordSet(
              weight: set.weight,
              reps: set.reps,
              duration: null,
              distance: null,
              workoutId: workout.id,
              at: workout.start.toUtc().toIso8601String(),
            ),
      ];
      final records = [...history, ...today].toPersonalRecords(bench.category)!;
      return recordMarks(workout, [
        for (final kind in RecordKind.values)
          if (records[kind.key] case Map record when record['workoutId'] == workout.id)
            (exercise: bench, kind: kind, record: record),
      ]);
    }

    RecordMarks live(Workout workout) {
      return liveRecordMarks(workout, {bench.id: history.toPersonalRecords(bench.category)});
    }

    Workout session(List<ExerciseSet> sets) {
      final [first, ...rest] = sets;
      final exercise = WorkoutExercise(starter: first);
      rest.forEach(exercise.add);
      return Workout.fromExercises([exercise]);
    }

    test('agrees with the Done page, set for set', () {
      for (final sets in [
        [done(105, 3)],
        [done(80, 10), done(102, 2)],
        // equalled, not beaten: the record stays with the day that set it
        [done(100, 3)],
        [done(50, 20), done(70, 15)],
        [done(110, 1), done(110, 1)],
      ]) {
        final workout = session(sets);
        expect(live(workout), doneMarks(workout), reason: '$sets');
      }
    });

    test('a heavier set holds the records it beat, on itself', () {
      final heavy = done(105, 5);
      final workout = session([done(60, 5), heavy]);

      expect(live(workout), {
        heavy.id: [RecordKind.maxWeight, RecordKind.oneRepMax],
      });
    });

    test('a warm-up is no one\'s record (#151)', () {
      final workout = session([done(120, 5, type: .warmup)]);
      expect(live(workout), isEmpty);
    });

    test('unticked, the set holds nothing', () {
      final heavy = done(105, 5);
      final workout = session([heavy]);
      heavy.isCompleted = false;
      expect(live(workout), isEmpty);
    });

    test('an exercise with no past sets no record worth a note, and one still being read none at all', () {
      final workout = session([done(105, 5)]);
      expect(liveRecordMarks(workout, {bench.id: null}), isEmpty);
      expect(liveRecordMarks(workout, const {}), isEmpty);
    });
  });

  group('the sheet', () {
    const userId = 'u1';
    late MockLocalDatabase db;
    late MockApi api;
    late MockCdn cdn;

    setUp(() {
      tz.initializeTimeZones();
      FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => call.method == 'initialize' ? true : null,
      );
      db = MockLocalDatabase();
      api = MockApi();
      cdn = MockCdn();
      stubStartup(db, api);
      SharedPreferences.setMockInitialValues({...pastOnboarding(), 'weightUnit': 'metric'});
      when(db.startWorkout(any, any)).thenAnswer((_) async {});
      when(db.storeMeasurements(any)).thenAnswer((_) async {});
      when(db.markSetAsComplete(any)).thenAnswer((_) async {});
      when(db.markSetAsIncomplete(any)).thenAnswer((_) async {});
      when(
        db.setRestTimer(
          exerciseName: anyNamed('exerciseName'),
          userId: anyNamed('userId'),
          seconds: anyNamed('seconds'),
        ),
      ).thenAnswer((_) async {});
      when(db.getRecordWithout(any, any, any)).thenAnswer((_) async => history.toPersonalRecords(bench.category));
    });

    /// A light set and a heavy one, neither ticked.
    Workout pressing() {
      return Workout.fromExercises([
        WorkoutExercise(starter: ExerciseSet(bench, weight: 60, reps: 5))
          ..add(ExerciseSet(bench, weight: 105, reps: 5)),
      ], name: 'Push');
    }

    Future<BuildContext> start(WidgetTester tester, {FeatureAnswer? answer}) async {
      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: userId, email: '$userId@test'),
          signedIn: true,
        ),
        hasLocalNotifications: false,
        settle: false,
      );
      await tester.pumpTimes();
      final context = tester.element(find.byType(MaterialApp));
      switch (answer) {
        case FeatureAnswer.on:
          Preferences.of(context).setFeature(.liveRecords, on: true);
        case FeatureAnswer.off:
          Preferences.of(context).setFeature(.liveRecords, on: false);
        case FeatureAnswer.unasked || FeatureAnswer.pending || null:
          break;
      }
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench]));
      await Workouts.of(context).startWorkout(source: .template, template: pressing());
      await tester.tapByKey(AppKeys.workoutStack);
      await tester.pumpTimes();
      return context;
    }

    final note = find.byKey(WorkoutDetailKeys.liveRecordNote);
    final pills = find.byType(RecordPills);
    final offer = find.byKey(WorkoutDetailKeys.liveRecordsOffer);

    testWidgets('on: a ticked record gets a note and pills, and an untick withdraws both', (tester) async {
      await start(tester, answer: .on);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 1));
      await tester.pumpTimes();
      expect(note, findsNothing, reason: '60 × 5 beats nothing');

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();
      expect(note, findsOneWidget);
      expect(find.text('New records'), findsOneWidget, reason: 'heaviest and 1RM; 525 kg falls short of 720 in volume');
      expect(find.textContaining('Bench Press: '), findsOneWidget);
      expect(pills, findsOneWidget);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();
      expect(note, findsNothing);
      expect(pills, findsNothing);
      // one read when the exercise came in, never one per tick
      verify(db.getRecordWithout(userId, bench, any)).called(1);
    });

    testWidgets('on: the note goes by itself; the pill stays', (tester) async {
      await start(tester, answer: .on);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();
      expect(note, findsOneWidget);

      await tester.pumpTimes(40);
      expect(note, findsNothing);
      expect(pills, findsOneWidget);
    });

    testWidgets('off: as if never built, and nothing read', (tester) async {
      await start(tester, answer: .off);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();

      expect(note, findsNothing);
      expect(pills, findsNothing);
      expect(offer, findsNothing);
      verifyNever(db.getRecordWithout(any, any, any));
    });

    testWidgets('unasked: offered under the first set that would have been a record; a no earns one notice', (
      tester,
    ) async {
      final context = await start(tester);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 1));
      await tester.pumpTimes();
      expect(offer, findsNothing, reason: 'not a record, so not the moment');

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();
      expect(offer, findsOneWidget);
      expect(note, findsNothing);
      expect(pills, findsNothing);
      expect(Preferences.of(context).featureAnswer(.liveRecords), FeatureAnswer.pending);

      await tester.tapByKey(WorkoutDetailKeys.liveRecordsDecline);
      await tester.pumpTimes();
      expect(offer, findsNothing);
      expect(find.byKey(AppKeys.featureDeclinedNotice), findsOneWidget);
      expect(Preferences.of(context).isOn(.liveRecords), isFalse);
    });

    testWidgets('unasked: a yes turns it on in full, the set that asked included', (tester) async {
      final context = await start(tester);

      await tester.tapByKey(WorkoutDetailKeys.doneFor(bench.id, 2));
      await tester.pumpTimes();
      await tester.tapByKey(WorkoutDetailKeys.liveRecordsAccept);
      await tester.pumpTimes();

      expect(Preferences.of(context).isOn(.liveRecords), isTrue);
      expect(offer, findsNothing);
      expect(pills, findsOneWidget);
    });
  });
}
