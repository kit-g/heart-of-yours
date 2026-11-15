import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'test_utils.dart';

/// History's muscle-group filter (#610): what a workout trained, and which
/// workouts a filter lets through.
void main() {
  Exercise exercise(
    String id, {
    String target = 'Chest',
    List<String> primary = const [],
    List<String> secondary = const [],
  }) {
    return Exercise.fromJson({
      'id': id,
      'name': id,
      'category': 'Barbell',
      'target': target,
      'asset': null,
      'thumbnail': null,
      'instructions': null,
      'archived': false,
      if (primary.isNotEmpty)
        'muscles': {
          'primary': {'ids': <String>[], 'groups': primary},
          'secondary': {'ids': <String>[], 'groups': secondary},
        },
    });
  }

  Workout workout(List<Exercise> exercises, {bool done = true}) {
    final workout = Workout.fromExercises(exercises.map((each) => wEx(each)));
    if (done) workout.completeAllSets();
    return workout;
  }

  Exercise? none(ExerciseId _) => null;

  final bench = exercise('bench', primary: ['chest'], secondary: ['arms', 'shoulders']);
  final squat = exercise('squat', target: 'Legs', primary: ['legs', 'glutes']);

  group('workoutGroupsOf', () {
    test('primary groups only: a bench session is no arm day', () {
      expect(workoutGroupsOf(workout([bench]), lookup: none), {MuscleGroupKey.chest});
    });

    test('every exercise with a set done adds its groups', () {
      expect(
        workoutGroupsOf(workout([bench, squat]), lookup: none),
        {MuscleGroupKey.chest, MuscleGroupKey.legs, MuscleGroupKey.glutes},
      );
    });

    test('an exercise with nothing done adds nothing', () {
      expect(workoutGroupsOf(workout([bench], done: false), lookup: none), isEmpty);
    });

    test('an untagged exercise of the user\'s falls back to its target', () {
      final own = exercise('own', target: 'Back');
      expect(workoutGroupsOf(workout([own]), lookup: none), {MuscleGroupKey.back});
    });

    test('a target no group answers to places nothing', () {
      final run = exercise('run', target: 'Cardio');
      expect(workoutGroupsOf(workout([run]), lookup: none), isEmpty);
    });

    test('the library\'s tagging wins over the copy the workout carries', () {
      final copy = exercise('row', target: 'Back');
      final library = exercise('row', target: 'Back', primary: ['back', 'arms']);
      expect(
        workoutGroupsOf(workout([copy]), lookup: (id) => id == 'row' ? library : null),
        {MuscleGroupKey.back, MuscleGroupKey.arms},
      );
    });

    test('read before the library loads, a workout is read again once it has', () {
      final copy = exercise('row', target: 'Chest');
      final library = exercise('row', target: 'Back', primary: ['back']);
      final session = workout([copy]);

      expect(workoutGroupsOf(session, lookup: none), {MuscleGroupKey.chest});
      expect(workoutGroupsOf(session, lookup: (_) => library), {MuscleGroupKey.back});
    });
  });

  group('HistoryFilter', () {
    test('shows everything with no group set', () {
      final filter = HistoryFilter();
      expect(filter.isOn, isFalse);
      expect(filter.shows(workout([bench]), lookup: none), isTrue);
    });

    test('lets through a workout that trained any of its groups', () {
      final filter = HistoryFilter()
        ..toggle(.legs)
        ..toggle(.back);
      expect(filter.shows(workout([squat]), lookup: none), isTrue);
      expect(filter.shows(workout([bench]), lookup: none), isFalse);
      expect(filter.shows(workout([bench, squat]), lookup: none), isTrue);
    });

    test('toggling a group in the filter takes it out', () {
      final filter = HistoryFilter()..toggle(.legs);
      var heard = 0;
      filter.addListener(() => heard++);
      filter.toggle(.legs);
      expect(filter.groups, isEmpty);
      expect(heard, 1);
    });

    test('remove and clear say something only when something changed', () {
      final filter = HistoryFilter()..toggle(.legs);
      var heard = 0;
      filter.addListener(() => heard++);

      filter.remove(.chest);
      expect(heard, 0);
      filter.remove(.legs);
      expect(heard, 1);
      filter.clear();
      expect(heard, 1);
    });

    test('a sign-out clears it', () {
      final filter = HistoryFilter()..toggle(.chest);
      filter.onSignOut();
      expect(filter.isOn, isFalse);
    });
  });
}
