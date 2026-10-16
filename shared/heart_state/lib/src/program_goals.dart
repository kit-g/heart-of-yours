import 'package:heart_models/heart_models.dart';

/// A goal a following program implies (#353): derived from its schedule or
/// one of its rules while it runs, shown labelled with the program, and never
/// written as a goal row behind the user's back. "Keep as a goal" is the one
/// way it becomes one, and then it is the user's.
///
/// [goal] carries a synthetic id (`program:…`) so it can be told apart and
/// keyed on screen; [kept] is the goal without it, ready to create.
final class ImpliedGoal {
  final Program program;
  final Goal goal;

  const new({required this.program, required this.goal});

  /// The goal as the user's own: no id, so creating it mints one.
  Goal get kept {
    return Goal(
      metric: goal.metric,
      exerciseId: goal.exerciseId,
      cadence: goal.cadence,
      stages: [
        for (final GoalStage(:target, :dueOn) in goal.stages) GoalStage(target: target, dueOn: dueOn),
      ],
    );
  }
}

/// Where a goal heads under a program (#353), from the slope its bases have
/// taken and how many of its sessions the user has kept to: "on track for
/// week 11". Skips move it, by slowing the slope they come from.
sealed class GoalForecast {
  const new();
}

/// The goal's current rung is already met.
final class ForecastReached extends GoalForecast {
  const new();
}

/// At this pace the goal lands in program week [week], within the program.
final class ForecastOnTrack extends GoalForecast {
  final int week;

  const new(this.week);
}

/// At this pace the goal lands in [week], after the program's last.
final class ForecastPastEnd extends GoalForecast {
  final int week;

  const new(this.week);
}

/// The bases have not moved, or nothing has been logged to move from.
final class ForecastTooEarly extends GoalForecast {
  const new();
}

/// A training max is set at about 90% of the one-rep max (#350), so a share
/// of a max reads back as an estimated one-rep max divided by it.
const _maxShare = .9;

/// The goals [program] implies, less any the user already holds: the same
/// target is never shown twice (#353).
///
/// - A weekly target (`perWeek`) is a weekly `workouts` goal.
/// - A rule that grows a weight, in a program with a length, is a milestone
///   at its end: the first base grown at the rule's nominal pace for every
///   week. A share of a max is an estimated one-rep max; the others a top
///   set's weight.
///
/// Health goals are never among them: a program grows lifts, not bodies.
List<ImpliedGoal> impliedGoals(
  Program program, {
  required Iterable<ProgramBase> bases,
  required Iterable<Goal> held,
}) {
  final id = program.id;
  if (id == null) return const [];
  final live = held.where((goal) => !goal.archived).toList();
  bool holds(GoalMetric metric, {String? exerciseId, GoalCadence? cadence}) {
    return live.any(
      (goal) => goal.metric == metric && goal.exerciseId == exerciseId && goal.cadence == cadence,
    );
  }

  final end = switch ((program.createdAt, program.weeks)) {
    (final DateTime start, final int weeks) => start.add(Duration(days: weeks * 7)),
    _ => null,
  };

  return [
    if (program.perWeek case final int perWeek when !holds(.workouts, cadence: .week))
      ImpliedGoal(
        program: program,
        goal: Goal(
          id: 'program:$id:workouts',
          metric: .workouts,
          cadence: .week,
          stages: [GoalStage(target: perWeek)],
        ),
      ),
    if (program.weeks case final int weeks)
      for (final MapEntry(key: exerciseId, value: rule) in program.rules.entries)
        if ((weeklyGain(rule), _metricOf(rule), _firstBase(bases, exerciseId))
            case (
              final num gain,
              final GoalMetric metric,
              final num first,
            )
            when !holds(metric, exerciseId: exerciseId))
          if (_target(rule, first + gain * weeks) case final num target when target > _target(rule, first)!)
            ImpliedGoal(
              program: program,
              goal: Goal(
                id: 'program:$id:$exerciseId',
                metric: metric,
                exerciseId: exerciseId,
                stages: [GoalStage(target: target, dueOn: end)],
              ),
            ),
  ];
}

