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
