import 'package:heart_models/heart_models.dart';

/// Rounds [kilograms] of [exercise] to a weight the user can load: the step
/// their unit counts in. The caller knows the unit; this library does not.
typedef RoundWeight = num Function(Exercise exercise, num kilograms);

/// [session] as the workout it starts (#349): its targets as the program has
/// them this time. A share of a base becomes a weight, of the base this
/// occurrence keeps (its slot: the template exercise's id), of the exercise's
/// own, or of the one the target names (`of`); without a base it stays a
/// share, and the cells take the rest of the target. In a [lighter] cycle the
/// weights come down by [Program.deload]'s load and each exercise drops to
/// its volume share of working sets, the supplemental ones first.
///
/// What it starts is the same as [Template.toWorkout]'s otherwise: the plan
/// is the targets, never a logged value.
Workout planSession(
  Template session, {
  required Program program,
  required Map<String, ProgramBase> bases,
  required bool lighter,
  required RoundWeight round,
}) {
  final workout = session.toWorkout();
  final load = switch (lighter) {
    true => program.deload?.load ?? Deload.defaultLoad,
    false => 1,
  };
  final volume = switch (lighter) {
    true => program.deload?.volume ?? Deload.defaultVolume,
    false => 1,
  };

  // toWorkout skips an exercise without sets, so the two line up once the
  // template's empty ones are out of the way
  final slots = session.where((exercise) => exercise.isNotEmpty);
  for (final (slot, exercise) in _zip(slots, workout)) {
    for (final set in exercise) {
      _planSet(set, slot: slot.id, bases: bases, load: load, round: round);
    }
    if (lighter) _lighten(exercise, volume);
  }
  return workout;
}

void _planSet(
  ExerciseSet set, {
  required String slot,
  required Map<String, ProgramBase> bases,
  required num load,
  required RoundWeight round,
}) {
  final target = set.target;
  num scaled(num kilograms) => round(set.exercise, kilograms * load);

  final base = switch (target) {
    SetTarget(share: num _, of: final String of) => bases[of],
    SetTarget(share: num _) => bases[slot] ?? bases[set.exercise.id],
    _ => null,
  };
  switch ((target, base)) {
    case (final SetTarget target, final ProgramBase base):
      set.target = target.withRange(.weight, .exactly(scaled(target.share! * base.value)));
    case (final SetTarget target, null) when load != 1:
      if (target[.weight] case final TargetRange range) {
        set.target = target.withRange(
          .weight,
          TargetRange(
            min: scaled(range.min),
            max: switch (range.max) {
              final num max => scaled(max),
              null => null,
            },
            amrap: range.amrap,
          ),
        );
      }
    default:
  }
  if ((set.weight, load != 1) case (final double weight, true)) {
    set.setMeasurements(
      weight: scaled(weight).toDouble(),
      reps: set.reps,
      duration: set.duration,
      distance: set.distance,
    );
  }
}

/// Keeps [volume]'s share of [exercise]'s working sets, at least one: the
/// supplemental ones go first, then the last of the rest. Warm-ups stay.
void _lighten(WorkoutExercise exercise, num volume) {
  final working = exercise.where((set) => set.setType != .warmup).toList();
  final keep = switch ((working.length * volume).round()) {
    < 1 => 1,
    final count => count,
  };
  final dropped = [
    ...working.reversed.where((set) => set.target?.supplemental ?? false),
    ...working.reversed.where((set) => !(set.target?.supplemental ?? false)),
  ].take(working.length - keep);
  for (final set in dropped.toList()) {
    exercise.remove(set);
  }
}

Iterable<(A, B)> _zip<A, B>(Iterable<A> a, Iterable<B> b) sync* {
  final left = a.iterator;
  final right = b.iterator;
  while (left.moveNext() && right.moveNext()) {
    yield (left.current, right.current);
  }
}
