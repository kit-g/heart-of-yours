import 'dart:convert';

import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/muscle_volume.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

MuscleSets row(
  int sets, {
  DateTime? start,
  List<String> primaryIds = const [],
  List<String> primaryGroups = const [],
  List<String> secondaryIds = const [],
  List<String> secondaryGroups = const [],
}) {
  return (
    start: start ?? DateTime(2026, 9, 23),
    muscles: MuscleTagging.fromJson({
      'primary': {'ids': primaryIds, 'groups': primaryGroups},
      'secondary': {'ids': secondaryIds, 'groups': secondaryGroups},
    }),
    sets: sets,
  );
}

void main() {
  test('a primary group counts every set, a secondary one half', () {
    final (:sets, :unmapped) = muscleVolume([
      row(4, primaryIds: ['pectoralis_major_l', 'pectoralis_major_r'], secondaryGroups: ['arms']),
    ]);

    expect(sets, {MuscleGroup.chest: 4, MuscleGroup.arms: 2});
    expect(unmapped, 0);
  });

  test('two muscles of one group count the set once, not twice', () {
    final (:sets, unmapped: _) = muscleVolume([
      row(
        3,
        primaryIds: ['triceps_brachii_caput_longum_l', 'triceps_brachii_caput_laterale_l'],
        primaryGroups: ['arms'],
      ),
    ]);

    expect(sets, {MuscleGroup.arms: 3});
  });

  test('a group both primary and secondary counts as primary', () {
    final (:sets, unmapped: _) = muscleVolume([
      row(2, primaryGroups: ['legs'], secondaryGroups: ['legs', 'glutes']),
    ]);

    expect(sets, {MuscleGroup.legs: 2, MuscleGroup.glutes: 1});
  });

  test('exercises add up across rows', () {
    final (:sets, unmapped: _) = muscleVolume([
      row(3, primaryGroups: ['chest']),
      row(5, primaryGroups: ['back'], secondaryGroups: ['chest']),
    ]);

    expect(sets, {MuscleGroup.chest: 5.5, MuscleGroup.back: 5});
  });

  test('untagged exercises are unmapped, not dropped', () {
    final (:sets, :unmapped) = muscleVolume([
      row(4),
      row(2, primaryGroups: ['core']),
      (start: DateTime(2026, 9, 23), muscles: MuscleTagging.empty(), sets: 3),
    ]);

    expect(sets, {MuscleGroup.core: 2});
    expect(unmapped, 7);
  });

  test('ids and groups the atlas does not know are dropped; nothing left is unmapped', () {
    final (:sets, :unmapped) = muscleVolume([
      row(2, primaryIds: ['no_such_muscle'], primaryGroups: ['no_such_group']),
    ]);

    expect(sets, isEmpty);
    expect(unmapped, 2);
  });

  test('nothing in, nothing out', () {
    final (:sets, :unmapped) = muscleVolume(const []);
    expect(sets, isEmpty);
    expect(unmapped, 0);
  });

  group('windows and weeks', () {
    // a Sunday evening: the end of the week, and a DST-free stretch
    final now = DateTime(2026, 9, 27, 21);

    test('lastDays keeps today and the days before it, by the calendar', () {
      final rows = [
        row(1, start: DateTime(2026, 9, 21, 0, 0)), // 7 days back, first minute
        row(2, start: DateTime(2026, 9, 20, 23, 59)), // one minute too early
        row(4, start: DateTime(2026, 9, 27, 8)),
      ];

      expect(lastDays(rows, 7, now: now).map((each) => each.sets), [1, 4]);
      expect(lastDays(rows, 30, now: now).map((each) => each.sets), [1, 2, 4]);
    });

    test('lastWeeks is the Mondays of the weeks ending with this one, oldest first', () {
      expect(lastWeeks(3, now: now), [DateTime(2026, 9, 7), DateTime(2026, 9, 14), DateTime(2026, 9, 21)]);
    });

    test('weeklyMuscleVolume buckets by the week a workout started in, and drops the rest', () {
      final weeks = lastWeeks(2, now: now);
      final weekly = weeklyMuscleVolume([
        row(3, start: DateTime(2026, 9, 14, 7), primaryGroups: ['chest']), // Monday of week one
        row(2, start: DateTime(2026, 9, 20, 23), primaryGroups: ['chest']), // Sunday, still week one
        row(5, start: DateTime(2026, 9, 21, 6), primaryGroups: ['back']), // Monday: week two
        row(9, start: DateTime(2026, 9, 1), primaryGroups: ['legs']), // before both
        row(1, start: DateTime(2026, 9, 25)), // untagged
      ], weeks);

      expect(weekly.keys, weeks);
      expect(weekly[weeks.first]?.sets, {MuscleGroup.chest: 5});
      expect(weekly[weeks.last]?.sets, {MuscleGroup.back: 5});
      expect(weekly[weeks.last]?.unmapped, 1);
    });
    test('lastMonths is the first days of the months ending with this one, across a year boundary', () {
      expect(lastMonths(3, now: DateTime(2026, 2, 14)), [DateTime(2025, 12), DateTime(2026, 1), DateTime(2026, 2)]);
    });

    test('monthlyMuscleVolume buckets by the month a workout started in, and drops the rest', () {
      final months = lastMonths(2, now: now);
      final monthly = monthlyMuscleVolume([
        row(3, start: DateTime(2026, 8, 31, 23), primaryGroups: ['chest']),
        row(4, start: DateTime(2026, 9, 1, 0, 5), primaryGroups: ['chest']),
        row(9, start: DateTime(2026, 7, 31), primaryGroups: ['legs']),
      ], months);

      expect(monthly.keys, months);
      expect(monthly[DateTime(2026, 8)]?.sets, {MuscleGroup.chest: 3});
      expect(monthly[DateTime(2026, 9)]?.sets, {MuscleGroup.chest: 4});
    });
  });

  group('one workout (#223)', () {
    MuscleTagging tags(String json) => MuscleTagging.fromJson(jsonDecode(json));

    test('counts completed sets only, and skips an exercise with none done', () {
      final bench = Exercise(
        name: 'Bench Press',
        category: .barbell,
        target: .chest,
        tags: tags('{"primary": {"groups": ["chest"]}, "secondary": {"groups": ["arms"]}}'),
      );
      final squat = Exercise(
        name: 'Squat',
        category: .barbell,
        target: .legs,
        tags: tags('{"primary": {"groups": ["legs"]}}'),
      );
      final workout = Workout(name: 'Monday');
      workout.add(bench)
        ..first.isCompleted = true
        ..add(ExerciseSet(bench, weight: 60, reps: 5)..isCompleted = true)
        ..add(ExerciseSet(bench, weight: 60, reps: 5));
      workout.add(squat);

      final rows = workoutMuscleSets(workout, lookup: (_) => null).toList();
      expect(rows.map((row) => row.sets), [2]);
      expect(muscleVolume(rows).sets, {MuscleGroup.chest: 2, MuscleGroup.arms: 1});
    });

    test("takes the library's tagging over the workout's own copy", () {
      final untagged = Exercise(name: 'Row', category: .barbell, target: .back);
      final tagged = Exercise(
        name: 'Row',
        category: .barbell,
        target: .back,
        tags: tags('{"primary": {"groups": ["back"]}}'),
      );
      final workout = Workout(name: 'Tuesday');
      workout.add(untagged).first.isCompleted = true;

      expect(muscleVolume(workoutMuscleSets(workout, lookup: (_) => null)).unmapped, 1);
      expect(muscleVolume(workoutMuscleSets(workout, lookup: (_) => tagged)).sets, {MuscleGroup.back: 1});
    });
  });
}
