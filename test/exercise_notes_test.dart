import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() => exerciseNoteTests();

void exerciseNoteTests({Future<void> Function(String name)? onFrame, bool useDeviceSize = false}) {
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });
  final sizes = switch (useDeviceSize) {
    true => [const Size(390, 844)],
    false => [const Size(390, 844), const Size(1194, 834), const Size(834, 1194)],
  };
  for (final size in sizes) {
    testWidgets('anonymous exercise notes at $size', (tester) async {
      if (!useDeviceSize) {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }
      final db = MockLocalDatabase();
      final api = MockApi();
      final cdn = MockCdn();
      stubStartup(db, api);
      final ex = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
      final workout = Workout(name: 'Push day');
      workout.add(ex).note = 'Pause at the bottom';
      when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [ex]));
      when(db.getActiveWorkout(any)).thenAnswer((_) async => workout);
      when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        firebaseAuth: MockFirebaseAuth(mockUser: _AnonymousNoteUser(), signedIn: true),
        settle: false,
      );
      final state = Workouts.of(tester.element(find.byType(MaterialApp)));
      await state.startWorkout(template: workout);
      await tester.tapByKey(AppKeys.workoutStack);
      await tester.pumpTimes();
      if (find.byType(WorkoutDetail).evaluate().isEmpty) {
        await tester.tapByKey(WorkoutDetailKeys.startNewWorkout);
      }
      await tester.pumpTimes();
      if (!useDeviceSize) tester.view.physicalSize = size;
      await tester.pumpTimes();
      expect(find.text('Pause at the bottom'), findsOneWidget);
      await onFrame?.call('note-${size.width.toInt()}');
      await tester.tap(find.byTooltip('Pin for future workouts'));
      await tester.pumpTimes();
      verify(db.setExerciseNote(ex.id, 'anon', 'Pause at the bottom', pending: true)).called(1);
      verifyNever(api.setExerciseNote(any, any));
      expect(find.byTooltip('Unpin for future workouts'), findsOneWidget);
      await onFrame?.call('pinned-${size.width.toInt()}');
      await tester.drag(find.text('Pause at the bottom'), const Offset(-600, 0));
      await tester.pumpTimes();
      expect(workout.first.note, isNull);
      verify(db.setWorkoutExerciseNote(workout.first.id, null)).called(1);
      final exercises = Exercises.of(tester.element(find.byType(WorkoutDetail)));
      expect(exercises.noteFor(ex.id), 'Pause at the bottom');
      await tester.tap(find.byKey(WorkoutDetailKeys.exerciseOptionsFor(ex.id)));
      await tester.pumpTimes();
      await tester.tap(find.text('Add note'));
      await tester.pumpTimes();
      await onFrame?.call('editor-${size.width.toInt()}');
      await tester.enterText(find.byType(TextFormField), 'x' * 151);
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, 'x' * 150);
      await tester.enterText(find.byType(TextFormField), 'One hand at a time');
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();
      expect(workout.first.note, 'One hand at a time');
      expect(exercises.noteFor(ex.id), 'Pause at the bottom');
      expect(find.byTooltip('Unpin for future workouts'), findsOneWidget);
      await tester.tap(find.byTooltip('Unpin for future workouts'));
      await tester.pumpTimes();
      expect(exercises.noteFor(ex.id), isNull);
      expect(workout.first.note, 'One hand at a time');

      await tester.tap(find.byTooltip('Pin for future workouts'));
      await tester.pumpTimes();
      await tester.tap(find.byTooltip('Remove note'));
      await tester.pumpTimes();
      expect(workout.first.note, isNull);
      expect(exercises.noteFor(ex.id), 'One hand at a time');
      await tester.tap(find.byKey(WorkoutDetailKeys.exerciseOptionsFor(ex.id)));
      await tester.pumpTimes();
      await tester.tap(find.text('Unpin for future workouts'));
      await tester.pumpTimes();
      expect(exercises.noteFor(ex.id), isNull);

      final longNote = 'x' * 180;
      await state.setNote(workout.first, longNote);
      await tester.pumpTimes();
      await tester.tap(find.byTooltip('Pin for future workouts'));
      await tester.pumpTimes();
      // Existing server notes can exceed the UI limit: validation still matters.
      expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, longNote);
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(exercises.noteFor(ex.id), isNull);
      await tester.enterText(find.byType(TextFormField), 'Short pin');
      await tester.tap(find.text('Save'));
      await tester.pumpTimes();
      expect(exercises.noteFor(ex.id), 'Short pin');
      expect(workout.first.note, longNote);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

// MockUser otherwise supplies a remote avatar, unrelated to this offline flow.
// The upstream mock is mutable despite Firebase User's immutable annotation.
// ignore: must_be_immutable
class _AnonymousNoteUser extends MockUser {
  new() : super(uid: 'anon', isAnonymous: true);

  @override
  String? get photoURL => null;
}
