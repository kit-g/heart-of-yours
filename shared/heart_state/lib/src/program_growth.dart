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

  /// The advance written for an [Advance], or the stage step for a
  /// [ToStage]; undoing it is "Keep".
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
/// [bases] are the program's current ones, before [workout], and [actions]
/// its steps so far, which say what stage a stages rule is on. [earlier] are
/// the program's workouts before it, oldest first. [before] is the position
/// the workout was done in, and [closesCycle] whether it completed that
/// week's cycle. [session] is the template it was started from, which names
/// the occurrences a slotted base is kept for, and [slots] which of them each
/// of [workout]'s exercises was ([slotsOf], read before the finish dropped
/// any); without them, the nth occurrence is the nth.
///
/// Pure: offline and signed out alike, what the device writes is what this
/// returns.
List<GrowthMove> growthOf(
  Program program,
  Workout workout, {
  required Map<String, ProgramBase> bases,
  Iterable<ProgramAction> actions = const [],
  required List<EarlierSession> earlier,
  required ProgramPosition before,
  required bool closesCycle,
  Template? session,
  Map<String, String>? slots,
}) {
  final groups = _groups(program, workout, session: session, bases: bases, slots: slots);
  final stages = currentStages(actions);
  final moved = _stageMoves(actions);

  if (program.tests[workout.templateId] case final ProgramTest test) {
    return [
      for (final group in groups)
        if (Progression.test(
              group.sets,
              share: test.share,
              step: _stepOf(program.ruleFor(group.exerciseId, slot: group.slot)),
            )
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
    final rule = program.ruleFor(group.exerciseId, slot: group.slot);
    if (rule == null) continue;
    final base = program.atSlot(bases, group.exerciseId, slot: group.slot);
    final stage = program.atSlot(stages, group.exerciseId, slot: group.slot) ?? 0;

    // the streak runs since the base last changed, or a stages rule last
    // moved: a session before either was judged against something else
    // a session whose occurrences can't be told apart any more says nothing
    final from = [?base?.at, ?program.atSlot(moved, group.exerciseId, slot: group.slot)].fold<DateTime?>(
      null,
      (latest, at) => latest == null || at.isAfter(latest) ? at : latest,
    );
    final since = [
      for (final each in earlier)
        if (from == null || each.workout.start.isAfter(from))
          if (_setsOf(each.workout, group, session: session) case final List<ExerciseSet> sets)
            (sets: sets, lighter: each.lighter),
    ];
    final misses = Progression.streak(
      rule,
      [for (final each in since) each.sets],
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
      stage: stage,
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
    AddWeight(:final step) || RangeThenWeight(:final step) || ShareOfMax(:final step) || Stages(:final step) => step,
    _ => 2.5,
  };
}

/// When each stages rule last moved, keyed like [currentStages].
Map<String, DateTime> _stageMoves(Iterable<ProgramAction> actions) {
  final moved = <String, DateTime>{};
  for (final action in actions) {
    if (action case ProgramAction(kind: .stage, :final exercise?, :final at)) {
      final key = action.slot ?? exercise;
      if (moved[key] case final DateTime held when held.isAfter(at)) continue;
      moved[key] = at;
    }
  }
  return moved;
}

/// One exercise of a workout as a rule judges it: every occurrence's sets
/// together, or one occurrence's when the program keeps a base or a rule
/// for it.
typedef _Group = ({String exerciseId, String? slot, List<ExerciseSet> sets});

extension on _Group {
  /// What [currentBases] keys its base by.
  String get key => slot ?? exerciseId;
}

List<_Group> _groups(
  Program program,
  Workout workout, {
  Template? session,
  required Map<String, ProgramBase> bases,
  Map<String, String>? slots,
}) {
  final groups = <String, _Group>{};
  for (final (exercise, slot) in _occurrences(workout, session, slots: slots)) {
    final id = exercise.exercise.id;
    // an occurrence with a base or a rule of its own is judged on its own
    final own = switch (slot) {
      final String slot when bases.containsKey(slot) || program.rules.containsKey(slot) => slot,
      _ => null,
    };
    final key = own ?? id;
    final held = groups[key];
    groups[key] = (exerciseId: id, slot: own, sets: [...?held?.sets, ...exercise]);
  }
  return groups.values.toList();
}

/// Each of [workout]'s exercises by id, with the template exercise it was
/// started from: the nth occurrence of a lift in the workout is the nth in
/// [session]. Read while the workout still holds every exercise it started
/// with — the finish drops the ones nobody ticked, and after that a skipped
/// first occurrence would hand the second's sets to the first's slot.
Map<String, String> slotsOf(Workout workout, Template? session) {
  return {
    for (final (exercise, slot) in _occurrences(workout, session)) exercise.id: ?slot,
  };
}

/// Each of [workout]'s exercises with the template exercise it was started
/// from: [slots]' answer when given, else the nth occurrence of a lift in the
/// workout is the nth in [session]. A workout keeps no link to its
/// template's exercises, and a lift used twice in one session is the only
/// case a slot tells apart.
Iterable<(WorkoutExercise, String?)> _occurrences(
  Workout workout,
  Template? session, {
  Map<String, String>? slots,
}) sync* {
  if (slots != null) {
    for (final exercise in workout) {
      yield (exercise, slots[exercise.id]);
    }
    return;
  }
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
/// the same session for a slotted base, else every occurrence. Null when the
/// occurrences can't be told apart: the finish dropped one, and by position
/// the rest would be read as the wrong slots.
List<ExerciseSet>? _setsOf(Workout workout, _Group group, {Template? session}) {
  final slot = group.slot;
  if (slot == null) {
    return [
      for (final exercise in workout)
        if (exercise.exercise.id == group.exerciseId) ...exercise,
    ];
  }
  if (workout.templateId != session?.id) return const [];
  bool sameLift(WorkoutExercise exercise) => exercise.exercise.id == group.exerciseId;
  final planned = session?.where(sameLift).length ?? 0;
  if (workout.where(sameLift).length < planned) return null;
  return [
    for (final (exercise, each) in _occurrences(workout, session))
      if (each == slot) ...exercise,
  ];
}
