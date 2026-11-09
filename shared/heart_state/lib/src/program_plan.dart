import 'package:heart_models/heart_models.dart';

/// Rounds [kilograms] of [exercise] to a weight the user can load: the step
/// their unit counts in. The caller knows the unit; this library does not.
typedef RoundWeight = num Function(Exercise exercise, num kilograms);

/// A workout about to start, and what it was asked to be when it is a
/// program's session: null otherwise.
typedef PlannedWorkout = ({Workout workout, WorkoutPlan? plan});

/// [session] as the workout it starts (#349): [PlannedSession.of]'s reading
/// of it, the one the developer API and MCP show too, laid onto the sets
/// [Template.toWorkout] makes. A worked-out weight, duration or distance is a
/// target the cells show and a tick takes, rounded to the user's plates; it
/// is never a logged value. A stages rule lays out its stage's sets, and a
/// lighter cycle keeps its share of the working sets.
///
/// With it comes the plan (#566, #558): that same reading, each planned set
/// naming the set it became (`setId`) and its weight as the user was shown it,
/// on their plates. A coach compares the workout with it, and it can't be
/// worked out again later, since bases, waves and lighter weeks move on.
PlannedWorkout planSession(
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
  final laid = <String, List<_Laid?>>{};

  // toWorkout skips an exercise without sets, so the two line up once the
  // template's empty ones are out of the way
  final slots = session.where((exercise) => exercise.isNotEmpty);
  for (final (slot, exercise) in _zip(slots, workout)) {
    if (bySlot[slot.id] case final PlannedExercise plan) laid[plan.slot] = _lay(exercise, plan, round);
  }
  return (workout: workout, plan: WorkoutPlan(_planOf(planned, laid)));
}

/// What became of one planned set: the set it is, and the weight it shows.
typedef _Laid = ({String setId, num? weight});

/// [planned] as the server keeps it, each set with what [laid] says it became.
Map<String, dynamic> _planOf(PlannedSession planned, Map<String, List<_Laid?>> laid) {
  final plan = planned.toMap();
  plan['exercises'] = [
    for (final (exercise, json) in _zip(planned.exercises, (plan['exercises'] as List).cast<Map<String, dynamic>>()))
      {
        ...json,
        'sets': [
          for (final (index, set) in (json['sets'] as List).cast<Map<String, dynamic>>().indexed)
            switch (laid[exercise.slot]?.elementAtOrNull(index)) {
              final _Laid laid => {...set, 'setId': laid.setId, 'weight': ?laid.weight ?? set['weight']},
              null => set,
            },
        ],
      },
  ];
  return plan;
}

/// Replaces [exercise]'s sets with [plan]'s, in its order: warm-ups as they
/// were, working sets from the ones written, and a stage's extra sets as
/// copies of the first. Returns what each planned set became, in [plan]'s
/// order: null for one there was no set to lay it on.
List<_Laid?> _lay(WorkoutExercise exercise, PlannedExercise plan, RoundWeight round) {
  final warmups = exercise.where((set) => set.setType == .warmup).iterator;
  final working = exercise.where((set) => set.setType != .warmup).toList();
  final sets = <ExerciseSet>[];
  final laid = <_Laid?>[];
  var next = 0;
  for (final planned in plan.sets) {
    final set = switch (planned.setType) {
      .warmup when warmups.moveNext() => warmups.current,
      _ when next < working.length => working[next++],
      _ when working.isNotEmpty => working.first.copy(),
      _ => null,
    };
    if (set == null) {
      laid.add(null);
      continue;
    }
    final placed = _planned(set, planned, round);
    sets.add(placed);
    laid.add((setId: placed.id, weight: _shownWeight(placed)));
  }
  for (final set in exercise.toList()) {
    exercise.remove(set);
  }
  sets.forEach(exercise.add);
  return laid;
}

/// The weight [set] shows: the one its target asks for, on the user's plates,
/// else the one it holds.
num? _shownWeight(ExerciseSet set) {
  return switch (set.target?[.weight]) {
    TargetRange(:final min) => min,
    _ => set.weight,
  };
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
