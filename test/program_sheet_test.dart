// A program's targets on the sheet (#349): the plan's line under each
// exercise, the supplemental sets, a lighter cycle said once, planned rest,
// an open slot's swap, and the finish that names what is left unticked. The
// pieces are private to `workout_detail.dart`, so these drive the real app.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/column_fill.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  const userId = 'u1';
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);
  final front = Exercise(name: 'Front Squat', category: .barbell, target: .legs);
  final program = Program(id: 'p1', name: 'Waves', perWeek: 3, createdAt: DateTime.utc(2026, 10, 1));

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  void programs({required bool on}) {
    SharedPreferences.setMockInitialValues({
      ...pastOnboarding(),
      'weightUnit': 'metric',
      'distanceUnit': 'metric',
      'feature-programs': switch (on) {
        true => FeatureAnswer.on.name,
        false => FeatureAnswer.off.name,
      },
    });
  }

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
    programs(on: true);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(db.storeMeasurements(any)).thenAnswer((_) async {});
    when(db.markSetAsComplete(any)).thenAnswer((_) async {});

    when(db.getPrograms(userId)).thenAnswer((_) async => [program]);
    when(api.getPrograms()).thenAnswer((_) async => [program]);
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramMarks(userId, any)).thenAnswer((_) async => []);
    when(db.storePrograms(any, any)).thenAnswer((_) async {});
    when(db.storeProgramActions(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBases(any, any)).thenAnswer((_) async {});
    when(api.getProgramActions(any)).thenAnswer((_) async => []);
    when(api.getProgramBases(any)).thenAnswer((_) async => []);
  });

  /// Squat day: three sets at shares of the squat's max, the last of them
  /// supplemental, and a front squat at a share of the squat's.
  Workout squatDay({int? rest, String? pattern, TargetRange? totalReps}) {
    final main = SetTarget({.reps: TargetRange.exactly(5), .weight: TargetRange.exactly(77.5)}, share: 0.65, rir: 2);
    final top = SetTarget({.reps: const TargetRange(min: 5, max: 10, amrap: true)}, share: 0.85);
    final extra = SetTarget({.reps: TargetRange.exactly(5)}, share: 0.6, supplemental: true);
    final squats = WorkoutExercise(starter: ExerciseSet(squat, target: main))
      ..rest = rest
      ..pattern = pattern
      ..totalReps = totalReps;
    squats
      ..add(ExerciseSet(squat, target: top))
      ..add(ExerciseSet(squat, target: extra));
    final fronts = WorkoutExercise(
      starter: ExerciseSet(front, target: SetTarget({.reps: TargetRange.exactly(5)}, share: 0.55, of: squat.id)),
    );
    return Workout.fromExercises([squats, fronts], name: 'Squat day', programId: 'p1');
  }

  /// Signs in, reads the program, and opens [workout] as the active one.
  Future<BuildContext> start(WidgetTester tester, Workout workout) async {
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
    await Programs.of(context).init();
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat, front]));
    await Workouts.of(context).startWorkout(source: .program, template: workout);
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    if (find.byType(WorkoutDetail).evaluate().isEmpty) {
      await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
      await tester.pumpTimes();
    }
    return context;
  }

  testWidgets('each exercise says its plan in a line, and a supplemental set is marked', (tester) async {
    await start(tester, squatDay(totalReps: const TargetRange(min: 50, max: 100)));

    expect(
      find.text(
        '5, 5+ at 65%–85% of your max · as many as you can, up to 10 · stop with 2 in reserve'
        ' · then 1×5 at 60% of your max · 50–100 reps in all',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('at 55% of your'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Supplemental set')), findsOneWidget);
  });

  testWidgets('with Programs off the sheet is as it was', (tester) async {
    programs(on: false);
    await start(tester, squatDay(rest: 90, pattern: 'squat'));

    expect(find.textContaining('of your max'), findsNothing);
    expect(find.text('+'), findsNothing);
    // no plan to rest by, and no user timer: no timer in the header
    expect(find.byTooltip(L.of(tester.element(find.byType(WorkoutDetail))).restTimer), findsNothing);
  });

  testWidgets("a plan's rest is the exercise's timer while the user has set none", (tester) async {
    await start(tester, squatDay(rest: 90));

    expect(find.byTooltip(L.of(tester.element(find.byType(WorkoutDetail))).restTimer), findsOneWidget);
  });

  testWidgets('an open slot offers a swap until a set of it is ticked', (tester) async {
    final workout = squatDay(pattern: 'squat');
    final context = await start(tester, workout);
    final squats = workout.first;

    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
    expect(find.byKey(WorkoutDetailKeys.swapExerciseFor(squat.id)), findsOneWidget);
    expect(find.text('Open slot: Squat'), findsNothing, reason: 'the line says it, the menu is the menu');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpTimes();

    Workouts.of(context).markSetAsComplete(squats, squats.first);
    await tester.pumpTimes();
    await tester.tapByKey(WorkoutDetailKeys.exerciseOptionsFor(squat.id));
    await tester.pumpTimes();
    expect(find.byKey(WorkoutDetailKeys.swapExerciseFor(squat.id)), findsNothing);
  });

  testWidgets("the session's note says what it is for, at the top", (tester) async {
    final draft = Template.empty(id: 't1', order: 0)..name = 'Test day';
    final session = Template.fromJson({
      ...draft.toMap(),
      'programId': 'p1',
      'note': 'Work up to one heavy set of three to five reps',
    });
    when(db.getTemplates(userId)).thenAnswer((_) async => [session]);
    final day = squatDay();
    await start(tester, Workout.fromExercises(day, name: 'Test day', templateId: 't1', programId: 'p1'));
    await Templates.of(tester.element(find.byType(MaterialApp))).init();
    await tester.pumpTimes();

    expect(find.byKey(WorkoutDetailKeys.sessionNote), findsOneWidget);
    expect(find.text('Work up to one heavy set of three to five reps'), findsOneWidget);
  });

  testWidgets("a session's workout is marked, and the mark opens its program", (tester) async {
    await start(tester, squatDay());
    final mark = find.byKey(AppKeys.partOfProgram('p1'));
    expect(mark, findsOneWidget);
    expect(find.byTooltip('Open Waves'), findsOneWidget);

    await tester.tap(mark);
    await tester.pumpTimes();
    expect(find.byType(WorkoutDetail), findsNothing, reason: 'the sheet stepped aside');
    expect(find.text('Waves'), findsWidgets);
  });

  testWidgets('a workout of no program has no mark', (tester) async {
    programs(on: true);
    await start(tester, Workout.fromExercises(squatDay(), name: 'Mine'));
    expect(find.byKey(AppKeys.partOfProgram('p1')), findsNothing);
  });

  testWidgets("a session's value columns are labels, not fills: the plan's values stay", (tester) async {
    await start(tester, squatDay());
    expect(find.byKey(WorkoutDetailKeys.fillFor(squat.id, SetColumn.reps.key)), findsNothing);
    expect(find.byKey(WorkoutDetailKeys.fillFor(squat.id, SetColumn.weight.key)), findsNothing);
    // the ✓ still ticks the column
    expect(find.byKey(WorkoutDetailKeys.tickAllFor(squat.id)), findsOneWidget);
  });

  testWidgets('with Programs off, the columns fill as ever', (tester) async {
    programs(on: false);
    await start(tester, squatDay());
    expect(find.byKey(WorkoutDetailKeys.fillFor(squat.id, SetColumn.reps.key)), findsOneWidget);
  });

  testWidgets('a session with no note says nothing', (tester) async {
    await start(tester, squatDay());
    expect(find.byKey(WorkoutDetailKeys.sessionNote), findsNothing);
  });

  testWidgets('a lighter cycle says so once, at the top', (tester) async {
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer(
      (_) async => [ProgramAction(id: 'a1', programId: 'p1', kind: .lighter, at: DateTime.now())],
    );
    await start(tester, squatDay());

    expect(find.text('A lighter week: 90% of the weight, 50% of the sets'), findsOneWidget);
  });

  testWidgets('finishing names the sets a program session leaves unticked', (tester) async {
    final workout = squatDay();
    final context = await start(tester, workout);
    final squats = workout.first;
    Workouts.of(context).markSetAsComplete(squats, squats.first);
    await tester.pumpTimes();

    final sheet = tester.element(find.byType(WorkoutDetail));
    showFinishWorkoutDialog(sheet, Workouts.of(sheet));
    await tester.pumpTimes();

    expect(find.text('Only ticked sets are saved:'), findsOneWidget);
    expect(find.text('Squat: sets 2, 3'), findsOneWidget);
    expect(find.text('Front Squat: set 1'), findsOneWidget);
    // nothing typed, so nothing to keep but the ticks
    expect(find.text(L.of(sheet).saveUntickedSets), findsNothing);
    expect(find.text(L.of(sheet).discardUntickedSets), findsOneWidget);
  });
}
