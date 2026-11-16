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

  final none = WorkoutGroups((_) => null);

  final bench = exercise('bench', primary: ['chest'], secondary: ['arms', 'shoulders']);
  final squat = exercise('squat', target: 'Legs', primary: ['legs', 'glutes']);

  group('WorkoutGroups', () {
    test('primary groups only: a bench session is no arm day', () {
      expect(none.of(workout([bench])), {MuscleGroupKey.chest});
    });

    test('every exercise with a set done adds its groups', () {
      expect(
        none.of(workout([bench, squat])),
        {MuscleGroupKey.chest, MuscleGroupKey.legs, MuscleGroupKey.glutes},
      );
    });

    test('an exercise with nothing done adds nothing', () {
      expect(none.of(workout([bench], done: false)), isEmpty);
    });

    test('an untagged exercise of the user\'s falls back to its target', () {
      final own = exercise('own', target: 'Back');
      expect(none.of(workout([own])), {MuscleGroupKey.back});
    });

    test('a target no group answers to places nothing', () {
      final run = exercise('run', target: 'Cardio');
      expect(none.of(workout([run])), isEmpty);
    });

    test('the library\'s tagging wins over the copy the workout carries', () {
      final copy = exercise('row', target: 'Back');
      final library = exercise('row', target: 'Back', primary: ['back', 'arms']);
      expect(
        WorkoutGroups((id) => id == 'row' ? library : null).of(workout([copy])),
        {MuscleGroupKey.back, MuscleGroupKey.arms},
      );
    });

    test('the library\'s target places an exercise nobody tagged, over the copy\'s', () {
      final copy = exercise('own', target: 'Chest');
      final edited = exercise('own', target: 'Back');
      expect(WorkoutGroups((_) => edited).of(workout([copy])), {MuscleGroupKey.back});
    });

    test('warm-ups count for nothing, as on the muscle map', () {
      final session = workout([squat], done: false);
      session.first.first
        ..setType = .warmup
        ..isCompleted = true;
      expect(none.of(session), isEmpty);
    });
  });

  group('HistoryFilter', () {
    test('shows everything with no group set', () {
      final filter = HistoryFilter();
      expect(filter.isOn, isFalse);
      expect(filter.shows(workout([bench]), none), isTrue);
    });

    test('lets through a workout that trained any of its groups', () {
      final filter = HistoryFilter()
        ..toggle(.legs)
        ..toggle(.back);
      expect(filter.shows(workout([squat]), none), isTrue);
      expect(filter.shows(workout([bench]), none), isFalse);
      expect(filter.shows(workout([bench, squat]), none), isTrue);
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

  group('MuscleFamily (#617)', () {
    test('every group has a family, the lower body\'s four in one', () {
      expect(MuscleFamily.of(.legs), MuscleFamily.lowerBody);
      expect(MuscleFamily.of(.glutes), MuscleFamily.lowerBody);
      expect(MuscleFamily.of(.hamstrings), MuscleFamily.lowerBody);
      expect(MuscleFamily.of(.adductors), MuscleFamily.lowerBody);
      expect(MuscleFamily.of(.neck), MuscleFamily.shoulders);
      expect(MuscleFamily.of(.chest), MuscleFamily.chest);
    });

    test('sets by family count working sets, once per family an exercise reaches', () {
      final session = Workout.fromExercises([wEx(bench, sets: 3), wEx(squat, sets: 2)])..completeAllSets();
      // squat reaches legs and glutes, both the lower body: its two sets count once
      expect(none.setsByFamily([session]), {MuscleFamily.chest: 3, MuscleFamily.lowerBody: 2});
    });
  });
}
