import 'package:heart_models/heart_models.dart';

/// A filter over an exercise's [Movement], carried in the same set as
/// [Category] and [Target].
///
/// These implement [ExerciseFilter] so the picker renders and removes them like
/// any other chip, but [Exercise.fits] does not know them: it dispatches with
/// `whereType<Category>()` and `whereType<Target>()` and passes everything
/// else, so it fails open rather than throwing. [Exercise.matchesMovement]
/// applies these alongside `fits`, and the two compose.
abstract class MovementFilter implements ExerciseFilter {
  const MovementFilter();

  /// Filters sharing a dimension are OR-ed; different dimensions are AND-ed —
  /// the same shape category and target already have in [Exercise.fits]. Two
  /// patterns widen the result, a pattern and a skill ceiling narrow it.
  ///
  /// Dispatch is keyed on this rather than on the runtime type, so a new
  /// dimension needs no change to [Exercise.matchesMovement].
  String get dimension;

  /// [ExerciseFilter.value] is an identifier here, not copy — the raw pattern
  /// key or enum value.
  ///
  /// Unlike [Category] and [Target], which carry their own English, these are
  /// rendered by the presentation layer: this package cannot reach the
  /// localizations, and a chip needs different wording in the sheet (where a
  /// section header names the dimension) than in the active-filter row (where
  /// it stands alone next to "Chest" and "Barbell").
  @override
  String get value;

  bool matches(Movement movement);
}

/// A movement pattern the exercise must train, e.g. `horizontal_press`.
///
/// Both sides are multi-valued, so this is set intersection rather than
/// equality: an exercise annotated with two patterns matches a filter on
/// either.
class PatternFilter extends MovementFilter {
  final String pattern;

  const PatternFilter(this.pattern);

  @override
  String get dimension => 'pattern';

  @override
  bool matches(Movement movement) => movement.groups.contains(pattern);

  @override
  String get value => pattern;

  @override
  bool operator ==(Object other) => other is PatternFilter && other.pattern == pattern;

  @override
  int get hashCode => pattern.hashCode;

  @override
  String toString() => value;
}

/// Ceiling on technical demand: [SkillLevel.moderate] admits `low` and
/// `moderate`, never `high`.
///
/// [SkillLevel] is ordinal, so this is a ceiling and not set membership — a
/// lifter asking for moderate means "nothing harder than", not "exactly
/// moderate". Two ceilings in the same set OR to the looser one, which is the
/// sane reading of picking both.
class SkillCeiling extends MovementFilter {
  final SkillLevel limit;

  const SkillCeiling(this.limit);

  @override
  String get dimension => 'skill';

  @override
  bool matches(Movement movement) => movement.skill.atMost(limit);

  @override
  String get value => limit.value;

  @override
  bool operator ==(Object other) => other is SkillCeiling && other.limit == limit;

  @override
  int get hashCode => limit.hashCode;

  @override
  String toString() => value;
}

/// How much the movement path is constrained.
///
/// Categorical — `machine` is not "more" than `free` — so chip semantics are
/// correct here, unlike the ordinal dimensions.
class StabilityFilter extends MovementFilter {
  final Stability stability;

  const StabilityFilter(this.stability);

  @override
  String get dimension => 'stability';

  @override
  bool matches(Movement movement) => movement.stability == stability;

  @override
  String get value => stability.value;

  @override
  bool operator ==(Object other) => other is StabilityFilter && other.stability == stability;

  @override
  int get hashCode => stability.hashCode;

  @override
  String toString() => value;
}

extension MovementFiltering on Exercise {
  /// Whether this exercise satisfies every movement dimension present in
  /// [filters]. Filters it does not recognise are ignored, mirroring
  /// [Exercise.fits].
  ///
  /// An exercise with no annotation never matches an active movement filter.
  /// [Movement.empty] is not neutral — it reads as `skill: low`,
  /// `stability: free`, `axialLoad: none` — so a user-created exercise would
  /// otherwise surface under "low skill" while claiming nothing of the sort.
  bool matchesMovement(Iterable<ExerciseFilter> filters) {
    final movementFilters = filters.whereType<MovementFilter>();
    if (movementFilters.isEmpty) return true;
    if (movement.isEmpty) return false;

    final byDimension = <String, List<MovementFilter>>{};
    for (final filter in movementFilters) {
      byDimension.putIfAbsent(filter.dimension, () => []).add(filter);
    }

    return byDimension.values.every(
      (dimension) => dimension.any((filter) => filter.matches(movement)),
    );
  }
}
