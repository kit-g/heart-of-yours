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
