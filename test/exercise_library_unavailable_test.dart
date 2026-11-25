// A library that couldn't be downloaded (#723): the picker lists the user's
// own exercises under a line that says so, instead of a spinner for good, and
// trying again brings the library in.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

void main() {
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final curl = Exercise(name: 'My Curl', category: .dumbbell, target: .arms, isMine: true);
  const stamp = (version: 'run-1', locale: 'en', etag: null);

  late Exercises exercises;
  late MockExerciseLibraryService library;
  late Preferences preferences;
  late PreviousExercises previous;
  late TextEditingController search;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'feature-programs': 'off'});
    preferences = Preferences();
    await preferences.init();

    final service = MockExerciseService();
    when(service.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [curl]));
    when(service.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    library = MockExerciseLibraryService();
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) => Completer<Never>().future);
    final catalog = MockLocalCatalogService();
    when(catalog.getCatalogStamp()).thenAnswer((_) async => null);
    when(catalog.getSearchGlossary()).thenAnswer((_) async => null);
    when(catalog.storeCatalog(any, stamp: anyNamed('stamp'), glossary: anyNamed('glossary'))).thenAnswer((_) async {});
    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: service,
      libraryService: library,
      catalogService: catalog,
      preferenceService: MockRemoteExercisePreferenceService(),
      remote: RemoteAccess(),
      libraryWait: const Duration(milliseconds: 20),
    );
    await exercises.init();

    final sets = MockPreviousExerciseService();
    when(sets.getPreviousSets(any)).thenAnswer((_) async => {});
    previous = PreviousExercises(service: sets, readSessions: (_) async => {});
    search = TextEditingController();
  });

  tearDown(() => search.dispose());

  Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
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
          locale: locale,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          // watched, as the library page does
          home: Scaffold(
            body: Builder(
              builder: (context) => ExercisePicker(
                exercises: Exercises.watch(context),
                searchController: search,
                focusNode: focus,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  L l(WidgetTester tester) => L.of(tester.element(find.byType(ExercisePicker)));

  testWidgets('the own exercises are listed under a line that says the library is missing', (tester) async {
    await pump(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(AppKeys.libraryUnavailable), findsOneWidget);
    expect(find.text(l(tester).exerciseLibraryUnavailable), findsOneWidget);
    expect(find.text(curl.name), findsWidgets);
  });

  testWidgets('one created meanwhile shows at once', (tester) async {
    await pump(tester);
    final row = Exercise(name: 'My Row', category: .dumbbell, target: .back, isMine: true);

    await tester.runAsync(() => exercises.makeExercise(row));
    await tester.pump();

    expect(find.text(row.name), findsWidgets);
  });

  testWidgets('Retry brings the library, and the line goes', (tester) async {
    await pump(tester);
    final download = Completer<(CatalogLibrary?, CatalogStamp)>();
    when(library.getLibrary(cached: anyNamed('cached'))).thenAnswer((_) => download.future);

    await tester.tap(find.text(l(tester).retry));
    await tester.pump();
    // trying: a spinner where the button was
    expect(find.text(l(tester).retry), findsNothing);
    expect(
      find.descendant(of: find.byKey(AppKeys.libraryUnavailable), matching: find.byType(CircularProgressIndicator)),
      findsOneWidget,
    );

    download.complete(((exercises: <Exercise>[bench], glossary: SearchGlossary.empty()), stamp));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(AppKeys.libraryUnavailable), findsNothing);
    expect(find.text(bench.name), findsWidgets);
    expect(find.text(curl.name), findsWidgets);
  });

  testWidgets('while the library is still coming, a spinner as before', (tester) async {
    exercises.onSignOut();
    await pump(tester);

    expect(find.byKey(AppKeys.libraryUnavailable), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