/// How much [rule] grows its base in a week where every session is kept to,
/// on paper: a weight added each week; a rep range climbed first, so a step
/// every other week; a wave's step once per wave. Null for a rule that grows
/// no weight.
num? weeklyGain(GrowthRule rule) {
  return switch (rule) {
    AddWeight(:final step) => step,
    RangeThenWeight(:final step) => step / 2,
    ShareOfMax(:final step, :final waves) when waves.isNotEmpty => step / waves.length,
    _ => null,
  };
}

/// Where [goal] heads under [program] (#353), or null when the program has no
/// say in it: a goal with a cadence is never "reached by week N", and only a
/// weight its rules grow can be forecast.
///
/// [current] is the goal's reading, in its stored units; without one the
/// latest base stands in. The slope is what the bases did over the weeks they
/// span, which already carries every skipped session; before there is one,
/// it is the rule's nominal pace scaled by the share of planned sessions the
/// user kept to ([sessionsDone] against `perWeek` a week so far).
GoalForecast? forecastOf(
  Goal goal, {
  required num? current,
  required Program program,
  required ProgramPosition position,
  required Iterable<ProgramBase> bases,
  required int sessionsDone,
}) {
  if (goal.cadence != null) return null;
  final exerciseId = goal.exerciseId;
  final rule = program.rules[exerciseId];
  if (exerciseId == null || rule == null) return null;
  if (goal.metric != .topSetWeight && goal.metric != .estimatedOneRepMax) return null;
  final nominal = weeklyGain(rule);
  if (nominal == null) return null;

  final target = goal.currentStage?.target;
  if (target == null) return const ForecastReached();

  // a training max reads as the one-rep max it is a share of
  final scale = switch ((goal.metric, rule)) {
    (.estimatedOneRepMax, ShareOfMax()) => 1 / _maxShare,
    _ => 1,
  };
  final own = [
    for (final base in bases)
      if (base.exerciseId == exerciseId && base.slot == null) base,
  ]..sort((a, b) => a.at.compareTo(b.at));

  final reading =
      current ??
      switch (own.lastOrNull) {
        final ProgramBase base => base.value * scale,
        null => null,
      };
  if (reading == null) return const ForecastTooEarly();
  if (reading >= target) return const ForecastReached();

  final slope = switch (own) {
    [final first, ..., final last] when last.at.difference(first.at).inDays >= 7 =>
      (last.value - first.value) * scale / (last.at.difference(first.at).inDays / 7),
    _ => nominal * scale * _adherence(program, position, sessionsDone),
  };
  if (slope <= 0) return const ForecastTooEarly();

  // the step that reaches it lands at the end of a week: the current one is
  // the first of those counted
  final week = position.week - 1 + ((target - reading) / slope).ceil();
  return switch (program.weeks) {
    final int weeks when week > weeks => ForecastPastEnd(week),
    _ => ForecastOnTrack(week),
  };
}

/// The share of the sessions planned so far that were done: every full week
/// behind the current one, at `perWeek`. Whole before there is a week behind.
double _adherence(Program program, ProgramPosition position, int sessionsDone) {
  final planned = (program.perWeek ?? 0) * (position.week - 1);
  if (planned <= 0) return 1;
  return (sessionsDone / planned).clamp(0, 1).toDouble();
}

GoalMetric? _metricOf(GrowthRule rule) {
  return switch (rule) {
    ShareOfMax() => .estimatedOneRepMax,
    AddWeight() || RangeThenWeight() => .topSetWeight,
    _ => null,
  };
}

/// [base] as the goal's target: a share of a max as the one-rep max it
/// implies, and either way down to a whole number of the rule's steps.
num? _target(GrowthRule rule, num base) {
  final (value, step) = switch (rule) {
    ShareOfMax(:final step) => (base / _maxShare, step),
    AddWeight(:final step) || RangeThenWeight(:final step) => (base, step),
    _ => (null, null),
  };
  if (value == null || step == null || step <= 0) return null;
  return (value / step).floor() * step;
}

/// The exercise's first base in the program: where its growth is measured
/// from, so the implied target holds still while the program runs.
num? _firstBase(Iterable<ProgramBase> bases, String exerciseId) {
  final own = [
    for (final base in bases)
      if (base.exerciseId == exerciseId && base.slot == null) base,
  ];
  if (own.isEmpty) return null;
  return own.reduce((a, b) => b.at.isBefore(a.at) ? b : a).value;
}
