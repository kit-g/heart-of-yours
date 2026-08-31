import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// The About tab's chip row: equipment, movement pattern, body part.
///
/// [ExerciseDetailPage] is pumped directly rather than through the app harness
/// — the row only needs [Exercises] and the localizations, and the full app
/// would drag in Firebase, the router and the local database for a widget that
/// reads one field.
void main() {
  late MockExerciseService local;
  late MockRemoteExerciseService remote;
  late Exercises exercises;
  late Preferences preferences;

  /// [instructions] is not decoration: `Exercise.hasInfo` gates whether the
  /// About tab exists at all, and it looks only at asset, thumbnail and
  /// instructions — never at movement.
  Exercise ex(String name, {Map<String, dynamic>? movement, bool? validated}) {
    return Exercise.fromJson({
      'id': 'id-${name.toLowerCase().replaceAll(' ', '-')}',
      'name': name,
      'category': 'Machine',
      'target': 'Back',
      'archived': false,
      'instructions': 'Pull the bar down.',
      'movement': ?movement,
      'validated': ?validated,
    });
  }

  Map<String, dynamic> movement(List<String> groups) {
    return {
      'groups': groups,
      'axialLoad': 'none',
      'stability': 'machine',
      'unilateral': false,
      'impact': 'none',
      'skill': 'low',
    };
  }

  setUp(() async {
    local = MockExerciseService();
    remote = MockRemoteExerciseService();

    when(local.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(local.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(local.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
    when(remote.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(remote.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);

    exercises = Exercises(remoteService: remote, service: local);

    // the detail page builds every tab, not just About, and the History one
    // reads unit preferences
    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();
  });

  Future<void> pumpAbout(
    WidgetTester tester,
    Exercise exercise, {
    void Function(ExerciseFilter)? onFilter,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Exercises>.value(value: exercises),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          // the detail page forks on platform; pin Material so the test is not
          // at the mercy of the host it runs on
          theme: ThemeData(platform: TargetPlatform.android),
          home: ExerciseDetailPage(
            exercise: exercise,
            onTapWorkout: (_) async {},
            onFilter: onFilter,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('About chip row', () {
    testWidgets('shows the movement pattern between equipment and body part', (tester) async {
      await pumpAbout(tester, ex('Lat Pulldown (Machine)', movement: movement(['vertical_pull'])));

      expect(find.text('Vertical Pull'), findsOneWidget);

      // order carries the meaning: a pattern is coarser than the category and
      // finer than the target, and it should read that way left to right
      final chips = tester.widgetList<Text>(find.byType(Text)).map((each) => each.data).toList();
      final category = chips.indexOf('Machine');
      final pattern = chips.indexOf('Vertical Pull');
      final target = chips.indexWhere((each) => each?.contains('Back') ?? false);

      expect(category, lessThan(pattern));
      expect(pattern, lessThan(target));
    });

    testWidgets('renders every pattern of a multi-pattern exercise', (tester) async {
      // not named "Lunge": the app bar would match the chip finder
      await pumpAbout(tester, ex('Walking Lunge', movement: movement(['squat_unilateral', 'lunge'])));

      expect(find.text('Squat Unilateral'), findsOneWidget);
      expect(find.text('Lunge'), findsOneWidget);
    });

    testWidgets('shows no pattern chip for an unannotated exercise', (tester) async {
      await pumpAbout(tester, ex('My Curl'));

      // category and target still render; nothing else joins them
      expect(find.text('Machine'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('a pattern chip filters the library by that pattern', (tester) async {
      final tapped = <ExerciseFilter>[];
      await pumpAbout(
        tester,
        ex('Lat Pulldown (Machine)', movement: movement(['vertical_pull'])),
        onFilter: tapped.add,
      );

      await tester.tap(find.text('Vertical Pull'));
      await tester.pump();

      expect(tapped, [const PatternFilter('vertical_pull')]);
    });

    testWidgets('chips are inert without an onFilter, as in the workout dialog', (tester) async {
      await pumpAbout(tester, ex('Lat Pulldown (Machine)', movement: movement(['vertical_pull'])));

      // plain labels, not buttons: navigating to the library is wrong from a
      // dialog sitting on top of a live workout
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(Chip), findsNWidgets(3));
    });
  });

  group('machine-copy mark', () {
    testWidgets('machine-authored copy is disclosed above the instructions', (tester) async {
      await pumpAbout(tester, ex('Lat Pulldown (Machine)', validated: false));

      expect(find.text('Machine-translated'), findsOneWidget);
    });

    testWidgets('reviewed copy renders unmarked', (tester) async {
      await pumpAbout(tester, ex('Lat Pulldown (Machine)', validated: true));

      expect(find.text('Machine-translated'), findsNothing);
    });

    testWidgets('user-created copy takes no stance and renders unmarked', (tester) async {
      await pumpAbout(tester, ex('My Curl'));

      expect(find.text('Machine-translated'), findsNothing);
    });
  });
}
