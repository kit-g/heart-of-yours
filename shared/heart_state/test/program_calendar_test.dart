import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// A program's sessions in a calendar, and what an event's link opens (#391).
void main() {
  // joined long before any mark, so every cycle holds all three
  final joined = DateTime.utc(2026, 9, 1);
  Program program({Set<int> days = const {1, 3, 5}, int? weeks, bool archived = false}) {
    return Program(
      id: 'p1',
      name: 'Full body',
      days: days,
      weeks: weeks,
      archived: archived,
      sessions: const ['a', 'b', 'c'],
      joined: {'a': joined, 'b': joined, 'c': joined},
    );
  }

  Workout workout(String id, String session, DateTime start) {
    return Workout.fromJson({
      'id': id,
      'name': 'Session',
      'start': start.toIso8601String(),
      'templateId': session,
      'programId': 'p1',
      'exercises': const [],
    });
  }

  ProgramPosition position(Program program, {Iterable<ProgramMark> marks = const []}) {
    return ProgramPosition.of(program, marks: marks, actions: const [], now: DateTime(2026, 10, 12));
  }

  group('plannedSessions', () {
    // a Monday
    final monday = DateTime(2026, 10, 12, 9);

    test('takes the remaining sessions, then the next weeks, on the preferred days', () {
      final p = program();
      final planned = plannedSessions(
        p,
        position(
          p,
          marks: [ProgramMark(templateId: 'a', at: DateTime.utc(2026, 10, 10), isWorkout: true)],
        ),
        from: monday,
        days: 8,
      );
      expect(planned, [
        (session: 'b', week: 1, day: DateTime(2026, 10, 12)),
        (session: 'c', week: 1, day: DateTime(2026, 10, 14)),
        (session: 'a', week: 2, day: DateTime(2026, 10, 16)),
        (session: 'b', week: 2, day: DateTime(2026, 10, 19)),
      ]);
    });

    test('starts tomorrow when today already had its session', () {
      final p = program(days: {1, 2});
      final planned = plannedSessions(p, position(p), from: monday, days: 2, trainedToday: true);
      expect(planned, [(session: 'a', week: 1, day: DateTime(2026, 10, 13))]);
    });

    test('stops at the end of a program with a length', () {
      final p = program(days: {1, 2, 3, 4, 5, 6, 7}, weeks: 1);
      expect(plannedSessions(p, position(p), from: monday, days: 14).map((each) => each.session), ['a', 'b', 'c']);
    });

    test('plans nothing without days, or for an archived program', () {
      for (final p in [program(days: const {}), program(archived: true)]) {
        expect(plannedSessions(p, position(p), from: monday, days: 14), isEmpty);
      }
    });
  });

  group('undoneDay', () {
    // days are Monday, Wednesday, Friday; 2026-10-12 is a Monday
    // begun the week before: a program nobody has trained yet is not behind
    final begun = [DateTime(2026, 10, 9, 18)];
    DateTime? undone(
      Program p,
      DateTime now, {
      Iterable<DateTime>? marks,
      ProgramPosition? at,
      DateTime? resumedAt,
    }) {
      return undoneDay(p, at ?? position(p), marks: marks ?? begun, now: now, resumedAt: resumedAt);
    }

    test('the latest preferred day behind today, when nothing happened on it or since', () {
      // Thursday: Wednesday went by
      expect(undone(program(), DateTime(2026, 10, 15, 9)), DateTime(2026, 10, 14));
      // the next Monday: Friday did
      expect(undone(program(), DateTime(2026, 10, 19, 7)), DateTime(2026, 10, 16));
    });

    test('today is never behind: its session can still be done', () {
      // Wednesday morning, Monday trained
      final marks = [DateTime(2026, 10, 12, 18)];
      expect(undone(program(), DateTime(2026, 10, 14, 7), marks: marks), isNull);
    });

    test('a workout or a skip on the day, or any day since, settles it', () {
      final thursday = DateTime(2026, 10, 15, 9);
      expect(undone(program(), thursday, marks: [DateTime(2026, 10, 14, 19)]), isNull);
      // done a day late: the days are a hint, never a gate
      expect(undone(program(), thursday, marks: [DateTime(2026, 10, 15, 7)]), isNull);
      // the day before does not
      expect(undone(program(), thursday, marks: [DateTime(2026, 10, 13, 19)]), DateTime(2026, 10, 14));
    });

    test('a mark is placed on the day it fell on here, not in UTC', () {
      // late on the Wednesday, local: its UTC day may already be Thursday
      final late = DateTime(2026, 10, 14, 23, 30).toUtc();
      expect(undone(program(), DateTime(2026, 10, 15, 9), marks: [late]), isNull);
    });

    test('nothing done in it at all is a program not begun, or a history not read yet: not asked about', () {
      expect(undone(program(), DateTime(2026, 10, 15, 9), marks: const []), isNull);
    });

    test('a day inside a pause was nobody\'s to train', () {
      final thursday = DateTime(2026, 10, 15, 9);
      // brought back this morning: Wednesday was in the pause
      expect(undone(program(), thursday, resumedAt: DateTime(2026, 10, 15, 8)), isNull);
      // brought back on Tuesday: Wednesday was a day of its own
      expect(undone(program(), thursday, resumedAt: DateTime(2026, 10, 13, 8)), DateTime(2026, 10, 14));
    });

    test('nothing was due before the program existed', () {
      final p = Program(
        id: 'p1',
        name: 'Full body',
        days: const {1, 3, 5},
        sessions: const ['a', 'b', 'c'],
        joined: {'a': joined, 'b': joined, 'c': joined},
        createdAt: DateTime(2026, 10, 15, 8),
      );
      expect(undone(p, DateTime(2026, 10, 15, 9)), isNull);
      // made on the day itself: that day's session was its to do
      final friday = DateTime(2026, 10, 16);
      final made = Program(
        id: 'p1',
        name: 'Full body',
        days: const {1, 3, 5},
        sessions: const ['a', 'b', 'c'],
        joined: {'a': joined, 'b': joined, 'c': joined},
        createdAt: DateTime(2026, 10, 16, 8),
      );
      expect(undone(made, DateTime(2026, 10, 17, 9)), friday);
    });

    test('no days, archived, or nothing up next: nothing was ever due', () {
      final thursday = DateTime(2026, 10, 15, 9);
      expect(undone(program(days: const {}), thursday), isNull);
      expect(undone(program(archived: true), thursday), isNull);
      final p = program(weeks: 1);
      final finished = ProgramPosition.of(
        p,
        marks: [
          for (final (index, session) in ['a', 'b', 'c'].indexed)
            ProgramMark(templateId: session, at: DateTime.utc(2026, 9, 2 + index), isWorkout: true),
        ],
        actions: const [],
        now: thursday,
      );
      expect(finished.finished, isTrue);
      expect(undone(p, thursday, at: finished), isNull);
    });
  });

  group('occurrenceOf', () {
    final p = program();
    final done = workout('w1', 'a', DateTime.utc(2026, 10, 5, 8));
    final skip = TrainingSkip(id: 'k1', at: DateTime.utc(2026, 10, 6, 8), templateId: 'b', programId: 'p1');
    final second = workout('w2', 'a', DateTime.utc(2026, 10, 12, 8));
    final now = DateTime.utc(2026, 10, 13);

    OccurrenceState of(String session, int week, {List<ProgramAction> actions = const []}) {
      return occurrenceOf(
        p,
        session: session,
        week: week,
        workouts: [done, second],
        skips: [skip],
        actions: actions,
        now: now,
      );
    }

    test('a done occurrence names its workout, and each week its own', () {
      // c is still open in week 1, so w2 is a second a in week 1 and counts
      // for nothing
      expect(of('a', 1), isA<OccurrenceDone>().having((state) => state.workoutId, 'workout', 'w1'));
    });

    test('a skipped one names its skip', () {
      expect(of('b', 1), isA<OccurrenceSkipped>().having((state) => state.skipId, 'skip', 'k1'));
    });

    test('the open one and those after it are still ahead', () {
      expect(of('c', 1), isA<OccurrenceAhead>());
      expect(of('a', 2), isA<OccurrenceAhead>());
    });

    test('a session no longer in the program has passed', () {
      expect(of('gone', 1), isA<OccurrencePassed>());
    });

    test('one a replay jumped over has passed with nothing to show', () {
      final replay = ProgramAction(programId: 'p1', kind: .replay, week: 3, at: DateTime.utc(2026, 10, 12, 9));
      expect(of('c', 1, actions: [replay]), isA<OccurrencePassed>());
    });
  });
}
