import 'dart:math';

import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// What a goal read before one workout (#625): everything its value is made
/// of except that workout, which [goalCrossings] folds back in. Read by
/// [readGoalPrior] over the goal's window as of the workout's start; never a
/// health value — no goal is measured by one.
sealed class GoalPrior {
  const new();

  /// The goal's value without the workout: worked out once, as it is read,
  /// rather than on every tick.
  num? get before;
}

/// A whole-workout goal's: the other finished workouts in its window.
final class WorkoutsPrior extends GoalPrior {
  final int count;

  const new(this.count);

  @override
  num get before => count;
}

/// A per-exercise goal's: each other session's value of the goal's chart
/// metric, one per session in its window.
final class SessionsPrior extends GoalPrior {
  final List<num> values;

  @override
  final num? before;

  const new _(this.values, this.before);

  factory of(Goal goal, List<num> values) => SessionsPrior._(values, _fold(goal, values));
}

/// A sets or sessions goal's: what the other workouts in its window counted
/// toward its subject. Sets add up, and so do sessions, since the workout is
/// never among them.
final class LensPrior extends GoalPrior {
  final num count;

  const new(this.count);

  @override
  num get before => count;
}

/// How a workout's sets are read into a goal (#625), as the store reads a
/// finished one: each exercise as the catalogue tags it — a workout's own
/// copy may carry no movement or muscles at all — and the sets the user
/// discarded (#428) left out.
typedef GoalFold = ({Exercise Function(Exercise embedded) exerciseOf, Set<String> leftOut});

/// The rungs [workout] carries over the line (#625): met with its ticked
/// sets, and not without them. What a set just reached, while the workout is
/// going; what the session earned, on its summary — the one calculation both
/// make, so a workout never says something its summary will not.
///
/// [priorOf] answers each goal's [GoalPrior], or null for one not read (or
/// not measurable): such a goal crosses nothing. A rung already stamped, and
/// a goal already complete, cross nothing either: whatever the history in
/// hand says, they were reached before. A recurring goal crosses once a
/// period — a later session in a week already won was not what won it.
List<GoalAchievement> goalCrossings(
  Iterable<Goal> goals,
  GoalPrior? Function(Goal goal) priorOf,
  Workout workout, {
  required GoalFold fold,
}) {
  return [
    for (final goal in goals)
      if (!goal.isComplete)
        if (priorOf(goal) case final GoalPrior prior)
          if (_value(goal, prior, workout, fold) case final num now)
            for (final stage in goal.stages)
              if (!stage.isAchieved && stage.isMetBy(now, goal.metric))
                if (prior.before case final before when before == null || !stage.isMetBy(before, goal.metric))
                  (goal: goal, stage: stage),
  ];
}

/// Whether [crossing] is its goal's last rung — the hardest target on the
/// ladder, and a recurring goal's only one — rather than one on the way.
bool isFinalRung(GoalAchievement crossing) {
  final (:goal, :stage) = crossing;
  return stage.target == goal.stages.map((each) => each.target).reduce(goal.metric.lowerIsBetter ? min : max);
}

/// Which goal and which rung a crossing is: the goal and the rung's place on
/// its ladder, which neither a sync reassigning stage ids nor a retarget
/// moves.
typedef GoalCrossingKey = (String?, int);

GoalCrossingKey crossingKey(GoalAchievement crossing) {
  final (:goal, :stage) = crossing;
  return (goal.id, goal.stages.indexOf(stage));
}

