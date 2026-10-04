import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';

/// A workout card's TOTAL VOLUME is weight moved: load × reps. A loaded hold's
/// own total is kg × seconds and a carry's kg × km (heart_models 2.7.0), and
/// neither is a weight (#253).
void main() {
  testWidgets('a carry and a loaded hold add nothing to total volume', (tester) async {
    SharedPreferences.setMockInitialValues({'weightUnit': 'metric', 'distanceUnit': 'metric'});
    final preferences = Preferences();
    await preferences.init();
    final exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
      libraryService: MockExerciseLibraryService(),
      catalogService: MockLocalCatalogService(),
      preferenceService: MockRemoteExercisePreferenceService(),
    );

    ExerciseSet done(WorkoutExercise exercise, {double? weight, int? reps, int? duration, double? distance}) {
      return exercise.first
        ..setMeasurements(weight: weight, reps: reps, duration: duration, distance: distance)
        ..isCompleted = true;
    }

    final workout = Workout(name: 'Strongman')
      ..add(Exercise(name: 'Bench Press', category: .barbell, target: .chest))
      ..add(Exercise(name: 'Plank (Weighted)', category: .weightedDuration, target: .core))
      ..add(Exercise(name: "Farmer's Walk", category: .weightedDistance, target: .fullBody));
    done(workout.elementAt(0), weight: 100, reps: 5);
    done(workout.elementAt(1), weight: 24, duration: 45);
    done(workout.elementAt(2), weight: 40, distance: 0.03);
    workout.finish(DateTime.now());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: WorkoutItem(workout: workout, showsMenuButton: false),
          ),
        ),
      ),
    );

    // the bench alone; Workout.total would have read 1581
    expect(find.text('500 kg'), findsOneWidget);
    expect(find.text('24 kg / 45 sec'), findsOneWidget);
    expect(find.text('40 kg / 30 m'), findsOneWidget);
  });
}
