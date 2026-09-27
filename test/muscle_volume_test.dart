import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/muscle_volume.dart';
import 'package:heart_models/heart_models.dart';

({MuscleTagging muscles, int sets}) row(
  int sets, {
  List<String> primaryIds = const [],
  List<String> primaryGroups = const [],
  List<String> secondaryIds = const [],
  List<String> secondaryGroups = const [],
}) {
  return (
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
      (muscles: MuscleTagging.empty(), sets: 3),
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
}
