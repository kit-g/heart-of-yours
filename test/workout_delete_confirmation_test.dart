import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// Deleting a workout from the history card's menu must ask first — a misclick
/// on the popup item used to delete the workout outright, with no way back.
void main() {
  late MockWorkoutService local;
  late MockRemoteWorkoutService remote;
  late Workouts workouts;
  late Preferences preferences;
  late Exercises exercises;

  setUp(() async {
    local = MockWorkoutService();
    remote = MockRemoteWorkoutService();
    when(local.deleteWorkout(any)).thenAnswer((_) async {});
    when(remote.deleteWorkout(any)).thenAnswer((_) async => true);
    workouts = Workouts(service: local, remoteService: remote);

    SharedPreferences.setMockInitialValues({});
    preferences = Preferences();
    await preferences.init();

    exercises = Exercises(
      remoteService: MockRemoteExerciseService(),
      service: MockExerciseService(),
    );
  });

  Future<void> pumpItem(WidgetTester tester, Workout workout, {void Function(Workout)? onDeleteWorkout}) {
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Workouts>.value(value: workouts),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
          ChangeNotifierProvider<Exercises>.value(value: exercises),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: WorkoutItem(
              workout: workout,
              onDeleteWorkout: onDeleteWorkout,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('delete asks for confirmation; cancel keeps the workout', (tester) async {
    final workout = Workout(name: 'Leg day');
    var deleted = false;
    await pumpItem(tester, workout, onDeleteWorkout: (_) => deleted = true);

    await openDeleteDialog(tester);

    expect(find.text('Do you want to delete this workout?'), findsOneWidget);
    verifyNever(remote.deleteWorkout(any));
    verifyNever(local.deleteWorkout(any));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Do you want to delete this workout?'), findsNothing);
    verifyNever(remote.deleteWorkout(any));
    verifyNever(local.deleteWorkout(any));
    expect(deleted, isFalse);
  });

  testWidgets('confirming deletes the workout', (tester) async {
    final workout = Workout(name: 'Leg day');
    var deleted = false;
    await pumpItem(tester, workout, onDeleteWorkout: (_) => deleted = true);

    await openDeleteDialog(tester);
    await tester.tap(find.text('Yes, delete this'));
    await tester.pumpAndSettle();

    verify(remote.deleteWorkout(workout.id)).called(1);
    verify(local.deleteWorkout(workout.id)).called(1);
    expect(deleted, isTrue);
    expect(find.text('Deleted'), findsOneWidget); // snackbar
  });
}
