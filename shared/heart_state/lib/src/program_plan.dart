import 'package:heart_models/heart_models.dart';

/// Rounds [kilograms] of [exercise] to a weight the user can load: the step
/// their unit counts in. The caller knows the unit; this library does not.
typedef RoundWeight = num Function(Exercise exercise, num kilograms);

/// [session] as the workout it starts (#349): [PlannedSession.of]'s reading
/// of it, the one the developer API and MCP show too, laid onto the sets
/// [Template.toWorkout] makes. A worked-out weight, duration or distance is a
/// target the cells show and a tick takes, rounded to the user's plates; it
/// is never a logged value. A stages rule lays out its stage's sets, and a
/// lighter cycle keeps its share of the working sets.
Workout planSession(
  Template session, {
  required Program program,
  required ProgramPosition position,
  required Map<String, ProgramBase> bases,
  Map<String, int> stages = const {},
  required RoundWeight round,
}) {
  final workout = session.toWorkout();
  final planned = PlannedSession.of(program, session, position: position, bases: bases, stages: stages);
  final bySlot = {for (final exercise in planned.exercises) exercise.slot: exercise};

  // toWorkout skips an exercise without sets, so the two line up once the
  // template's empty ones are out of the way
  final slots = session.where((exercise) => exercise.isNotEmpty);
  for (final (slot, exercise) in _zip(slots, workout)) {
    if (bySlot[slot.id] case final PlannedExercise plan) _lay(exercise, plan, round);
  }
  return workout;
}

/// Replaces [exercise]'s sets with [plan]'s, in its order: warm-ups as they
/// were, working sets from the ones written, and a stage's extra sets as
/// copies of the first.
void _lay(WorkoutExercise exercise, PlannedExercise plan, RoundWeight round) {
  final warmups = exercise.where((set) => set.setType == .warmup).iterator;
  final working = exercise.where((set) => set.setType != .warmup).toList();
  final sets = <ExerciseSet>[];
  var next = 0;
  for (final planned in plan.sets) {
    final set = switch (planned.setType) {
      .warmup when warmups.moveNext() => warmups.current,
      _ when next < working.length => working[next++],
      _ when working.isNotEmpty => working.first.copy(),
      _ => null,
    };
    if (set == null) continue;
    sets.add(_planned(set, planned, round));
  }
  for (final set in exercise.toList()) {
    exercise.remove(set);
  }
  sets.forEach(exercise.add);
}

/// [set] with [planned]'s target, and what the plan worked out as targets of
/// their own in place of what the template stored.
ExerciseSet _planned(ExerciseSet set, PlannedSet planned, RoundWeight round) {
  var target = planned.target;
  if (planned.weight case final num weight when weight != set.weight) {
    target = (target ?? SetTarget.none).withRange(.weight, .exactly(round(set.exercise, weight)));
  }
  if (planned.duration case final num duration when duration != set.duration) {
    target = (target ?? SetTarget.none).withRange(.duration, .exactly(duration));
  }
  if (planned.distance case final num distance when distance != set.distance) {
    target = (target ?? SetTarget.none).withRange(.distance, .exactly(distance));
  }
  set.target = target;
  // a target the plan worked out replaces the value it stood in for
  set.setMeasurements(
    weight: switch (target?[.weight]) {
      TargetRange() => null,
      null => set.weight,
    },
    reps: switch (target?[.reps]) {
      TargetRange() => null,
      null => planned.reps?.toInt() ?? set.reps,
    },
    duration: switch (target?[.duration]) {
      TargetRange() => null,
      null => set.duration,
    },
    distance: switch (target?[.distance]) {
      TargetRange() => null,
      null => set.distance,
    },
  );
  return set;
}

Iterable<(A, B)> _zip<A, B>(Iterable<A> a, Iterable<B> b) sync* {
  final left = a.iterator;
  final right = b.iterator;
  while (left.moveNext() && right.moveNext()) {
    yield (left.current, right.current);
  }
}
