import 'package:heart_models/heart_models.dart';

import 'screen_choices.dart';

/// How the exercise picker lays out the library before any typing (#620): one
/// flat list, or a heading per category, target or movement pattern.
///
/// One choice for every place the picker appears — the Exercises tab, a
/// workout's Add exercises, the goal and chart pickers, Move history — because
/// it is the same list in all of them. A screen choice
/// ([ScreenChoice.pickerGrouping]), stored and synced by its [name].
enum PickerGrouping {
  /// The library as it always was, and the default.
  none,
  category,
  target,
  movement,
  ;

  /// Null for anything this version does not know — a newer app's grouping —
  /// so it never replaces a choice with a guess.
  static PickerGrouping? fromString(String? value) => values.asNameMap()[value];
}

/// One heading of a grouped picker. Carries identifiers only; the picker
/// words them.
sealed class ExerciseGroup {
  const new();

  /// Stable across launches and unique across groupings — a target and a
  /// category can share a name (`cardio`): what this device remembers a
  /// group's fold under.
  String get id;

  @override
  bool operator ==(Object other) => other is ExerciseGroup && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ExerciseGroup($id)';
}

final class const CategoryGroup(final Category category) extends ExerciseGroup {
  @override
  String get id => 'category:${category.name}';
}

final class const TargetGroup(final Target target) extends ExerciseGroup {
  @override
  String get id => 'target:${target.name}';
}

/// A movement pattern, by its key (`horizontal_press`).
final class const PatternGroup(final String pattern) extends ExerciseGroup {
  @override
  String get id => 'movement:$pattern';
}

/// The exercises with no movement pattern at all — custom ones, mostly —
/// under Movement, after every pattern.
final class const NoPatternGroup() extends ExerciseGroup {
  @override
  // no colon: every [PatternGroup] has one, whatever its pattern
  String get id => 'movement';
}

typedef GroupedExercises = ({ExerciseGroup group, List<Exercise> exercises});

/// [exercises] under the headings [by] gives them, in the order the filters
/// list them: categories and targets as their menus do, movement patterns as
/// [patterns] does (the filter sheet's order, most common first), then
/// [NoPatternGroup]. Each group keeps [exercises]' own order, and a heading
/// with nothing under it is left out — a filter can empty one.
///
/// An exercise that trains several patterns is under each of them, as the
/// movement filter finds it under each; an empty pattern key is no pattern.
/// [patterns] is only asked for by movement — it walks the whole library.
/// [PickerGrouping.none] has no headings.
List<GroupedExercises> groupExercises(
  Iterable<Exercise> exercises,
  PickerGrouping by, {
  Iterable<String> Function()? patterns,
}) {
  Iterable<ExerciseGroup> groupsOf(Exercise exercise) {
    return switch (by) {
      .none => const [],
      .category => [CategoryGroup(exercise.category)],
      .target => [TargetGroup(exercise.target)],
      .movement => switch (exercise.movement.groups) {
        Iterable<String> found when found.isEmpty => const [NoPatternGroup()],
        Iterable<String> found => found.toSet().map(PatternGroup.new),
      },
    };
  }

  // one pass over the list, each exercise into every group it is under
  final buckets = exercises
      .expand((each) => groupsOf(each).map((group) => (group, each)))
      .fold(
        <ExerciseGroup, List<Exercise>>{},
        (buckets, entry) => buckets..putIfAbsent(entry.$1, () => []).add(entry.$2),
      );

  final Iterable<ExerciseGroup> order = switch (by) {
    .none => const [],
    .category => Category.values.map(CategoryGroup.new),
    .target => Target.values.map(TargetGroup.new),
    .movement => {
      ...?patterns?.call().map(PatternGroup.new),
      // a pattern [patterns] does not know yet still gets its heading, after it
      ...buckets.keys.whereType<PatternGroup>(),
      const NoPatternGroup(),
    },
  };

  return [
    for (final group in order)
      if (buckets[group] case final members?) (group: group, exercises: members),
  ];
}

/// The exercise a grouped picker pictures [members]' heading by (#711): of
/// those with a thumbnail, when any has one, the one done most
/// ([timesDone], finished sessions), then the best known ([_staples]), then
/// the first in [members]' order. Null for no members.
///
/// The picture comes first because it is what the heading is for: a custom
/// exercise done every week has none, and would leave the heading as bare as
/// before. Someone who has done nothing in the group still gets a familiar
/// face — the squat over whichever squat sorts first.
Exercise? representativeOf(List<Exercise> members, {int Function(ExerciseId)? timesDone}) {
  final pictured = members.where((each) => each.thumbnail != null).toList();
  final candidates = pictured.isEmpty ? members : pictured;
  if (candidates.isEmpty) return null;

  int staple(Exercise exercise) {
    return switch (_stapleRank[exercise.key]) {
      int rank => rank,
      null => _stapleRank.length,
    };
  }

  final ranked = [
    for (final (order, exercise) in candidates.indexed)
      (exercise: exercise, done: timesDone?.call(exercise.id) ?? 0, staple: staple(exercise), order: order),
  ];
  ranked.sort(
    (a, b) => [
      b.done.compareTo(a.done),
      a.staple.compareTo(b.staple),
      a.order.compareTo(b.order),
    ].firstWhere((each) => each != 0, orElse: () => 0),
  );
  return ranked.first.exercise;
}

/// Library slugs ([Exercise.key]) a lifter knows on sight, best known first:
/// the big lifts, then one staple per family of movement. The library has no
/// popularity of its own to read, and its order is alphabetical, which put
/// "Ab Wheel" over Core and "Air Bike" over Cardio. A slug the library drops
/// is simply never matched, and the group falls back to its own order.
const _staples = [
  'squat-barbell',
  'bench-press-barbell',
  'deadlift-barbell',
  'overhead-press-barbell',
  'pull-up',
  'pull-up-assisted',
  'bent-over-row-barbell',
  'push-up',
  'bicep-curl-dumbbell',
  'lat-pulldown-cable',
  'leg-press',
  'plank',
  'running',
  'plank-weighted',
  'farmers-walk',
  'burpee',
  'power-clean',
  'bench-press-dumbbell',
  'romanian-deadlift-barbell',
  'hip-thrust-barbell',
  'lunge-dumbbell',
  'lateral-raise-dumbbell',
  'triceps-pushdown-cable-straight-bar',
  'incline-bench-press-barbell',
  'seated-row-cable',
  'chest-fly-dumbbell',
  'chest-dip',
  'crunch',
  'hanging-leg-raise',
  'standing-calf-raise-machine',
  'leg-extension-machine',
  'seated-leg-curl-machine',
  'face-pull-cable',
  'shrug-dumbbell',
  'upright-row-barbell',
  'front-raise-dumbbell',
  'pullover-dumbbell',
  'russian-twist',
  'back-extension',
  'box-jump',
  'sled-push',
  'hip-abductor-machine',
  'hip-adductor-machine',
  'kettlebell-swing',
  'stretching',
];

final _stapleRank = {for (final (rank, key) in _staples.indexed) key: rank};
