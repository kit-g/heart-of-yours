import 'dart:math';

import 'package:heart/core/utils/goals.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// What a goal read before one workout (#625): everything its value is made
/// of except that workout, which [goalValue] folds back in. Read by
/// [readGoalPrior]; never a health value — no goal is measured by one.
///
/// [window] is the stretch the goal is measured over, [from, to): its period,
/// or all time for a milestone. The workout counts toward it when it started
/// inside.
sealed class GoalPrior {
  final (DateTime, DateTime) window;

  const new(this.window);

  bool covers(DateTime at) {
    final (from, to) = window;
    return !at.isBefore(from) && at.isBefore(to);
  }
}

/// A whole-workout goal's: the finished workouts in the window.
final class WorkoutsPrior extends GoalPrior {
  final int count;

  const new(super.window, this.count);
}

/// A per-exercise goal's: each other session's value of the goal's chart
/// metric, one per session in the window.
final class SessionsPrior extends GoalPrior {
  final List<num> values;

  const new(super.window, this.values);
}

/// A sets or sessions goal's: the pattern lens's rows in the window.
final class LensPrior extends GoalPrior {
  final List<LensSets> rows;

  const new(super.window, this.rows);
}

/// [goal]'s value from [prior], with [today]'s ticked sets folded in when
/// there is one: the one calculation the workout summary's goal list and the
/// live goal note both make (#625), so a workout never says something its
/// summary will not.
///
/// Folds the way [currentGoalValue] reads the store: a milestone is its best
/// session, a recurring goal its period's sessions folded the way the metric
/// folds ([ChartPreferenceType.periodAggregate]), a sets or sessions goal the
/// lens's count, a workouts goal a count of workouts. Null where there is
/// nothing to read yet.
num? goalValue(Goal goal, GoalPrior prior, {Workout? today}) {
  final counted = switch (today) {
    final Workout workout when prior.covers(workout.start) => workout,
    _ => null,
  };
  return switch (prior) {
    WorkoutsPrior(:final count) => count + ((counted?.any(_ticked) ?? false) ? 1 : 0),
    LensPrior(:final rows) => subjectCount(goal, [
      ...rows,
      if (counted case final Workout workout) ..._lensSetsOf(workout),
    ]),
    SessionsPrior(:final values) => switch (goal.metric.chart) {
      final ChartPreferenceType metric => _fold(goal, metric, [
        ...values,
        if (counted case final Workout workout) ?_sessionValue(metric, _workingSets(workout, goal.exerciseId)),
      ]),
      null => null,
    },
  };
}

/// The rungs [workout] carries over the line (#625): met with its ticked
/// sets, and not without them. What a set just reached, while the workout is
/// going; what the session earned, on its summary.
///
/// [priorOf] answers each goal's [GoalPrior], or null for one not read (or
/// not measurable): such a goal crosses nothing. A recurring goal crosses
/// once a period — a later session in a week already won was not what won it.
List<GoalAchievement> goalCrossings(
  Iterable<Goal> goals,
  GoalPrior? Function(Goal goal) priorOf,
  Workout workout,
) {
  return [
    for (final goal in goals)
      if (priorOf(goal) case final GoalPrior prior)
        if (goalValue(goal, prior, today: workout) case final num now)
          for (final stage in goal.stages)
            if (stage.isMetBy(now, goal.metric))
              if (goalValue(goal, prior) case final before when before == null || !stage.isMetBy(before, goal.metric))
                (goal: goal, stage: stage),
  ];
}

/// Whether [crossing] is its goal's last rung — the hardest target on the
/// ladder, and a recurring goal's only one — rather than one on the way.
bool isFinalRung(GoalAchievement crossing) {
  final (:goal, :stage) = crossing;
  return stage.target == goal.stages.map((each) => each.target).reduce(goal.metric.lowerIsBetter ? min : max);
}

/// Which goal and which rung a crossing is, for telling a new one from one
/// already seen.
typedef GoalCrossingKey = (String?, String?, num);

GoalCrossingKey crossingKey(GoalAchievement crossing) {
  final (:goal, :stage) = crossing;
  return (goal.id, stage.id, stage.target);
}

/// [workout]'s ticked working sets as the pattern lens reads a finished
/// workout's: one row per exercise entry that has any.
List<LensSets> _lensSetsOf(Workout workout) {
  return [
    for (final entry in workout)
      if (entry.where(_working).length case final int sets when sets > 0)
        (
          workoutId: workout.id,
          exerciseId: entry.exercise.id,
          start: workout.start,
          movement: entry.exercise.movement,
          muscles: entry.exercise.muscles,
          target: entry.exercise.target,
          sets: sets,
        ),
  ];
}

bool _ticked(WorkoutExercise entry) => entry.any((set) => set.isCompleted);

/// Completed and not a warm-up: what every chart, record and lens counts.
bool _working(ExerciseSet set) => set.isCompleted && set.setType != .warmup;

List<ExerciseSet> _workingSets(Workout workout, String? exerciseId) {
  return [
    for (final entry in workout)
      if (entry.exercise.id == exerciseId) ...entry.where(_working),
  ];
}

num? _fold(Goal goal, ChartPreferenceType metric, List<num> values) {
  final lower = goal.metric.lowerIsBetter;
  // as [currentGoalValue]: a milestone is its best session; an empty period
  // is nothing yet, except for pace, where nought would read as met
  if (goal.cadence == null) return values.isEmpty ? null : values.reduce(lower ? min<num> : max<num>);
  if (values.isEmpty) return lower ? null : 0;
  return metric.periodAggregate.of(values);
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
