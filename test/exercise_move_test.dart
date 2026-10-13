import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart_api/heart_api.dart' show ExerciseMoveRefusal, ExerciseMoveRefused;
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart' hide Page;
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/exercise_detail_test_helpers.dart';

/// Moving an exercise's history onto another, from its page (#338).
void main() {
  Exercise lift(String name, {bool mine = false}) {
    return Exercise.fromJson({
      'id': 'id-$name',
      'name': name,
      'category': 'Barbell',
      'target': 'Chest',
      'isMine': mine,
    });
  }

  final bench = lift('Bench Press');
  final incline = lift('Incline Bench Press');
  final custom = lift('My Bench', mine: true);

  late _Moves moves;
  late RemoteAccess access;
  late Exercises exercises;
  late Workouts workouts;
  late Preferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    moves = _Moves();
    access = RemoteAccess();

    final service = MockExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[custom]));
    when(service.getExerciseUnits(any)).thenAnswer((_) async => {});
    final library = MockExerciseLibraryService();
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
      (_) async => (
        (exercises: [bench, incline], glossary: SearchGlossary.empty()),
        (version: 'run-1', locale: 'en', etag: null),
      ),
    );
    final catalog = MockLocalCatalogService();
    when(
      catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary')),
    ).thenAnswer((_) async {});
    final remote = MockRemoteExerciseService();
    when(remote.getOwnExercises()).thenAnswer((_) async => [custom]);
    final preferenceService = MockRemoteExercisePreferenceService();
    when(preferenceService.getExercisePreferences()).thenAnswer((_) async => []);
    exercises = Exercises(
      remoteService: remote,
      service: service,
      libraryService: library,
      catalogService: catalog,
      preferenceService: preferenceService,
      moveService: moves,
      remote: access,
    )..userId = 'u1';
    await exercises.init();

    workouts = Workouts(service: MockWorkoutService(), remoteService: MockRemoteWorkoutService())..userId = 'u1';
  });

  Future<List<Exercise>> pump(WidgetTester tester, Exercise exercise, {bool movable = true}) async {
    final moved = <Exercise>[];
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final templates = MockTemplateService();
    when(templates.getTemplates(any)).thenAnswer((_) async => <Template>[]);
    final timers = MockTimersService();
    when(timers.getTimers(any)).thenAnswer((_) async => <String, int>{});
    final previous = MockPreviousExerciseService();
    when(previous.getPreviousSets(any)).thenAnswer((_) async => {});
    final charts = MockChartPreferenceService();
    when(charts.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);
    when(charts.saveChartPreference(any, any)).thenAnswer((inv) async => inv.positionalArguments.first);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Charts>(create: (_) => Charts(service: charts)..userId = 'u1'),
          ChangeNotifierProvider<Goals>(
            create: (_) => Goals(service: FakeGoalService(), remoteService: FakeGoalService()),
          ),
          ChangeNotifierProvider<Templates>(
            create: (_) => Templates(
              service: templates,
              remoteService: MockRemoteTemplateService(),
              configService: MockRemoteConfigService(),
              folderService: _UnusedFolders(),
              remoteFolderService: _UnusedRemoteFolders(),
              filingService: _UnusedFiling(),
            )..userId = 'u1',
          ),
          ChangeNotifierProvider<Timers>(create: (_) => Timers(service: timers)..userId = 'u1'),
          ChangeNotifierProvider<PreviousExercises>(
            create: (_) => PreviousExercises(service: previous)..userId = 'u1',
          ),
          Provider<Scrolls>.value(value: Scrolls()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: ExerciseDetailPage(
              exercise: exercise,
              onTapWorkout: (_) async {},
              initialTab: 'history',
              onHistoryMoved: switch (movable) {
                true => moved.add,
                false => null,
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return moved;
  }

  L copy(WidgetTester tester) => L.of(tester.element(find.byType(Scaffold).first));

  testWidgets('a library exercise gets a menu holding only the move', (tester) async {
    await pump(tester, bench);
    final l = copy(tester);

    await tester.tap(find.byTooltip(l.exerciseOptions));
    await tester.pumpAndSettle();

    expect(find.text(l.moveHistory), findsOneWidget);
    expect(find.text(l.archive), findsNothing);
    expect(find.text(l.edit), findsNothing);
  });

  testWidgets('no account, no destination, or a workout running: no move, and no empty menu', (tester) async {
    access.account = false;
    await pump(tester, bench);
    final l = copy(tester);
    expect(find.byTooltip(l.exerciseOptions), findsNothing);

    access.account = true;
    await pump(tester, bench, movable: false);
    expect(find.byTooltip(l.exerciseOptions), findsNothing);

    await workouts.startWorkout(source: .blank, name: 'Now');
    await pump(tester, bench);
    expect(find.byTooltip(l.exerciseOptions), findsNothing);
  });

  testWidgets('pick a target, read what the move does, then move', (tester) async {
    final moved = await pump(tester, custom);
    final l = copy(tester);

    await tester.tap(find.byTooltip(l.exerciseOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.moveHistory));
    await tester.pumpAndSettle();

    // the picker; the source is there, and tapping it is not an answer
    await tester.tap(find.text(custom.name).last);
    await tester.pumpAndSettle();
    expect(moves.calls, isEmpty);

    await tester.tap(find.text(bench.name).last);
    await tester.pumpAndSettle();

    expect(find.text(l.moveHistoryTitle(bench.name)), findsOneWidget);
    expect(moves.calls, [(custom.id, bench.id, true)]);
    final lines = [
      '${l.moveHistoryLogged(12)} · ${l.moveHistoryTemplates(2)} · ${l.moveHistoryGoals(1)}',
      l.moveHistoryPreferenceDropped(bench.name, custom.name),
      l.moveHistorySourceDeleted(custom.name),
      l.moveHistoryFinal,
    ];
    expect(find.text(lines.join('\n')), findsOneWidget);

    await tester.tap(find.text(l.moveHistoryAction));
    await tester.pumpAndSettle();

    expect(moves.calls.last, (custom.id, bench.id, false));
    expect(moves.mirrored, [custom.id]);
    expect(moved, [bench]);
    expect(exercises.lookup(custom.id), isNull);
    expect(find.text(l.moveHistoryDone(bench.name)), findsOneWidget);
  });

  testWidgets('a refused preview says so and offers no Move', (tester) async {
    moves.refuse = true;
    final moved = await pump(tester, bench);
    final l = copy(tester);

    await tester.tap(find.byTooltip(l.exerciseOptions));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.moveHistory));
    await tester.pumpAndSettle();
    await tester.tap(find.text(incline.name).last);
    await tester.pumpAndSettle();

    expect(find.text(l.moveHistoryGone), findsOneWidget);
    expect(find.text(l.moveHistoryAction), findsNothing);

    await tester.tap(find.text(l.cancel));
    await tester.pumpAndSettle();
    expect(moved, isEmpty);
    expect(moves.mirrored, isEmpty);
  });
}

class _Moves implements ExerciseMoveService {
  final calls = <(String, String, bool)>[];
  final mirrored = <String>[];
  bool refuse = false;

  @override
  Future<ExerciseMoveReport> move(String sourceId, String targetId, {bool dryRun = false}) async {
    calls.add((sourceId, targetId, dryRun));
    if (refuse) throw const ExerciseMoveRefused(ExerciseMoveRefusal.unknownExercise);
    return ExerciseMoveReport(
      sourceId: sourceId,
      targetId: targetId,
      dryRun: dryRun,
      workoutExercises: 12,
      templateExercises: 2,
      preferences: 0,
      preferencesDropped: 1,
      chartPreferences: 0,
      goals: 1,
      sourceDeleted: true,
    );
  }

  @override
  Future<void> mirror(ExerciseMoveReport report, {required String userId}) async {
    mirrored.add(report.sourceId);
  }
}

// The template filing services: nothing in a move reaches them.
class _UnusedFolders extends Fake implements LocalTemplateFolderService;

class _UnusedRemoteFolders extends Fake implements ApiTemplateFolderService;

class _UnusedFiling extends Fake implements RemoteTemplateFilingService;
