import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Targets on template sets through the mirror (#173).
///
/// A template's sets are JSON in `template_exercises.description`, so a target
/// rides in them as `toMap` writes it, a measure this build can't read
/// included. A workout started from the template keeps them in `sets.target`,
/// so the sheet still shows them after the app restarts mid-workout.
void main() {
  sqfliteFfiInit();

  late Database db;
  late LocalDatabase local;

  const user = 'user-1';
  const bench = 'catalog-bench';

  final benchPress = Exercise.fromJson({
    'id': bench,
    'name': 'Bench Press (Barbell)',
    'category': 'Barbell',
    'target': 'Chest',
  });

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
    await db.insert('exercises', {
      'id': bench,
      'name': 'Bench Press (Barbell)',
      'category': 'Barbell',
      'target': 'Chest',
    });
  });

  tearDown(() => db.close());

  /// Six to ten reps at 80% of a program's base, and a measure from a build
  /// newer than this one.
  SetTarget doubleProgression() {
    return SetTarget.fromJson({
      'reps': {'min': 6, 'max': 10},
      'share': 0.8,
      'pace': {'min': 5},
    });
  }

  Future<Template> templateWith(SetTarget? target) async {
    final raw = await local.startTemplate(userId: user);
    final workout = Workout.fromExercises([
      WorkoutExercise(starter: ExerciseSet(benchPress, weight: 60, target: target)),
    ]);
    final template = Template.fromWorkout(raw.id, workout, raw.order)..name = 'Push';
    await local.updateTemplate(template);
    return template;
  }

  test('a template set keeps its target, what this build cannot read included', () async {
    await templateWith(doubleProgression());

    final [read] = (await local.getTemplates(user)).toList();
    final set = read.first.first;

    expect(set.target?[.reps], const TargetRange(min: 6, max: 10));
    expect(set.target?.share, 0.8);
    expect(set.target?.toMap(), doubleProgression().toMap());
    expect(set.weight, 60);
  });

  test('a template set without a target reads back without one', () async {
    await templateWith(null);

    final [read] = (await local.getTemplates(user)).toList();
    expect(read.first.first.target, isNull);
  });

  test('a workout started from the template keeps the targets through a restart', () async {
    final template = await templateWith(doubleProgression());
    await local.startWorkout(template.toWorkout(), user);

    final reopened = await LocalDatabase.init(other: db);
    final active = (await reopened.getActiveWorkout(user))!;
    final set = active.first.first;

    expect(set.target?.toMap(), doubleProgression().toMap());
    expect(set.isCompleted, isFalse);
  });

  test('a logged set aims at nothing', () async {
    final template = await templateWith(null);
    await local.startWorkout(template.toWorkout(), user);

    final active = (await local.getActiveWorkout(user))!;
    expect(active.first.first.target, isNull);
  });

  group('a finished workout and the server copy (#173)', () {
    /// A program session's workout, finished: one ticked set aiming at a
    /// target.
    Future<Workout> finished() async {
      final template = await templateWith(doubleProgression());
      final workout = template.toWorkout();
      workout.first.first
        ..setMeasurements(weight: 60, reps: 8)
        ..isCompleted = true;
      workout.finish(DateTime.timestamp());
      await local.finishWorkout(workout, user);
      return workout;
    }

    /// [workout] as the server sends it back: its sets keep no target, so
    /// the key is not there at all.
    Workout echoed(Workout workout, {bool clearTargets = false}) {
      final map = workout.toMap();
      for (final exercise in map['exercises'] as List) {
        for (final set in (exercise as Map)['sets'] as List) {
          (set as Map).remove('target');
          if (clearTargets) set['target'] = null;
        }
      }
      return Workout.fromJson(map);
    }

    test('a server copy without targets keeps the ones the session wrote', () async {
      final workout = await finished();

      await local.storeWorkoutHistory([echoed(workout)], user);

      final read = (await local.getWorkout(user, workout.id))!;
      final set = read.first.first;
      expect(set.target?.toMap(), doubleProgression().toMap());
      expect(set.reps, 8);
    });

    test('a copy that clears a target clears it', () async {
      final workout = await finished();

      await local.storeWorkoutHistory([echoed(workout, clearTargets: true)], user);

      final read = (await local.getWorkout(user, workout.id))!;
      expect(read.first.first.target, isNull);
    });
  });
}
