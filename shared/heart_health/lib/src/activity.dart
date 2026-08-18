part of '../models.dart';

/// What kind of session Heart writes back to the health store.
///
/// Heart's own vocabulary, for the same reason [HealthMetric] is: the
/// `health` package's `HealthWorkoutActivityType` stops at `device.dart`, and
/// the caller should not have to know that Apple calls indoor cycling
/// `BIKING` while Health Connect calls it `BIKING_STATIONARY`.
///
/// The values are the shape of Heart's own exercise library rather than a
/// transcription of either platform's list — a session is whatever the user
/// actually did, and Heart only logs so many things. Anything it cannot place
/// is [other], never a guess.
///
/// **Every value must resolve on both platforms.** The plugin throws
/// `HealthException` for an activity the platform does not know rather than
/// degrading, so a value that maps to nothing is a crash on finish, not a
/// vaguer label. `_activityType` in `device.dart` is where that promise is
/// kept, and several values exist only because the two stores disagree —
/// swimming, climbing and treadmill running are each one name here and two
/// names down there.
enum WorkoutActivity {
  /// Lifting. The default, and what most Heart sessions are.
  strength,

  /// Lifting *and* cardio in one session — a treadmill finisher after squats.
  /// Its own value because it is neither of the two, and both stores have a
  /// name for exactly that idea.
  crossTraining,

  /// Cardio of more than one kind, with no lifting.
  mixedCardio,

  cycling,

  /// Stationary. Apple does not distinguish it; Health Connect does.
  cyclingIndoor,
  elliptical,
  hiking,
  rowing,
  running,

  /// Apple does not distinguish it; Health Connect does.
  runningTreadmill,
  skating,
  skiing,
  snowboarding,
  swimming,
  walking,
  climbing,

  /// Planks and the like.
  coreTraining,

  /// Stretching.
  flexibility,
  yoga,

  /// Aerobics.
  cardioDance,

  /// Circuit work with no better name — battle ropes.
  highIntensity,

  /// Skipping. One of the few where Apple has a name and Health Connect does
  /// not — see `_activityType`.
  jumpRope,

  /// Heart cannot place it. A custom exercise, most often.
  ///
  /// Deliberately not folded into [strength]: a session labelled as lifting
  /// that was not is a worse answer than one the store shows as unclassified,
  /// and the user sees this label in the Health app.
  other;

  /// Whether this is lifting rather than cardio — the split that decides
  /// whether a mixed session is [crossTraining].
  bool get isStrength => this == strength;
}
