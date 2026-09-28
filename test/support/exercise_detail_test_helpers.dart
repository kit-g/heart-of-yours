import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import '../mocks.mocks.dart';

/// Neither [Goals] leg is exercised by the exercise detail tabs (the chart
/// tab only reads goals to plot rungs), and neither has a generated mock in
/// `test/mocks.dart` — a `Fake` throws only if a test actually calls into it,
/// which none of these do.
class FakeGoalService extends Fake implements LocalGoalService {
  // no members: nothing in these tests calls into a goal service
}

/// A hand-rolled [ExerciseAct] — the real one is built from raw db rows via
/// [ExerciseAct.fromRows], which is more machinery than a fixture needs here.
class TestExerciseAct with Iterable<ExerciseSet> implements ExerciseAct {
  @override
  final String? workoutName;
  @override
  final String workoutId;
  @override
  final DateTime? start;
  final List<ExerciseSet> sets;

  new({
    required this.workoutId,
    this.workoutName,
    this.start,
    this.sets = const [],
  });

  @override
  Iterator<ExerciseSet> get iterator => sets.iterator;

  @override
  int compareTo(ExerciseAct other) {
    return switch ((start, other.start)) {
      (DateTime one, DateTime two) => two.compareTo(one),
      _ => 0,
    };
  }
}

/// Everything the exercise detail page's tabs read from context, built from
/// the generated nice mocks so unstubbed calls answer with harmless defaults
/// instead of throwing.
class ExerciseDetailState {
  final Exercises exercises;
  final Workouts workouts;
  final Preferences preferences;
  final Charts charts;
  final Goals goals;
  final MockExerciseService exerciseService;
  final MockWorkoutService workoutService;
  final MockChartPreferenceService chartService;

  new({
    required this.exercises,
    required this.workouts,
    required this.preferences,
    required this.charts,
    required this.goals,
    required this.exerciseService,
    required this.workoutService,
    required this.chartService,
  });
}

/// Builds the provider stack the exercise detail page's tabs read from —
/// [Exercises] for the records/history/chart lookups and per-exercise unit,
/// [Workouts] because both stateful tabs listen to it to invalidate their
/// query, [Preferences] for unit-aware formatting, and [Charts]/[Goals]
/// because the charts tab always builds (every exercise has one) and reads
/// both.
///
/// Remote access is switched off so seeding exercises through [makeExercise]
/// never reaches for [RemoteExerciseService] — a plain nice mock would answer
/// harmlessly anyway, but this keeps the fixture's intent explicit.
Future<ExerciseDetailState> buildExerciseDetailState({String? userId = 'u1'}) async {
  SharedPreferences.setMockInitialValues({});

  final exerciseService = MockExerciseService();
  // The real db-backed service never resolves this to null — a never-touched
  // metric is an empty list, which is what drives the charts tab's empty
  // state (see ExerciseChart's phase switch). A nice mock's default of `null`
  // would instead hit its silent "no data at all yet" branch.
  when(
    exerciseService.getExerciseMetics(any, any, any, limit: anyNamed('limit')),
  ).thenAnswer((_) async => []);

  final exercises = Exercises(
    service: exerciseService,
    remoteService: MockRemoteExerciseService(),
    libraryService: MockExerciseLibraryService(),
    catalogService: MockLocalCatalogService(),
    preferenceService: MockRemoteExercisePreferenceService(),
    remote: RemoteAccess(allowed: false),
  )..userId = userId;

  final workoutService = MockWorkoutService();
  final workouts = Workouts(
    service: workoutService,
    remoteService: MockRemoteWorkoutService(),
  )..userId = userId;

  final preferences = Preferences();
  await preferences.init();

  final chartService = MockChartPreferenceService();
  final charts = Charts(service: chartService)..userId = userId;

  final goals = Goals(
    service: FakeGoalService(),
    remoteService: FakeGoalService(),
  );

  return ExerciseDetailState(
    exercises: exercises,
    workouts: workouts,
    preferences: preferences,
    charts: charts,
    goals: goals,
    exerciseService: exerciseService,
    workoutService: workoutService,
    chartService: chartService,
  );
}

/// Pumps the real [ExerciseDetailPage] (Material or Cupertino, depending on
/// [platform]) over a provider stack built by [buildExerciseDetailState],
/// landing on [initialTab] — an explicit tab always wins over the
/// session-remembered one (see `_initialSection` in utils.dart), which keeps
/// tests from leaking state into each other through that static.
///
/// A non-null [platform] sets [debugDefaultTargetPlatformOverride] but does
/// *not* schedule the reset — flutter_test's own end-of-test invariant check
/// runs before `addTearDown` callbacks fire, so a caller reaching for
/// [platform] must wrap its whole test body in `try`/`finally` and reset it
/// there (see exercise_cupertino_detail_test.dart).
Future<ExerciseDetailState> pumpExerciseDetail(
  WidgetTester tester,
  Exercise exercise, {
  String? initialTab,
  Future<void> Function(String)? onTapWorkout,
  Future<void> Function(Exercise)? onAddToWorkout,
  void Function(Exercise, {String? tab})? onShareExercise,
  TargetPlatform? platform,
  Size size = const Size(390, 844),
  ExerciseDetailState? state,
}) async {
  final resolved = state ?? await buildExerciseDetailState();

  if (platform != null) {
    debugDefaultTargetPlatformOverride = platform;
  }

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<Exercises>.value(value: resolved.exercises),
        ChangeNotifierProvider<Workouts>.value(value: resolved.workouts),
        ChangeNotifierProvider<Preferences>.value(value: resolved.preferences),
        ChangeNotifierProvider<Charts>.value(value: resolved.charts),
        ChangeNotifierProvider<Goals>.value(value: resolved.goals),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: Scaffold(
          body: ExerciseDetailPage(
            exercise: exercise,
            onTapWorkout: onTapWorkout ?? (_) async {},
            onAddToWorkout: onAddToWorkout,
            onShareExercise: onShareExercise,
            initialTab: initialTab,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return resolved;
}
