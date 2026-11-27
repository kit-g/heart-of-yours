import 'package:heart_models/heart_models.dart';

import 'programs.dart' show ProgramLife;

/// One session of a program on the day it is planned for (#391): what a
/// calendar event stands for. [week] is the program week, the cycle the session
/// was planned in, so an event keeps naming the same occurrence after the
/// program has moved on.
typedef SessionAhead = ({String session, int week, DateTime day});

/// The sessions [program] has ahead of it, on its preferred days, from [from]'s
/// day for [days] days: the open cycle's remaining ones first, then each week's
/// in program order. Only a hint, as the days themselves are — nothing is
/// planned for a program without days, paused, finished or archived. With
/// [trainedToday] the plan starts tomorrow: today already had its session.
List<SessionAhead> plannedSessions(
  Program program,
  ProgramPosition position, {
  required DateTime from,
  required int days,
  bool trainedToday = false,
}) {
  if (!program.live || position.paused || position.finished || program.days.isEmpty) return const [];
  final queue = _ahead(program, position).iterator;
  final today = DateTime(from.year, from.month, from.day);
  return [
    for (var offset = trainedToday ? 1 : 0; offset < days; offset++)
      if (DateTime(today.year, today.month, today.day + offset) case final day
          when program.days.contains(day.weekday) && queue.moveNext())
        (session: queue.current.$1, week: queue.current.$2, day: day),
  ];
}

/// The latest of [program]'s preferred days before [now]'s that went by with
/// its session undone: no workout and no skip of the program's on that day or
/// since (#445). The moment "Not today" would have had something to say.
///
/// Null for a program with no days, since nothing was ever due on one; for
/// one paused, finished, archived or with nothing up next; for a day before
/// the program existed, or before [resumedAt], when it was last brought back from
/// a pause; and for a program with no [marks] at all. That last one is a
/// program not begun, and also what a device that has not read its history
/// yet looks like: neither is a session someone let go by. [marks] are when
/// its workouts and skips were.
DateTime? undoneDay(
  Program program,
  ProgramPosition position, {
  required Iterable<DateTime> marks,
  required DateTime now,
  DateTime? resumedAt,
}) {
  if (!program.live || position.paused || position.finished || position.next == null) return null;
  if (marks.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  // a week holds every weekday once: the latest preferred day is in the last seven
  final day = Iterable.generate(
    7,
    (back) => DateTime(today.year, today.month, today.day - back - 1),
  ).where((day) => program.days.contains(day.weekday)).firstOrNull;
  if (day == null) return null;
  if (program.createdAt?.toLocal() case final DateTime created when day.isBefore(_dayOf(created))) return null;
  if (resumedAt?.toLocal() case final DateTime resumed when day.isBefore(_dayOf(resumed))) return null;
  final since = marks.any((at) => !_dayOf(at.toLocal()).isBefore(day));
  return since ? null : day;
}

DateTime _dayOf(DateTime at) => DateTime(at.year, at.month, at.day);

/// Every session still to come, with the week it falls in, up to the end of a
/// program with a length.
Iterable<(String, int)> _ahead(Program program, ProgramPosition position) sync* {
  for (final session in position.remaining) {
    yield (session, position.week);
  }
  for (var week = position.week + 1; program.weeks == null || week <= program.weeks!; week++) {
    final sessions = _sessionsOf(program, week);
    if (sessions.isEmpty) return;
    for (final session in sessions) {
      yield (session, week);
    }
  }
}

/// The sessions program [week] runs, as [ProgramPosition.of] reads them: its
/// phase's, or all of them when the phase has none left.
List<String> _sessionsOf(Program program, int week) {
  final phase = switch (program.phaseOf(week)) {
    final int phase => [
      for (final id in program.phases[phase].sessions)
        if (program.sessions.contains(id)) id,
    ],
    null => const <String>[],
  };
  return phase.isEmpty ? program.sessions : phase;
}

/// Where an occurrence of a session stands (#391): what a calendar event's link
/// opens.
sealed class OccurrenceState {
  const new();
}

/// Not reached yet, or the one the program is on: the link starts it.
final class OccurrenceAhead extends OccurrenceState {
  const new();
}

/// Done by the workout [workoutId].
final class OccurrenceDone extends OccurrenceState {
  final String workoutId;

  const new(this.workoutId);
}

/// Set aside by the skip [skipId] ("Not today", #312).
final class OccurrenceSkipped extends OccurrenceState {
  final String skipId;

  const new(this.skipId);
}

/// Behind the program with nothing that names it — a week repeated or
/// replayed over it, or its workout deleted — or a session no longer in the
/// program: the link opens the program.
final class OccurrencePassed extends OccurrenceState {
  const new();
}

/// What became of [session] in program [week], folded from the program's
/// [workouts], [skips] and [actions] the way [ProgramPosition.of] folds them: the
/// workout or skip that completed it in that week, if one did.
OccurrenceState occurrenceOf(
  Program program, {
  required String session,
  required int week,
  required Iterable<Workout> workouts,
  required Iterable<TrainingSkip> skips,
  required Iterable<ProgramAction> actions,
  required DateTime now,
  int firstWeekday = DateTime.monday,
}) {
  if (!program.sessions.contains(session)) return const OccurrencePassed();

  final events = <(ProgramMark, OccurrenceState)>[
    for (final workout in workouts) (ProgramMark.workout(workout), OccurrenceDone(workout.id)),
    for (final skip in skips)
      if (skip.id case final String id) (ProgramMark.skip(skip), OccurrenceSkipped(id)),
  ]..sort((a, b) => a.$1.at.compareTo(b.$1.at));

  ProgramPosition before(int index, DateTime at) {
    return ProgramPosition.of(
      program,
      marks: events.take(index).map((event) => event.$1),
      actions: actions.where((action) => action.at.isBefore(at)),
      now: at,
      firstWeekday: firstWeekday,
    );
  }

  for (final (index, (mark, state)) in events.indexed) {
    if (mark.templateId != session) continue;
    final position = before(index, mark.at);
    if (position.week == week && position.remaining.contains(session)) return state;
  }

  final current = ProgramPosition.of(
    program,
    marks: events.map((event) => event.$1),
    actions: actions,
    now: now,
    firstWeekday: firstWeekday,
  );
  return switch (current.week) {
    final at when at < week => const OccurrenceAhead(),
    final at when at == week && !current.done.contains(session) => const OccurrenceAhead(),
    _ => const OccurrencePassed(),
  };
}
