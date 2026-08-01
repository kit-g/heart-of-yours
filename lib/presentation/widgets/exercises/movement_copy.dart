import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Display copy for the movement filters, which carry identifiers rather than
/// words.
///
/// [Category] and [Target] ship their own English in the model; the movement
/// filters deliberately do not, so the wording is decided here, next to the
/// localizations. A standalone library rather than a part file because both the
/// picker's filter sheet and the exercise About tab render these.
extension MovementFilterCopy on MovementFilter {
  /// Short form, for the filter sheet — the section header above already names
  /// the dimension, so repeating it in every chip is noise.
  String label(L l10n) {
    return switch (this) {
      // `horizontal_press` reads as `Horizontal Press`. Derived rather than
      // translated: content owns the vocabulary and can add a pattern without
      // an app release, so a hand-written label per group would ship blank.
      PatternFilter(:final pattern) => pattern.split('_').map(_capitalize).join(' '),
      SkillCeiling(:final limit) => _capitalize(limit.value),
      StabilityFilter(:final stability) => _capitalize(stability.value),
      _ => value,
    };
  }

  /// Long form, for the picker's active-filter row, where a chip stands alone
  /// between "Chest" and "Barbell" — a bare "Machine" there is
  /// indistinguishable from [Category.machine].
  String chipLabel(L l10n) {
    return switch (this) {
      SkillCeiling() => '${l10n.skillAtMost}: ${label(l10n)}',
      StabilityFilter() => '${l10n.stability}: ${label(l10n)}',
      _ => label(l10n),
    };
  }
}

String _capitalize(String word) {
  return switch (word) {
    '' => word,
    _ => '${word[0].toUpperCase()}${word.substring(1)}',
  };
}
