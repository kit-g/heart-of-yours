import 'package:flutter_body_atlas/flutter_body_atlas.dart';
import 'package:heart_models/heart_models.dart';

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
MuscleVolume muscleVolume(Iterable<({MuscleTagging muscles, int sets})> rows) {
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

/// The atlas groups a tag reaches: the ones it names, and the groups of the
/// muscles it names. Ids and names the atlas does not know are dropped.
Set<MuscleGroup> _groupsOf(MuscleTag? tag) {
  return {
    ...?tag?.groups?.map(MuscleGroup.tryFromString).nonNulls,
    ...?tag?.ids?.map(MuscleCatalog.tryById).nonNulls.map((muscle) => muscle.group),
  };
}
