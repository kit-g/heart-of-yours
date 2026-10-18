import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Sets per muscle group, and the sets that could not be placed (#136).
///
/// Counted per atlas [MuscleGroup], not per muscle: the library tags almost
/// half its exercises by group alone ("legs", "arms"), and spreading such a set
/// across every muscle in the group would invent precision the data does not
/// have. Finer regions wait on finer tagging.
typedef MuscleVolume = ({Map<MuscleGroup, double> sets, int unmapped});

/// Folds [rows] — completed sets per exercise, with the exercise's tagging —
/// into [MuscleVolume], each row placed by [muscleSharesOf].
///
/// A row that places nothing — an untagged exercise whose target no group
/// answers to (cardio, the whole body) — adds to `unmapped` rather than
/// vanishing, so the map can say what it left out.
MuscleVolume muscleVolume(Iterable<MuscleSets> rows) {
  return _volume(rows.map((row) => (muscles: row.muscles, target: row.target, sets: row.sets)));
}

/// What [muscleVolume] reads of a row: no time, so a plan can be one too.
typedef _Placed = ({MuscleTagging muscles, Target target, int sets});

MuscleVolume _volume(Iterable<_Placed> rows) {
  return rows.fold(
    (sets: <MuscleGroup, double>{}, unmapped: 0),
    (volume, row) {
      final shares = muscleSharesOf(row.muscles, row.target);
      if (shares.isEmpty) {
        return (sets: volume.sets, unmapped: volume.unmapped + row.sets);
      }

      for (final MapEntry(key: group, value: share) in shares.entries) {
        volume.sets.update(group, (count) => count + row.sets * share, ifAbsent: () => row.sets * share);
      }
      return volume;
    },
  );
}

/// Whether the map counts a set: warm-ups are left out, as the map's
/// read of a period leaves them out (#236).
bool _counts(ExerciseSet set) => set.setType != .warmup;

/// [exercise]'s tagging from the library when it knows the exercise: the copy
/// a workout or a template carries may have been synced without it.
MuscleTagging _tagging(Exercise exercise, Exercise? Function(ExerciseId) lookup) {
  return switch (lookup(exercise.id)?.muscles) {
    MuscleTagging muscles when !muscles.isEmpty => muscles,
    _ => exercise.muscles,
  };
}

/// One workout's completed sets per exercise, as [muscleVolume] reads them
/// (#223).
///
/// An exercise with no sets done adds nothing, not even to `unmapped`.
Iterable<MuscleSets> workoutMuscleSets(Workout workout, {required Exercise? Function(ExerciseId) lookup}) {
  return workout
      .map(
        (each) => (
          start: workout.start,
          muscles: _tagging(each.exercise, lookup),
          target: each.exercise.target,
          sets: each.where((set) => set.isCompleted && _counts(set)).length,
        ),
      )
      .where((row) => row.sets > 0);
}

/// What a template plans, per muscle group (#263): every set it lists, counted
/// the way [workoutMuscleSets] counts a finished one, warm-ups left out.
MuscleVolume plannedMuscleVolume(
  Iterable<WorkoutExercise> exercises, {
  required Exercise? Function(ExerciseId) lookup,
}) {
  return _volume(
    exercises
        .map(
          (each) => (
            muscles: _tagging(each.exercise, lookup),
            target: each.exercise.target,
            sets: plannedSets(each),
          ),
        )
        .where((row) => row.sets > 0),
  );
}

/// The sets of [exercise] a plan's muscle map counts.
int plannedSets(WorkoutExercise exercise) => exercise.where(_counts).length;

/// The last [days] calendar days, today included, of [rows].
///
/// Calendar days rather than a [Duration], so the window survives a DST change.
Iterable<MuscleSets> lastDays(Iterable<MuscleSets> rows, int days, {required DateTime now}) {
  final from = DateTime(now.year, now.month, now.day - (days - 1));
  return rows.where((row) => !row.start.isBefore(from));
}

/// The first days of the [weeks] weeks ending with [now]'s, oldest first, for
/// weeks that start on [firstWeekday] — the user's (#339).
List<DateTime> lastWeeks(int weeks, {required DateTime now, required int firstWeekday}) {
  final start = weekOf(now, firstWeekday: firstWeekday);
  return [
    for (final back in Iterable<int>.generate(weeks, (index) => weeks - 1 - index))
      DateTime(start.year, start.month, start.day - 7 * back),
  ];
}

/// The first days of the [months] calendar months ending with [now]'s, oldest
/// first.
List<DateTime> lastMonths(int months, {required DateTime now}) {
  return [
    for (final back in Iterable<int>.generate(months, (index) => months - 1 - index))
      DateTime(now.year, now.month - back),
  ];
}

/// [rows] counted into [weeks] (their first days, as [lastWeeks] gives them,
/// for the same [firstWeekday]), one [MuscleVolume] per week. Rows outside
/// every week are left out.
Map<DateTime, MuscleVolume> weeklyMuscleVolume(
  Iterable<MuscleSets> rows,
  List<DateTime> weeks, {
  required int firstWeekday,
}) {
  return _bucketed(rows, weeks, (start) => weekOf(start, firstWeekday: firstWeekday));
}

/// [rows] counted into [months] (their first days, as [lastMonths] gives
/// them), one [MuscleVolume] per month. Rows outside every month are left out.
Map<DateTime, MuscleVolume> monthlyMuscleVolume(Iterable<MuscleSets> rows, List<DateTime> months) {
  return _bucketed(rows, months, (start) => DateTime(start.year, start.month));
}

Map<DateTime, MuscleVolume> _bucketed(
  Iterable<MuscleSets> rows,
  List<DateTime> buckets,
  DateTime Function(DateTime start) bucketOf,
) {
  final grouped = <DateTime, List<MuscleSets>>{for (final bucket in buckets) bucket: []};
  for (final row in rows) {
    grouped[bucketOf(row.start)]?.add(row);
  }
  return grouped.map((bucket, rows) => MapEntry(bucket, muscleVolume(rows)));
}

/// What [row]'s sets count toward under the muscle key (#341):
/// [muscleSharesOf] its tagging and target.
Map<MuscleGroup, double> muscleGroupsOf(LensSets row) => muscleSharesOf(row.muscles, row.target);

/// The share of one set each atlas group receives, by the rule the server
/// counts with (`MuscleTagging.groupShares`, `docs/2026-10-11.pattern-lens.md`
/// rules 7 and 8), so the map, the weekly card and the coach over MCP agree:
/// the groups [muscles] reaches, primary ones at the content's primary share
/// and the others at its secondary share. An exercise nobody tagged — one the
/// user made — falls to the group its [target] names, in full; a target no
/// group answers to places nothing.
Map<MuscleGroup, double> muscleSharesOf(MuscleTagging muscles, Target target) {
  return switch (muscles.groupShares) {
    final shares when shares.isNotEmpty => {
      for (final MapEntry(:key, value: share) in shares.entries) ?_atlasGroup(key): share,
    },
    _ => {?_atlasGroup(target.muscleGroup): 1.0},
  };
}

/// The atlas's own group for a heart_models one: the same ten, by id.
MuscleGroup? _atlasGroup(MuscleGroupKey? key) {
  return switch (key) {
    MuscleGroupKey(:final value) => MuscleGroup.tryFromString(value),
    null => null,
  };
}
