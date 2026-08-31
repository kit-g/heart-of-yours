import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Display copy for the exercise filters, which carry identifiers rather than
/// words.
///
/// [Category] and [Target] ship English in the model, but that is a wire
/// identifier ([Category.fromString] round-trips it) — copy for all of them
/// is decided here, next to the localizations. A standalone library rather
/// than a part file because the picker's filter sheet, the exercise About tab,
/// the list tiles, and the exercise editor all render these.
extension MovementFilterCopy on MovementFilter {
  /// Short form, for the filter sheet — the section header above already names
  /// the dimension, so repeating it in every chip is noise.
  String label(L l10n) {
    return switch (this) {
      PatternFilter(:final pattern) => _patternLabel(pattern, l10n),
      SkillCeiling(:final limit) => limit.label(l10n),
      StabilityFilter(:final stability) => stability.label(l10n),
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

extension CategoryCopy on Category {
  String label(L l10n) {
    return switch (this) {
      .weightedBodyWeight => l10n.categoryWeightedBodyWeight,
      .assistedBodyWeight => l10n.categoryAssistedBodyWeight,
      .repsOnly => l10n.categoryRepsOnly,
      .cardio => l10n.categoryCardio,
      .duration => l10n.categoryDuration,
      .machine => l10n.categoryMachine,
      .dumbbell => l10n.categoryDumbbell,
      .barbell => l10n.categoryBarbell,
    };
  }
}

extension TargetCopy on Target {
  String label(L l10n) {
    return switch (this) {
      .core => l10n.targetCore,
      .arms => l10n.targetArms,
      .back => l10n.targetBack,
      .chest => l10n.targetChest,
      .legs => l10n.targetLegs,
      .shoulder => l10n.targetShoulders,
      .other => l10n.targetOther,
      .olympic => l10n.targetOlympic,
      .fullBody => l10n.targetFullBody,
      .cardio => l10n.targetCardio,
    };
  }
}

extension SkillLevelCopy on SkillLevel {
  String label(L l10n) {
    return switch (this) {
      .low => l10n.skillLow,
      .moderate => l10n.skillModerate,
      .high => l10n.skillHigh,
    };
  }
}

extension StabilityCopy on Stability {
  String label(L l10n) {
    return switch (this) {
      .free => l10n.stabilityFree,
      .supported => l10n.stabilitySupported,
      .machine => l10n.stabilityMachine,
    };
  }
}

/// The 38 patterns the library uses today get real copy; anything newer falls
/// back to the humanized identifier (`hip_thrust` reads as `Hip Thrust`).
/// Content owns the vocabulary and can add a pattern without an app release,
/// so an unknown key must label itself rather than ship blank — the fallback
/// is the seam that keeps that promise, the switch is what localizes the
/// known world.
String _patternLabel(String pattern, L l10n) {
  return switch (pattern) {
    'calf_raise' => l10n.patternCalfRaise,
    'cardio_steady' => l10n.patternCardioSteady,
    'chest_dip' => l10n.patternChestDip,
    'chest_fly' => l10n.patternChestFly,
    'core_bracing' => l10n.patternCoreBracing,
    'deadlift_floor' => l10n.patternDeadliftFloor,
    'decline_press' => l10n.patternDeclinePress,
    'elbow_extension' => l10n.patternElbowExtension,
    'elbow_flexion' => l10n.patternElbowFlexion,
    'forearm' => l10n.patternForearm,
    'front_raise' => l10n.patternFrontRaise,
    'full_body_conditioning' => l10n.patternFullBodyConditioning,
    'glute_isolation' => l10n.patternGluteIsolation,
    'hip_abduction' => l10n.patternHipAbduction,
    'hip_adduction' => l10n.patternHipAdduction,
    'hip_extension_bridge' => l10n.patternHipExtensionBridge,
    'hip_flexion_hanging' => l10n.patternHipFlexionHanging,
    'hip_hinge_stifflegged' => l10n.patternHipHingeStifflegged,
    'horizontal_press' => l10n.patternHorizontalPress,
    'horizontal_row' => l10n.patternHorizontalRow,
    'incline_press' => l10n.patternInclinePress,
    'knee_extension' => l10n.patternKneeExtension,
    'knee_flexion' => l10n.patternKneeFlexion,
    'lateral_raise' => l10n.patternLateralRaise,
    'lunge_split' => l10n.patternLungeSplit,
    'mobility' => l10n.patternMobility,
    'olympic_lift' => l10n.patternOlympicLift,
    'plyometric_lower' => l10n.patternPlyometricLower,
    'pullover' => l10n.patternPullover,
    'rear_delt' => l10n.patternRearDelt,
    'shrug' => l10n.patternShrug,
    'spinal_extension' => l10n.patternSpinalExtension,
    'squat_bilateral' => l10n.patternSquatBilateral,
    'trunk_flexion' => l10n.patternTrunkFlexion,
    'trunk_lateral_rotation' => l10n.patternTrunkLateralRotation,
    'upright_row' => l10n.patternUprightRow,
    'vertical_press' => l10n.patternVerticalPress,
    'vertical_pull' => l10n.patternVerticalPull,
    _ => pattern.split('_').map(_capitalize).join(' '),
  };
}

String _capitalize(String word) {
  return switch (word) {
    '' => word,
    _ => '${word[0].toUpperCase()}${word.substring(1)}',
  };
}
