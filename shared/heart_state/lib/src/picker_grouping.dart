import 'package:heart_models/heart_models.dart';

/// How the exercise picker lays out the library before any typing (#620): one
/// flat list, or a heading per category, target or movement pattern.
///
/// One choice for every place the picker appears — the Exercises tab, a
/// workout's Add exercises, the goal and chart pickers, Move history — because
/// it is the same list in all of them. Follows the account ([SettingsSync]).
enum PickerGrouping {
  /// The library as it always was, and the default.
  none,
  category,
  target,
  movement,
  ;

  /// Null for anything this version does not know — a newer app's grouping —
  /// so it never replaces a choice with a guess.
  static PickerGrouping? fromString(String? value) {
    return switch (value) {
      'none' => none,
      'category' => category,
      'target' => target,
      'movement' => movement,
      _ => null,
    };
  }
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
  String get id => 'movement:';
}

typedef GroupedExercises = ({ExerciseGroup group, List<Exercise> exercises});

/// [exercises] under the headings [by] gives them, in the order the filters
/// list them: categories and targets as their menus do, movement patterns as
/// [patterns] does (the filter sheet's order, most common first), then
/// [NoPatternGroup]. Each group keeps [exercises]' own order, and a heading
/// with nothing under it is left out — a filter can empty one.
///
/// An exercise that trains several patterns is under each of them, as the
/// movement filter finds it under each. [PickerGrouping.none] has no headings.
List<GroupedExercises> groupExercises(
  Iterable<Exercise> exercises,
  PickerGrouping by, {
  Iterable<String> patterns = const [],
}) {
  List<GroupedExercises> under<T>(Iterable<T> keys, ExerciseGroup Function(T) group, bool Function(Exercise, T) fits) {
    return [
      for (final key in keys)
        if (exercises.where((each) => fits(each, key)).toList() case final members when members.isNotEmpty)
          (group: group(key), exercises: members),
    ];
  }

  return switch (by) {
    .none => const [],
    .category => under(Category.values, CategoryGroup.new, (each, category) => each.category == category),
    .target => under(Target.values, TargetGroup.new, (each, target) => each.target == target),
    .movement => [
      // a pattern [patterns] does not know yet still gets its heading, last
      ...under(
        {...patterns, ...exercises.expand((each) => each.movement.groups)},
        PatternGroup.new,
        (each, pattern) => each.movement.groups.contains(pattern),
      ),
      if (exercises.where((each) => each.movement.groups.isEmpty).toList() case final rest when rest.isNotEmpty)
        (group: const NoPatternGroup(), exercises: rest),
    ],
  };
}

/// Where the choice lives in the account's [Settings]: `extra.pickerGrouping`,
/// as the enum's name. heart-api keeps keys it does not know.
const _settingsKey = 'pickerGrouping';

/// The grouping [settings] carries; null when it carries none this version can
/// read.
PickerGrouping? pickerGroupingOf(Settings settings) {
  return switch (settings.extra[_settingsKey]) {
    String value => PickerGrouping.fromString(value),
    _ => null,
  };
}

/// [settings] carrying [grouping], every other key as it was.
Settings withPickerGrouping(Settings settings, PickerGrouping grouping) {
  return settings.copyWith(extra: {...settings.extra, _settingsKey: grouping.name});
}