/// [goal]'s value from [prior] with [workout]'s ticked sets folded in.
///
/// Folds the way [currentGoalValue] reads the store: a milestone is its best
/// session, a recurring goal its period's sessions folded the way the metric
/// folds ([ChartPreferenceType.periodAggregate]), a sets or sessions goal the
/// lens's count, a workouts goal a count of workouts. Null where there is
/// nothing to read yet.
num? _value(Goal goal, GoalPrior prior, Workout workout, GoalFold fold) {
  bool working(ExerciseSet set) => isWorkingSet(set) && !fold.leftOut.contains(set.id);
  return switch (prior) {
    WorkoutsPrior(:final count) => count + (workout.any((entry) => entry.any((set) => set.isCompleted)) ? 1 : 0),
    LensPrior(:final count) => count + (subjectCount(goal, _lensSetsOf(workout, working, fold)) ?? 0),
    SessionsPrior(:final values) => _fold(goal, [
      ...values,
      if (goal.metric.chart case final ChartPreferenceType metric)
        ?_sessionValue(metric, [
          for (final entry in workout)
            if (entry.exercise.id == goal.exerciseId) ...entry.where(working),
        ]),
    ]),
  };
}

/// [workout]'s [working] sets as the pattern lens reads a finished workout's:
/// one row per exercise entry that has any, tagged as the catalogue tags it.
List<LensSets> _lensSetsOf(Workout workout, bool Function(ExerciseSet set) working, GoalFold fold) {
  return [
    for (final entry in workout)
      if (entry.where(working).length case final int sets when sets > 0)
        if (fold.exerciseOf(entry.exercise) case final exercise)
          (
            workoutId: workout.id,
            exerciseId: exercise.id,
            start: workout.start,
            movement: exercise.movement,
            muscles: exercise.muscles,
            target: exercise.target,
            sets: sets,
          ),
  ];
}

num? _fold(Goal goal, List<num> values) {
  final lower = goal.metric.lowerIsBetter;
  // as [currentGoalValue]: a milestone is its best session; an empty period
  // is nothing yet, except for pace, where nought would read as met
  if (goal.cadence == null) return values.isEmpty ? null : values.reduce(lower ? min<num> : max<num>);
  if (values.isEmpty) return lower ? null : 0;
  return goal.metric.chart?.periodAggregate.of(values);
}

/// One session's value of [metric] over [sets] — its working sets of one
/// exercise — or null where the store has no row for the session. The
/// in-memory twin of `heart_db`'s `metrics.dart`, statement for statement: a
/// change to one is a change to both.
num? _sessionValue(ChartPreferenceType metric, List<ExerciseSet> sets) {
  if (sets.isEmpty) return null;
  num sum(num? Function(ExerciseSet set) of, [Iterable<ExerciseSet>? only]) {
    return (only ?? sets).fold<num>(0, (total, set) => total + (of(set) ?? 0));
  }

  num weight(ExerciseSet set) => set.weight ?? 0;

  switch (metric) {
    case .topSetWeight:
      return sets.map(weight).reduce(max<num>);
    case .assistanceWeight:
      return sets.map(weight).reduce(min<num>);
    case .maxConsecutiveReps:
      final reps = sets.map((set) => set.reps).nonNulls;
      return reps.isEmpty ? null : reps.reduce(max);
    case .totalReps:
      return sum((set) => set.reps);
    case .totalVolume:
      return sum((set) => weight(set) * (set.reps ?? 0));
    case .averageWorkingWeight:
      final counted = sets.where((set) => (set.reps ?? 0) > 0);
      if (counted.isEmpty) return null;
      return sum((set) => weight(set) * set.reps!, counted) / sum((set) => set.reps, counted);
    case .estimatedOneRepMax:
      final counted = sets.where((set) => (set.reps ?? 0) > 0 && (set.weight ?? 0) > 0);
      if (counted.isEmpty) return null;
      // Brzycki, as the query has it
      return counted.map((set) => set.weight! / (1.0278 - (0.0278 * set.reps!))).reduce(max);
    case .cardioDistance:
      return sum((set) => set.distance);
    case .cardioDuration || .totalTimeUnderTension:
      return sum((set) => set.duration);
    case .averagePace:
      final distance = sum((set) => set.distance);
      if (distance <= 0) return null;
      return sum((set) => set.duration) / distance;
  }
}
