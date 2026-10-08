import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/questions/answers.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/exercise_detail_test_helpers.dart';

/// The assistant's answers (#288): the device's mirror, read through the
/// app's own queries, said in the app's words and units.
void main() {
  late MockLocalDatabase db;
  late Preferences prefs;
  final bench = Exercise(name: 'Bench Press', category: .barbell, target: .chest);
  final run = Exercise(name: 'Running', category: .cardio, target: .cardio);
  const user = 'u1';
  final now = DateTime(2026, 10, 7, 12);

  setUpAll(() => initializeDateFormatting('ru'));

  setUp(() async {
    db = MockLocalDatabase();
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [bench, run]));
    SharedPreferences.setMockInitialValues({});
    prefs = Preferences();
    await prefs.init();
  });

  Answers answers({String locale = 'en'}) {
    return Answers(db: db, l: lookupL(Locale(locale)), prefs: prefs, now: () => now);
  }

  group('record', () {
    test('is the heaviest set with its reps, in the user\'s unit, dated', () async {
      when(db.getRecord(user, bench)).thenAnswer(
        (_) async => {
          'heaviest': {'weight': 100.0, 'reps': 5, 'workoutId': 'w1', 'at': '2026-10-03T09:00:00.000Z'},
          'oneRepMax': {
            'value': 116.0,
            'weight': 100.0,
            'reps': 5,
            'workoutId': 'w1',
            'at': '2026-10-03T09:00:00.000Z',
          },
        },
      );
      expect(await answers().record(user, bench.id), 'Your Bench Press record is 100 kg x 5, set on Oct 3, 2026');

      await prefs.setWeightUnit(MeasurementUnit.imperial);
      expect(await answers().record(user, bench.id), startsWith('Your Bench Press record is 220'));
      expect(await answers().record(user, bench.id), contains('lbs x 5'));
    });

    test('a cardio record is its distance', () async {
      when(db.getRecord(user, run)).thenAnswer(
        (_) async => {
          'longestDistance': {'distance': 10.0, 'workoutId': 'w2', 'at': '2026-09-30T07:00:00.000Z'},
        },
      );
      expect(await answers().record(user, run.id), 'Your Running record is 10 km, set on Sep 30, 2026');
    });

    test('says so with no sets, an unknown exercise, or no session', () async {
      when(db.getRecord(user, bench)).thenAnswer((_) async => null);
      expect(await answers().record(user, bench.id), 'No record for Bench Press yet');
      expect(await answers().record(user, 'nope'), 'I don\'t know that exercise');
      expect(await answers().record(null, bench.id), 'No workouts yet');
      // the unknown exercise and the missing session never reach the query
      verify(db.getRecord(user, bench)).called(1);
    });

    test('speaks the device\'s language', () async {
      when(db.getRecord(user, bench)).thenAnswer(
        (_) async => {
          'heaviest': {'weight': 100.0, 'reps': 5, 'workoutId': 'w1', 'at': '2026-10-03T09:00:00.000Z'},
        },
      );
      final answer = await answers(locale: 'ru').record(user, bench.id);
      expect(answer, startsWith('Ваш рекорд в Bench Press — 100 кг x 5'));
      expect(answer, contains('окт. 2026'));
    });
  });

  group('last time for an exercise', () {
    test('is the latest act, with the workout it was in', () async {
      when(db.getExerciseHistory(user, bench)).thenAnswer(
        (_) async => [
          TestExerciseAct(workoutId: 'w1', workoutName: 'Push day', start: DateTime.utc(2026, 10, 3, 9)),
          TestExerciseAct(workoutId: 'w0', workoutName: 'Push day', start: DateTime.utc(2026, 9, 26, 9)),
        ],
      );
      expect(await answers().lastExercise(user, bench.id), 'You last did Bench Press on Oct 3, 2026, in Push day');
    });

    test('a nameless workout gets the app\'s word for one', () async {
      when(db.getExerciseHistory(user, bench)).thenAnswer(
        (_) async => [TestExerciseAct(workoutId: 'w1', start: DateTime.utc(2026, 10, 3, 9))],
      );
      expect(await answers().lastExercise(user, bench.id), 'You last did Bench Press on Oct 3, 2026, in Workout');
    });

    test('never done, unknown, no session', () async {
      when(db.getExerciseHistory(user, bench)).thenAnswer((_) async => const <ExerciseAct>[]);
      expect(await answers().lastExercise(user, bench.id), 'You haven\'t done Bench Press yet');
      expect(await answers().lastExercise(user, 'nope'), 'I don\'t know that exercise');
      expect(await answers().lastExercise(null, bench.id), 'No workouts yet');
    });
  });

  group('last time for a template', () {
    Workout workout(String id, String? name, DateTime start, {bool finished = true}) {
      return Workout.fromJson({
        'id': id,
        'name': name,
        'start': start.toIso8601String(),
        if (finished) 'end': start.add(const Duration(hours: 1)).toIso8601String(),
        'exercises': const [],
      });
    }

    test('is the latest finished workout of that name', () async {
      when(db.getWorkoutHistory(user)).thenAnswer(
        (_) async => [
          workout('w0', 'Push day', DateTime.utc(2026, 9, 26, 9)),
          workout('w1', 'Push day', DateTime.utc(2026, 10, 3, 9)),
          workout('w2', 'Legs', DateTime.utc(2026, 10, 5, 9)),
          // running now: not a "last did"
          workout('w3', 'Push day', DateTime.utc(2026, 10, 7, 11), finished: false),
        ],
      );
      expect(await answers().lastTemplate(user, 'Push day'), 'You last did Push day on Oct 3, 2026');
      expect(await answers().lastTemplate(user, 'Pull day'), 'You haven\'t done Pull day yet');
    });

    test('no history, no session', () async {
      when(db.getWorkoutHistory(user)).thenAnswer((_) async => null);
      expect(await answers().lastTemplate(user, 'Push day'), 'You haven\'t done Push day yet');
      expect(await answers().lastTemplate(null, 'Push day'), 'No workouts yet');
    });
  });

  group('this week', () {
    test('counts through the stats query, as the dashboard does', () async {
      when(db.getWeeklyWorkoutCount(now, userId: user)).thenAnswer((_) async => 3);
      expect(await answers().weekly(user), '3 workouts this week');

      when(db.getWeeklyWorkoutCount(now, userId: user)).thenAnswer((_) async => 1);
      expect(await answers().weekly(user), 'One workout this week');

      when(db.getWeeklyWorkoutCount(now, userId: user)).thenAnswer((_) async => 0);
      expect(await answers().weekly(user), 'No workouts this week yet');
      expect(await answers().weekly(null), 'No workouts yet');
    });
  });
}
