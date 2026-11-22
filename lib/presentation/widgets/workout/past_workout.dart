import 'dart:async';

import 'package:clock/clock.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/shown_programs.dart';
import 'package:heart/presentation/widgets/goals/goals.dart' show runningPrograms;
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart' hide Health;
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'adjust_times_dialog.dart';

/// Where a workout logged after the fact goes on Save (#530). Called with the
/// editor's context while it is still up; it reads what it needs before any
/// wait, and the editor leaves without waiting on it, as a finish does.
typedef LogTo = Future<void> Function(BuildContext context, Workout workout);

/// A workout that already happened, being filled in (#530), and where it goes
/// once it is: the user's own History unless the caller says otherwise.
class PastWorkout {
  final Workout workout;
  final LogTo logTo;

  /// Who it is being logged for, by name, when that is not the user: a
  /// coach's client (#560).
  final String? loggingFor;

  const new({required this.workout, this.logTo = logToHistory, this.loggingFor});

  /// [filled] at this one's times, and for whom it is.
  PastWorkout holding(Workout filled, {LogTo? logTo}) {
    filled
      ..start = workout.start
      ..end = workout.end;
    return PastWorkout(workout: filled, logTo: logTo ?? this.logTo, loggingFor: loggingFor);
  }
}

/// Asks when a past workout was, then hands [open] the workout to fill in
/// (#530). The date, start and end are picked first, by default the last hour
/// of today; none of them may be in the future, and the end comes after the
/// start. [on] moves that hour to another day — one tapped in History's
/// calendar (#618) — keeping the time of day. [workout] is the one to fill, a
/// new empty one unless given, and [logTo] is where it goes on Save.
/// Dismissed, nothing opens and nothing is stored.
///
/// A workout in progress is never part of this: logging one that already
/// happened works the same beside it.
Future<void> logPastWorkout(
  BuildContext context, {
  required void Function(PastWorkout) open,
  Workout? workout,
  LogTo logTo = logToHistory,
  String? loggingFor,
  DateTime? on,
}) async {
  final L(:whenWasIt, :next) = L.of(context);
  // to the minute, as the wheels pick it, on the clock the calendar reads
  final now = clock.now();
  final day = on ?? now;
  final end = DateTime(day.year, day.month, day.day, now.hour, now.minute);
  // a day asked for keeps the whole hour inside it: just after midnight, the
  // hour before would start on the day before (#618)
  final start = switch (end.subtract(const Duration(hours: 1))) {
    final before when on != null && before.isBefore(DateUtils.dateOnly(day)) => DateUtils.dateOnly(day),
    final before => before,
  };
  PastWorkout? picked;
  await showAdjustTimesDialog(
    context,
    start: start,
    end: end,
    title: whenWasIt,
    action: next,
    needsLength: true,
    onSave: (start, end) async {
      final filled = (workout ?? Workout())
        ..start = start.toUtc()
        ..end = end?.toUtc();
      picked = PastWorkout(workout: filled, logTo: logTo, loggingFor: loggingFor);
    },
  );
  if (picked case final PastWorkout past when context.mounted) open(past);
}

/// Saves [workout] into the signed-in user's History as a finish would: the
/// mirror, the server for an account, "last time", the goals it met, and the
/// device's health store under the finish's own rules
/// (`docs/2026-09-05.health-data.md`): written only where the write is granted,
/// asked only of a user who has engaged with health. Nothing waits on any of it.
///
/// [plan] is what a program's session was asked to be, kept as a start keeps it.
Future<void> logToHistory(BuildContext context, Workout workout, {WorkoutPlan? plan}) async {
  // read now: the editor this context belongs to is on its way out
  final workouts = Workouts.of(context);
  final health = Health.of(context);
  final mayAsk = Preferences.of(context).healthAsked(health.userId);
  final previous = PreviousExercises.of(context);
  final goals = Goals.of(context);
  final stats = Stats.of(context);
  final exercises = Exercises.of(context);
  final firstWeekday = Preferences.of(context).firstWeekday;
  final running = runningPrograms(context);
  final programs = Programs.of(context);
  final grows = programIdShown(context, workout.programId);
  final session = switch (workout.templateId) {
    final String id => Templates.of(context).lookup(id),
    null => null,
  };
  // read before the save drops the exercises nobody ticked, as a finish's are
  final slots = slotsOf(workout, session);
  final among = [...workouts.history];

  final saving = workouts.logWorkout(workout, plan: plan);
  // a program moves by a session logged after the fact too, unless something
  // moved it since (#737)
  if (grows) unawaited(programs.growPast(workout, among: among, session: session, slots: slots, after: saving));
  final saved = await saving;

  // "last time" and the picker's recency read the mirror
  unawaited(previous.init());

  // a courtesy copy, after the save and never in its way, as a finish's is;
  // the session this device holds, whose exercises carry the catalogue's
  // health annotation (see `finishWorkout`)
  unawaited(health.recordWorkout(workout, title: workout.name, mayAsk: mayAsk));

  // the goals it met, credited to it as the Done page credits a finish; the
  // aggregation predates it, so it is rebuilt first
  await stats.init();
  final lensSets = sharedLensSets(stats.getLensSets);
  await goals.observeProgress(
    (goal) => currentGoalValue(
      goal,
      exercises: exercises,
      firstWeekday: firstWeekday,
      workoutCount: workoutCounter(stats, firstWeekday: firstWeekday),
      lensSets: lensSets,
    ),
    achievedBy: saved.id,
    setAside: (goal) => pausedByPrograms(goal, running),
  );
}
