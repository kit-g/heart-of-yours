import 'package:heart_health/models.dart';
import 'package:heart_models/heart_models.dart';

/// What a finished session should be called in the device's health store.
///
/// Heart logs far more than lifting — the library has cycling, swimming,
/// rowing, skiing and a dozen more — so writing every session back as strength
/// training would mislabel a real workout in the user's own health record, next
/// to whatever their watch recorded for the same hour.
///
/// Each exercise carries its own activity, annotated once in the library and
/// served to every client (`Exercise.activity`, heart_models 1.8.0). It is read
/// rather than derived here, and the reason is worth keeping: the first cut of
/// this matched English exercise names, and `Exercise.name` is *localized copy*
/// — the library is keyed by exercise id with an `i18n` map per locale, so
/// every Russian user's cardio fell through. **Nothing in this file may key on
/// a name.**
///
/// What does live here is the session-level question, because only the caller
/// knows which exercises a workout contained: many exercises, one `HKWorkout`,
/// one label.
WorkoutActivity activityOf(Workout workout) {
  // Only what the user actually did. An exercise added and never worked is not
  // part of the session, and letting it choose the label would let an untouched
  // treadmill row rename a lifting workout.
  final activities = workout
      .where((exercise) => exercise.isStarted)
      .map((exercise) => exercise.exercise.activity.asWorkoutActivity)
      .toSet();

  return switch (activities) {
    // Nothing was completed. The caller does not write these at all, so this is
    // only reachable if that guard ever moves.
    Set(isEmpty: true) => .strength,
    Set(length: 1) => activities.first,
    // Lifting plus something else. Both stores have a name for exactly this,
    // and it is a better answer than picking whichever came first.
    _ when activities.any((each) => each.isStrength) => .crossTraining,
    // Several kinds of cardio and no lifting.
    _ => .mixedCardio,
  };
}

extension on HealthActivity {
  /// The library's vocabulary in the health package's terms.
  ///
  /// Two enums rather than one because `heart_health` deliberately depends on
  /// neither `heart_models` nor anything else — its `models.dart` is the
  /// vocabulary `heart_db` persists without dragging in a platform channel.
  /// The cost is this switch; it is exhaustive, so a value added to either side
  /// fails to compile rather than falling through to something wrong.
  ///
  /// [WorkoutActivity.crossTraining] and [WorkoutActivity.mixedCardio] have no
  /// counterpart on purpose: they describe a session, never an exercise, and
  /// [activityOf] is what derives them.
  WorkoutActivity get asWorkoutActivity {
    return switch (this) {
      .strength => .strength,
      .cycling => .cycling,
      .cyclingIndoor => .cyclingIndoor,
      .elliptical => .elliptical,
      .hiking => .hiking,
      .rowing => .rowing,
      .running => .running,
      .runningTreadmill => .runningTreadmill,
      .skating => .skating,
      .skiing => .skiing,
      .snowboarding => .snowboarding,
      .swimming => .swimming,
      .walking => .walking,
      .climbing => .climbing,
      .coreTraining => .coreTraining,
      .flexibility => .flexibility,
      .yoga => .yoga,
      .cardioDance => .cardioDance,
      .highIntensity => .highIntensity,
      .jumpRope => .jumpRope,
      .other => .other,
    };
  }
}
