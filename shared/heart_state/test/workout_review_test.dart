import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

Map<String, dynamic> _exercise(String id) {
  return {'id': id, 'name': id, 'category': 'Barbell', 'target': 'Legs', 'own': 0, 'archived': 0};
}

Map<String, dynamic> _set(String id, {num? weight, int? reps, bool done = true}) {
  return {
    'id': id,
    'completed': done,
    'started_at': '2026-11-07T19:10:00Z',
    'weight': ?weight,
    'reps': ?reps,
    'set_type': 'normal',
  };
}

Workout _workout(List<(String exercise, List<Map<String, dynamic>> sets)> exercises) {
  return Workout.fromJson({
    'id': 'w1',
    'name': 'Day A',
    'start': '2026-11-07T19:05:00Z',
    'end': '2026-11-07T20:05:00Z',
    'note': 'Last set was a grind',
    'exercises': [
      for (final (index, (exercise, sets)) in exercises.indexed)
        {
          'id': 'we-$exercise',
          'exercise': _exercise(exercise),
          'start': '2026-11-07T19:05:00Z',
          'order': index,
          'sets': sets,
        },
    ],
  });
}

void main() {
  test('without a plan, it lists what was done and compares nothing', () {
    final review = WorkoutReview.of(
      _workout([
        ('squat', [_set('s1', weight: 100, reps: 5), _set('s2', weight: 100, reps: 5, done: false)]),
      ]),
      null,
    );

    expect(review.hasPlan, isFalse);
    final [squat] = review.exercises;
    expect(squat.sets.map((set) => (set.done?.id, set.outcome)), [('s1', null)], reason: 'only completed sets');
    expect(review.offPlan, isTrue);
  });

  test('target beside done: as asked, lighter, fewer, skipped and added, in words the app can say', () {
    final workout = _workout([
      ('squat', [_set('s1', weight: 100, reps: 5), _set('s2', weight: 95, reps: 5), _set('s3', weight: 100, reps: 3)]),
      ('curl', [_set('c1', weight: 15, reps: 10)]),
    ]);
    const plan = WorkoutPlan({
      'lighter': true,
      'exercises': [
        {
          'exerciseId': 'squat',
          'sets': [
            {'setId': 's1', 'weight': 100, 'reps': 5},
            {
              'setId': 's2',
              'weight': 100,
              'target': {
                'reps': {'min': 5, 'max': 5},
              },
            },
            {'setId': 's3', 'weight': 100, 'reps': 5},
            {'setId': 's4', 'weight': 100, 'reps': 5},
          ],
        },
        {
          'exerciseId': 'bench',
          'sets': [
            {'setId': 'b1', 'weight': 80, 'reps': 5},
          ],
        },
      ],
    });

    final review = WorkoutReview.of(workout, plan);

    expect(review.hasPlan, isTrue);
    expect(review.lighterWeek, isTrue);
    final [squat, bench, curl] = review.exercises;
    expect(squat.sets.map((set) => set.outcome), [
      SetOutcome.asked,
      SetOutcome.lighter,
      SetOutcome.fewer,
      SetOutcome.skipped,
    ]);
    expect(squat.sets[1].planned?.reps, 5, reason: "a target's reps are the plan's");
    expect(squat.skipped, isFalse);
    expect(bench.skipped, isTrue);
    expect(bench.exercise, isNull, reason: 'never reached, so the app names it');
    expect(curl.planned, isFalse);
    expect(curl.sets.single.outcome, SetOutcome.added);
  });

  test('a set done beyond the plan, in a planned exercise, is added there', () {
    final workout = _workout([
      ('squat', [_set('s1', weight: 100, reps: 5), _set('s9', weight: 60, reps: 10)]),
    ]);
    const plan = WorkoutPlan({
      'exercises': [
        {
          'exerciseId': 'squat',
          'sets': [
            {'setId': 's1', 'weight': 100, 'reps': 5},
          ],
        },
      ],
    });

    final [squat] = WorkoutReview.of(workout, plan).exercises;

    expect(squat.sets.map((set) => set.outcome), [SetOutcome.asked, SetOutcome.added]);
    expect(
      WorkoutReview.of(
        _workout([
          ('squat', [_set('s1', weight: 100, reps: 5)]),
        ]),
        plan,
      ).offPlan,
      isFalse,
    );
  });

  test('a hold or a distance short of the plan is shorter, not as asked', () {
    final workout = Workout.fromJson({
      'id': 'w2',
      'start': '2026-11-07T19:05:00Z',
      'exercises': [
        {
          'id': 'we-plank',
          'exercise': {..._exercise('plank'), 'category': 'Duration'},
          'start': '2026-11-07T19:05:00Z',
          'order': 0,
          'sets': [
            {'id': 'p1', 'completed': true, 'started_at': '2026-11-07T19:10:00Z', 'duration': 30, 'set_type': 'normal'},
          ],
        },
      ],
    });
    const plan = WorkoutPlan({
      'exercises': [
        {
          'exerciseId': 'plank',
          'sets': [
            {'setId': 'p1', 'duration': 60},
          ],
        },
      ],
    });

    final [plank] = WorkoutReview.of(workout, plan).exercises;

    expect(plank.sets.single.outcome, SetOutcome.shorter);
  });
}
