import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';

/// A session a coach logged for someone says so on its History card (#560),
/// while Your coach is on; one of their own says nothing.
void main() {
  Future<void> pump(WidgetTester tester, Workout workout, {bool yourCoach = true}) async {
    SharedPreferences.setMockInitialValues({'feature-yourCoach': yourCoach ? 'on' : 'off'});
    final preferences = Preferences();
    await preferences.init();
    final exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: WorkoutItem(workout: workout, showsMenuButton: false)),
        ),
      ),
    );
  }

  Workout session({String? loggedByName}) {
    return Workout.fromJson({
      'id': 'w1',
      'name': 'Day B',
      'start': '2026-11-07T20:00:00Z',
      'end': '2026-11-07T21:00:00Z',
      'loggedBy': ?switch (loggedByName) {
        String _ => 'whiskers',
        null => null,
      },
      'loggedByName': ?loggedByName,
      'exercises': <Object>[],
    });
  }

  testWidgets("a coach's session names who logged it", (tester) async {
    await pump(tester, session(loggedByName: 'Whiskers'));

    expect(find.byKey(AppKeys.loggedBy('w1')), findsOneWidget);
    expect(find.text('Logged by Whiskers'), findsOneWidget);
  });

  testWidgets('one of their own says nothing of it', (tester) async {
    await pump(tester, session());

    expect(find.byKey(AppKeys.loggedBy('w1')), findsNothing);
  });

  testWidgets('with Your coach off, it is a workout like any other', (tester) async {
    await pump(tester, session(loggedByName: 'Whiskers'), yourCoach: false);

    expect(find.byKey(AppKeys.loggedBy('w1')), findsNothing);
  });
}
