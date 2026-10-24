import 'package:heart_models/heart_models.dart';

/// The kinds of exercise a default rest tells apart (#174): one length each,
/// rather than a mode per taste. [seconds] is the length before the user picks
/// their own, and [value] the storage key, which never changes once shipped.
enum RestKind {
  /// A loaded lift that moves several joints: squat, bench, deadlift, row.
  /// The 2–3 minutes a template plans for one (see `WorkoutExercise.rest`).
  compound('compound', 150),

  /// A loaded lift that moves one joint: curl, raise, extension.
  isolation('isolation', 90),

  /// The body as the load, or a clock rather than a load: push-ups, planks,
  /// cardio, carries.
  conditioning('conditioning', 60);

  final String value;
  final int seconds;

  new(this.value, this.seconds);
}

/// The movement patterns of a lift that works several joints at once — read
/// from the library's vocabulary (`docs/2026-10-11.pattern-lens.md`), which
/// content owns: a pattern added there falls to [RestKind.isolation] until it
/// is listed here.
const _compoundPatterns = {
  'horizontal_press',
  'incline_press',
  'decline_press',
  'vertical_press',
  'chest_dip',
  'horizontal_row',
  'vertical_pull',
  'deadlift_floor',
  'hip_hinge_stifflegged',
  'squat_bilateral',
  'lunge_split',
  'olympic_lift',
  'hip_extension_bridge',
  'loaded_carry',
  'sled_push_drag',
};

/// Patterns trained for breath or range rather than load.
const _conditioningPatterns = {
  'cardio_steady',
  'full_body_conditioning',
  'plyometric_lower',
  'mobility',
};

/// Which [RestKind] [exercise] rests as. What the exercise is loaded with comes
/// first — a push-up rests like a plank, not like a bench press — then its
/// movement pattern, and an exercise with no pattern (one the user made) is
/// guessed from its equipment.
RestKind restKindOf(Exercise exercise) {
  final groups = exercise.movement.groups;
  return switch (exercise.category) {
    .cardio || .duration || .repsOnly || .assistedBodyWeight => .conditioning,
    _ when groups.any(_compoundPatterns.contains) => .compound,
    _ when groups.any(_conditioningPatterns.contains) => .conditioning,
    _ when groups.isNotEmpty => .isolation,
    .barbell || .weightedBodyWeight => .compound,
    .dumbbell || .machine => .isolation,
    .weightedDistance || .weightedDuration => .conditioning,
  };
}
