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

/// How much a set counts toward a secondary muscle group. Primary groups count
/// in full.
const secondaryShare = .5;

/// Folds [rows] — completed sets per exercise, with the exercise's tagging —
/// into [MuscleVolume].
///
/// A group named as both primary and secondary counts once, as primary. An
/// exercise tagged with nothing (a custom one, so far — #176) adds to
/// `unmapped` rather than vanishing, so the map can say what it left out.
MuscleVolume muscleVolume(Iterable<MuscleSets> rows) {
  return rows.fold(
    (sets: <MuscleGroup, double>{}, unmapped: 0),
    (volume, row) {
      final primary = _groupsOf(row.muscles.primary);
      final secondary = _groupsOf(row.muscles.secondary).difference(primary);
      if (primary.isEmpty && secondary.isEmpty) {
        return (sets: volume.sets, unmapped: volume.unmapped + row.sets);
      }

      for (final (groups, share) in [(primary, 1.0), (secondary, secondaryShare)]) {
        for (final group in groups) {
          volume.sets.update(group, (count) => count + row.sets * share, ifAbsent: () => row.sets * share);
        }
      }
      return volume;
    },
  );
}

/// One workout's completed sets per exercise, as [muscleVolume] reads them
/// (#223).
///
/// The tagging comes from the library when it knows the exercise: the copy a
/// workout carries may have been synced without it. An exercise with no sets
/// done adds nothing, not even to `unmapped`.
Iterable<MuscleSets> workoutMuscleSets(Workout workout, {required Exercise? Function(ExerciseId) lookup}) {
  MuscleTagging tagging(Exercise exercise) {
    return switch (lookup(exercise.id)?.muscles) {
      MuscleTagging muscles when !muscles.isEmpty => muscles,
      _ => exercise.muscles,
    };
  }

  return workout
      .map(
        (each) => (
          start: workout.start,
          muscles: tagging(each.exercise),
          sets: each.where((set) => set.isCompleted).length,
        ),
      )
      .where((row) => row.sets > 0);
}

/// The last [days] calendar days, today included, of [rows].
///
/// Calendar days rather than a [Duration], so the window survives a DST change.
Iterable<MuscleSets> lastDays(Iterable<MuscleSets> rows, int days, {required DateTime now}) {
  final from = DateTime(now.year, now.month, now.day - (days - 1));
  return rows.where((row) => !row.start.isBefore(from));
}

/// The Mondays of the [weeks] calendar weeks ending with [now]'s, oldest
/// first — the weeks the profile's workouts-per-week chart buckets by too.
List<DateTime> lastWeeks(int weeks, {required DateTime now}) {
  final monday = getMonday(now);
  return [
    for (final back in Iterable<int>.generate(weeks, (index) => weeks - 1 - index))
      DateTime(monday.year, monday.month, monday.day - 7 * back),
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

/// [rows] counted into [weeks] (their Mondays, as [lastWeeks] gives them), one
/// [MuscleVolume] per week. Rows outside every week are left out.
Map<DateTime, MuscleVolume> weeklyMuscleVolume(Iterable<MuscleSets> rows, List<DateTime> weeks) {
  return _bucketed(rows, weeks, getMonday);
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

/// The atlas groups a tag reaches: the ones it names, and the groups of the
/// muscles it names. Ids and names the atlas does not know are dropped.
Set<MuscleGroup> _groupsOf(MuscleTag? tag) {
  return {
    ...?tag?.groups?.map(MuscleGroup.tryFromString).nonNulls,
    ...?tag?.ids?.map(MuscleCatalog.tryById).nonNulls.map((muscle) => muscle.group),
  };
}
