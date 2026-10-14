import 'package:heart_models/heart_models.dart';

/// What one finished program workout did to one of its exercises (#350): the
/// step heart_models' `Progression` took, the base it took it from, and what
/// was written for it, which "Keep" takes back (#351).
///
/// A [Hold] is never one of these: nothing moved and nothing counts. A
/// [Missed] is, though it writes nothing — the streak it reports is how close
/// the next one comes to a cut, and a move is never silent.
final class GrowthMove {
  final String exerciseId;

  /// The template exercise the base belongs to, when the program keeps one
  /// per occurrence of a lift used twice; null for the exercise's own.
  final String? slot;

  /// The base the step was taken from; null before the first, and for a
  /// ladder, which keeps none.
  final num? before;

  final ProgressionStep step;

  /// A test session's training max (`Program.tests`): [step] is the [Grow]
  /// to the base it set, judged against no rule.
  final bool isTest;

  /// How many misses in a row make a cut, for a [Missed]: "1 of 3".
  final int? cutAfter;

  /// The base written for a [Grow], a [Cut] or a test; deleting it is "Keep".
  final ProgramBase? base;

  /// The advance written for an [Advance]; undoing it is "Keep".
  final ProgramAction? action;

  const new({
    required this.exerciseId,
    required this.step,
    this.slot,
    this.before,
    this.isTest = false,
    this.cutAfter,
    this.base,
    this.action,
  });

  GrowthMove written({ProgramBase? base, ProgramAction? action}) {
    return GrowthMove(
      exerciseId: exerciseId,
      step: step,
      slot: slot,
      before: before,
      isTest: isTest,
      cutAfter: cutAfter,
      base: base,
      action: action,
    );
  }
}

/// A program session as run: the program's workouts before it, each with
/// whether it fell in a lighter cycle, which neither misses nor breaks a
/// streak.
typedef EarlierSession = ({Workout workout, bool lighter});

/// The steps [workout] takes in [program] (#350), computed and not yet
/// written: one per exercise the program has a rule for, or per occurrence
/// of a lift whose program keeps a base per slot; a base per exercise of a
/// test session instead.
///
/// [bases] are the program's current ones, before [workout]. [earlier] are
/// the program's workouts before it, oldest first. [before] is the position
/// the workout was done in, and [closesCycle] whether it completed that
/// week's cycle. [session] is the template it was started from, which names
/// the occurrences a slotted base is kept for.
///
/// Pure: offline and signed out alike, what the device writes is what this
/// returns.
List<GrowthMove> growthOf(
  Program program,
  Workout workout, {
  required Map<String, ProgramBase> bases,
  required List<EarlierSession> earlier,
  required ProgramPosition before,
  required bool closesCycle,
  Template? session,
}) {
  final groups = _groups(workout, session: session, bases: bases);

  if (program.tests[workout.templateId] case final ProgramTest test) {
    return [
      for (final group in groups)
        if (Progression.test(group.sets, share: test.share, step: _stepOf(program.rules[group.exerciseId]))
            case final num value)
          GrowthMove(
            exerciseId: group.exerciseId,
            slot: group.slot,
            before: bases[group.key]?.value,
            step: Grow(value),
            isTest: true,
          ),
    ];
  }

  final moves = <GrowthMove>[];
  for (final group in groups) {
    final rule = program.rules[group.exerciseId];
    if (rule == null) continue;
    final base = bases[group.key];

    // the streak runs since the base last changed: a session before it was
    // judged against another base
    final since = [
      for (final each in earlier)
        if (base == null || each.workout.start.isAfter(base.at)) each,
    ];
    final misses = Progression.streak(
      rule,
      [for (final each in since) _setsOf(each.workout, group, session: session)],
      lighter: [for (final each in since) each.lighter],
    );

    final step = Progression.next(
      rule: rule,
      base: base?.value,
      sets: group.sets,
      misses: misses,
      lighter: before.lighter,
      week: before.week,
      closesCycle: closesCycle,
    );
    if (step is Hold) continue;
    moves.add(
      GrowthMove(
        exerciseId: group.exerciseId,
        slot: group.slot,
        before: base?.value,
        step: step,
        cutAfter: rule.miss?.after,
      ),
    );
  }
  return moves;
}

/// The step a test's training max is rounded down to: its rule's, or 2.5.
num _stepOf(GrowthRule? rule) {
  return switch (rule) {
    AddWeight(:final step) || RangeThenWeight(:final step) || ShareOfMax(:final step) => step,
    _ => 2.5,
  };
}

/// One exercise of a workout as a rule judges it: every occurrence's sets
/// together, or one occurrence's when the program keeps a base for it.
typedef _Group = ({String exerciseId, String? slot, List<ExerciseSet> sets});

extension on _Group {
  /// What [currentBases] keys its base by.
  String get key => slot ?? exerciseId;
}

List<_Group> _groups(Workout workout, {Template? session, required Map<String, ProgramBase> bases}) {
  final groups = <String, _Group>{};
  for (final (exercise, slot) in _occurrences(workout, session)) {
    final id = exercise.exercise.id;
    final own = switch (slot) {
      final String slot when bases.containsKey(slot) => slot,
      _ => null,
    };
    final key = own ?? id;
    final held = groups[key];
    groups[key] = (exerciseId: id, slot: own, sets: [...?held?.sets, ...exercise]);
  }
  return groups.values.toList();
}

/// Each of [workout]'s exercises with the template exercise it was started
/// from: the nth occurrence of a lift in the workout is the nth in [session].
/// A workout keeps no link to its template's exercises, and a lift used
/// twice in one session is the only case a slot tells apart.
Iterable<(WorkoutExercise, String?)> _occurrences(Workout workout, Template? session) sync* {
  final seen = <String, int>{};
  for (final exercise in workout) {
    final id = exercise.exercise.id;
    final nth = seen[id] = (seen[id] ?? -1) + 1;
    final slots = [
      for (final each in session ?? const <WorkoutExercise>[])
        if (each.exercise.id == id) each.id,
    ];
    yield (exercise, nth < slots.length ? slots[nth] : null);
  }
}

/// [group]'s exercise as an earlier [workout] did it: the same occurrence of
/// the same session for a slotted base, else every occurrence.
List<ExerciseSet> _setsOf(Workout workout, _Group group, {Template? session}) {
  final slot = group.slot;
  if (slot == null) {
    return [
      for (final exercise in workout)
        if (exercise.exercise.id == group.exerciseId) ...exercise,
    ];
  }
  if (workout.templateId != session?.id) return const [];
  return [
    for (final (exercise, each) in _occurrences(workout, session))
      if (each == slot) ...exercise,
  ];
}
