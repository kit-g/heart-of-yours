import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The picker shows what was done last before any typing, and ranks what a
/// query finds by match first and recency second (#135).
void main() {
  Exercise lift(String name, String key) {
    return Exercise.fromJson({'id': 'id-$key', 'key': key, 'name': name, 'category': 'Barbell', 'target': 'Chest'});
  }

  final barbell = lift('Bench Press (Barbell)', 'bench-press-barbell');
  final dumbbell = lift('Bench Press (Dumbbell)', 'bench-press-dumbbell');
  final incline = lift('Incline Bench Press (Barbell)', 'incline-bench-press-barbell');
  final squat = lift('Squat (Barbell)', 'squat-barbell');

  late Exercises exercises;
  late PreviousExercises previous;
  late Preferences preferences;
  late TextEditingController search;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    final service = MockExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    final library = MockExerciseLibraryService();
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer(
      (_) async => (
        (exercises: [barbell, dumbbell, incline, squat], glossary: SearchGlossary.empty()),
        (version: 'run-1', locale: 'en', etag: null),
      ),
    );
    final catalog = MockLocalCatalogService();
    when(catalog.getCatalogStamp()).thenAnswer((_) async => null);
    when(
      catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary')),
    ).thenAnswer((_) async {});
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: service,
      libraryService: library,
      catalogService: catalog,
      preferenceService: MockRemoteExercisePreferenceService(),
      remote: RemoteAccess(),
    );
    await exercises.init();

    final sets = MockPreviousExerciseService();
    when(sets.getPreviousSets(any)).thenAnswer(
      (_) async => {
        incline.id: [
          {'weight': 60.0, 'reps': 8, 'workout_start': '2026-10-03T08:00:00.000Z'},
        ],
        squat.id: [
          {'weight': 100.0, 'reps': 5, 'workout_start': '2026-09-30T08:00:00.000Z'},
        ],
      },
    );
    previous = PreviousExercises(service: sets)..userId = 'u1';
    await previous.init();

    search = TextEditingController();
  });

  tearDown(() => search.dispose());

  Future<void> pump(WidgetTester tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<PreviousExercises>.value(value: previous),
          Provider<Scrolls>.value(value: Scrolls()),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: ExercisePicker(exercises: exercises, searchController: search, focusNode: focus),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The exercise names on screen, top to bottom.
  List<String> names(WidgetTester tester) {
    final names = {barbell.name, dumbbell.name, incline.name, squat.name};
    return [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        if (text.data case final String name when names.contains(name)) name,
    ];
  }

  testWidgets('before any typing, the last done sit above the whole library, newest first', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester);

    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('ALL EXERCISES'), findsOneWidget);
    expect(names(tester), [
      // recent
      incline.name,
      squat.name,
      // all, in the library's order
      barbell.name,
      dumbbell.name,
      incline.name,
      squat.name,
    ]);
  });

  testWidgets('a query ranks by match, then by what was done last, in one list', (tester) async {
    await pump(tester);

    search.text = 'bench';
    await tester.pump();

    expect(find.text('RECENT'), findsNothing);
    // both Bench Press names start with the query; the incline, done
    // yesterday, still comes after them
    expect(names(tester), [barbell.name, dumbbell.name, incline.name]);

    search.text = 'press';
    await tester.pump();

    // every one matches by word alone, so recency decides
    expect(names(tester).first, incline.name);
  });

  testWidgets('a lifter with no history sees the library as before', (tester) async {
    final sets = MockPreviousExerciseService();
    when(sets.getPreviousSets(any)).thenAnswer((_) async => {});
    previous = PreviousExercises(service: sets)..userId = 'u1';
    await previous.init();

    await pump(tester);

    expect(find.text('RECENT'), findsNothing);
    expect(find.text('ALL EXERCISES'), findsNothing);
    expect(names(tester), [barbell.name, dumbbell.name, incline.name, squat.name]);
  });
}
