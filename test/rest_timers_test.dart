import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/finders.dart';

class _Timers implements TimersService {
  @override
  Future<void> setRestTimer({required String exerciseName, required String userId, required int? seconds}) async {}

  @override
  Future<Map<String, int>> getTimers(String userId) async => {};
}

/// The rest-timers page: every timer, readable by name, clearable in one tap
/// and back with one more.
void main() {
  final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);
  final bench = Exercise(name: 'Bench press', category: .barbell, target: .chest);

  late Exercises exercises;
  late Timers timers;
  late Preferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    final local = MockExerciseService();
    when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat, bench]));
    when(local.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});

    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: local,
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    await exercises.init();

    timers = Timers(service: _Timers())..userId = 'u1';
    await timers.setRestTimer(squat.id, 120);
    await timers.setRestTimer(bench.id, 90);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Timers>.value(value: timers),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: RestTimersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> titles(WidgetTester tester) {
    return tester.widgetList<ListTile>(find.byType(ListTile)).map((tile) => (tile.title as Text).data!).toList();
  }

  testWidgets('lists by name, each with its duration', (tester) async {
    await pump(tester);

    expect(titles(tester), ['Bench press', 'Squat']);
    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
  });

  testWidgets('leaves out a timer the catalog does not resolve', (tester) async {
    // not reachable through the app — the foreign key cascades a deleted
    // exercise's timer away — only through a hand-edited database
    await timers.setRestTimer('gone', 45);
    await pump(tester);

    expect(titles(tester), ['Bench press', 'Squat']);
    expect(find.text('00:45'), findsNothing);
  });

  testWidgets('clears on the spot, and Undo puts it back', (tester) async {
    await pump(tester);

    await tester.tap(find.tooltip('Clear rest timer for Squat'));
    await tester.pumpAndSettle();

    expect(timers[squat.id], isNull);
    expect(find.text('Squat'), findsNothing);
    expect(find.text('Rest timer cleared'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(timers[squat.id], 120);
    expect(find.text('Squat'), findsOneWidget);
  });

  testWidgets('the Undo outlasts the default snackbar', (tester) async {
    await pump(tester);

    await tester.tap(find.tooltip('Clear rest timer for Squat'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));

    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('says where timers come from once the last one is cleared', (tester) async {
    await pump(tester);

    for (final tooltip in ['Bench press', 'Squat']) {
      await tester.tap(find.tooltip('Clear rest timer for $tooltip'));
      await tester.pumpAndSettle();
    }

    expect(find.byType(ListTile), findsNothing);
    expect(find.textContaining('No rest timers.'), findsOneWidget);
  });

  group('default rest (#174)', () {
    testWidgets('off, no heading and no defaults: the page as it was', (tester) async {
      await pump(tester);

      expect(find.text('Default rest'), findsNothing);
      expect(find.text('Exercises'), findsNothing);
      expect(find.text('Compound lifts'), findsNothing);
    });

    testWidgets("on, each kind's length heads the page, the timers under it", (tester) async {
      preferences.setFeature(.defaultRest, on: true);
      await pump(tester);

      expect(titles(tester), ['Compound lifts', 'Isolation lifts', 'Bodyweight and cardio', 'Bench press', 'Squat']);
      expect(find.text('Default rest'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('02:30'), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);
    });

    testWidgets('a kind set to no rest says so', (tester) async {
      preferences
        ..setFeature(.defaultRest, on: true)
        ..setDefaultRest(.conditioning, 0);
      await pump(tester);

      expect(find.text('No rest'), findsOneWidget);
    });

    testWidgets('with every timer cleared, says what the defaults are for', (tester) async {
      preferences.setFeature(.defaultRest, on: true);
      await timers.remove(squat.id);
      await timers.remove(bench.id);
      await pump(tester);

      expect(find.text('Compound lifts'), findsOneWidget);
      expect(find.textContaining('No rest timers.'), findsNothing);
      expect(find.textContaining('Exercises without a timer of their own'), findsOneWidget);
    });

    testWidgets("the picker's Cancel makes a kind rest not at all", (tester) async {
      preferences.setFeature(.defaultRest, on: true);
      await pump(tester);

      await tester.tap(find.text('Isolation lifts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel timer'));
      await tester.pumpAndSettle();

      expect(preferences.defaultRest(.isolation), 0);
      expect(find.text('No rest'), findsOneWidget);
    });
  });
}
