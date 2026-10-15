// A program session's Done page (#350, #351): what its rules moved, each with
// a "Keep" that takes that one move back, and nothing of it with Programs
// off. Driven through the real app and router, as program_screens_test.dart.
import 'dart:async';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  const userId = 'u1';

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  final program = Program(
    id: 'p1',
    name: 'Split',
    perWeek: 3,
    weeks: 8,
    sessions: const ['t1'],
    rules: {bench.id: const AddWeight(step: 2.5)},
    createdAt: DateTime.utc(2026, 10, 1),
  );
  final base = ProgramBase(id: 'b1', programId: 'p1', exerciseId: bench.id, value: 100, at: DateTime.utc(2026, 10, 1));

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.startWorkout(any, any)).thenAnswer((_) async {});
    when(cdn.getSampleTemplates()).thenAnswer((_) async => <Template>[]);
    when(db.getTemplates(any)).thenAnswer((_) async => <Template>[]);
    when(api.getTemplates()).thenAnswer((_) async => null);

    when(db.getPrograms(userId)).thenAnswer((_) async => [program]);
    when(api.getPrograms()).thenAnswer((_) async => [program]);
    when(db.getProgramActions(userId, programId: anyNamed('programId'))).thenAnswer((_) async => []);
    when(db.getProgramBases(userId, programId: anyNamed('programId'))).thenAnswer((_) async => [base]);
    when(db.getProgramMarks(userId, any)).thenAnswer((_) async => []);
    when(db.getProgramWorkouts(userId, any)).thenAnswer((_) async => []);
    when(db.storePrograms(any, any)).thenAnswer((_) async {});
    when(db.storeProgramActions(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBases(any, any)).thenAnswer((_) async {});
    when(db.storeProgramBase(any)).thenAnswer((_) async {});
    when(db.deleteProgramBase(any)).thenAnswer((_) async {});
    when(api.getProgramActions(any)).thenAnswer((_) async => []);
    when(api.getProgramBases(any)).thenAnswer((_) async => [base]);
    when(api.replayProgramBase(any)).thenAnswer(
      (i) async => (row: i.positionalArguments.single as ProgramBase, created: true),
    );
    when(api.deleteProgramBase(any, any)).thenAnswer((_) async {});
  });

  /// A session of [program] with every bench set made, on its Done page.
  Future<void> finishSession(WidgetTester tester, {required FeatureAnswer programs}) async {
    SharedPreferences.setMockInitialValues({...pastOnboarding(), 'feature-programs': programs.name});
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
    final context = tester.element(find.byType(MaterialApp));
    await Programs.of(context).init();
    final sets = WorkoutExercise(starter: ExerciseSet(bench, weight: 100, reps: 5)..isCompleted = true);
    await Workouts.of(context).startWorkout(
      source: .program,
      template: Workout.fromExercises([sets], name: 'Day A', programId: 'p1'),
    );
    await tester.pumpTimes();
    final workout = Workouts.of(context).activeWorkout!;
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/done?workoutId=${workout.id}');
    await tester.pumpTimes();
    if (programs == .on) unawaited(Programs.of(context).grow(workout));
    await tester.pumpTimes();
  }

  testWidgets('what moved is said, and Keep takes that one move back', (tester) async {
    await finishSession(tester, programs: .on);

    expect(find.byKey(AppKeys.doneProgram), findsOneWidget);
    expect(find.textContaining('next time'), findsOneWidget);
    final written = verify(db.storeProgramBase(captureAny)).captured.first as ProgramBase;
    expect(written.value, 102.5);

    await tester.tap(find.textContaining('Keep'));
    await tester.pumpTimes();

    verify(db.deleteProgramBase(written.id)).called(1);
    expect(find.textContaining('Keeping'), findsOneWidget);
    expect(find.textContaining('Keep '), findsNothing);
  });

  testWidgets('with Programs off the page is as it always was', (tester) async {
    await finishSession(tester, programs: .off);

    expect(find.byKey(AppKeys.doneProgram), findsNothing);
    verifyNever(db.storeProgramBase(any));
  });
}
