import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// The pattern lens's count (#341): one function over the same sets, by
/// whichever key, per week or per cycle.
void main() {
  LensSets row({
    required String workout,
    required DateTime start,
    List<String> patterns = const [],
    int sets = 3,
  }) {
    return (
      workoutId: workout,
      exerciseId: 'e1',
      start: start,
      movement: Movement.fromJson({'groups': patterns}),
      muscles: MuscleTagging.empty(),
      target: Target.other,
      sets: sets,
    );
  }

  group('weekOf', () {
    // Wednesday 16 September 2026
    final wednesday = DateTime(2026, 9, 16, 18, 30);

    test('goes back to the first day the user chose, at midnight', () {
      expect(weekOf(wednesday), DateTime(2026, 9, 14));
      expect(weekOf(wednesday, firstWeekday: DateTime.sunday), DateTime(2026, 9, 13));
      expect(weekOf(wednesday, firstWeekday: DateTime.saturday), DateTime(2026, 9, 12));
    });

    test('the first day is its own week', () {
      expect(weekOf(DateTime(2026, 9, 13, 7), firstWeekday: DateTime.sunday), DateTime(2026, 9, 13));
    });

    test('lastWeeksOf lists the weeks ending with this one, oldest first', () {
      expect(
        lastWeeksOf(3, now: wednesday, firstWeekday: DateTime.sunday),
        [DateTime(2026, 8, 30), DateTime(2026, 9, 6), DateTime(2026, 9, 13)],
      );
    });
  });

  group('countByWeek', () {
    final now = DateTime(2026, 9, 16, 12);

    test('counts sets and the sessions that touched a key, per week', () {
      final counts = countByWeek(
        [
          row(workout: 'w1', start: DateTime(2026, 9, 14, 9), patterns: ['horizontal_press'], sets: 3),
          // a second press in the same session: more sets, not another session
          row(workout: 'w1', start: DateTime(2026, 9, 14, 9), patterns: ['horizontal_press'], sets: 2),
          row(workout: 'w2', start: DateTime(2026, 9, 16, 9), patterns: ['horizontal_press', 'horizontal_row']),
          row(workout: 'w0', start: DateTime(2026, 9, 10, 9), patterns: ['horizontal_row'], sets: 4),
        ],
        weeks: 2,
        now: now,
        keysOf: patternsOf,
      );

      expect(counts.keys, [DateTime(2026, 9, 7), DateTime(2026, 9, 14)]);
      expect(counts[DateTime(2026, 9, 7)], {'horizontal_row': (sets: 4.0, sessions: 1)});
      expect(counts[DateTime(2026, 9, 14)], {
        'horizontal_press': (sets: 8.0, sessions: 2),
        'horizontal_row': (sets: 3.0, sessions: 1),
      });
    });

    test('the user\'s first day moves a workout into the week it belongs to', () {
      // a Sunday: last week's for a Monday week, this week's for a Sunday one
      final sunday = row(workout: 'w1', start: DateTime(2026, 9, 13, 9), patterns: ['hip_hinge']);

      final monday = countByWeek([sunday], weeks: 1, now: now, keysOf: patternsOf);
      final ownWeek = countByWeek([sunday], weeks: 1, now: now, keysOf: patternsOf, firstWeekday: DateTime.sunday);

      expect(monday.values.single, isEmpty);
      expect(ownWeek.values.single, {'hip_hinge': (sets: 3.0, sessions: 1)});
    });

    test('a share counts a fraction of each set, and a zero share is no session', () {
      final counts = countByWeek(
        [
          row(workout: 'w1', start: DateTime(2026, 9, 14, 9), sets: 3),
          row(workout: 'w2', start: DateTime(2026, 9, 15, 9), sets: 4),
        ],
        weeks: 1,
        now: now,
        keysOf: (row) => switch (row.workoutId) {
          'w1' => {'triceps': .5, 'chest': 1.0},
          _ => {'triceps': .0},
        },
      );

      expect(counts.values.single, {
        'triceps': (sets: 1.5, sessions: 1),
        'chest': (sets: 3.0, sessions: 1),
      });
    });

    test('an exercise with no movement counts toward no pattern', () {
      final counts = countByWeek(
        [row(workout: 'w1', start: DateTime(2026, 9, 14, 9))],
        weeks: 1,
        now: now,
        keysOf: patternsOf,
      );

      expect(counts.values.single, isEmpty);
    });
  });

  group('countByPeriod', () {
    test('counts a program\'s own cycle when given its starts', () {
      // a six-day rotation: cycles start on the 1st and the 7th
      final cycles = [DateTime(2026, 9, 1), DateTime(2026, 9, 7)];
      DateTime cycleOf(DateTime start) => cycles.lastWhere((cycle) => !start.isBefore(cycle));

      final counts = countByPeriod(
        [
          row(workout: 'w1', start: DateTime(2026, 9, 6, 9), patterns: ['squat']),
          row(workout: 'w2', start: DateTime(2026, 9, 7, 9), patterns: ['squat']),
        ],
        periods: cycles,
        periodOf: cycleOf,
        keysOf: patternsOf,
      );

      expect(counts[cycles.first], {'squat': (sets: 3.0, sessions: 1)});
      expect(counts[cycles.last], {'squat': (sets: 3.0, sessions: 1)});
    });

    test('leaves out a row whose period is not asked for', () {
      final counts = countByPeriod(
        [
          row(workout: 'w1', start: DateTime(2026, 8, 1), patterns: ['squat']),
        ],
        periods: [DateTime(2026, 9, 1)],
        periodOf: (start) => DateTime(start.year, start.month),
        keysOf: patternsOf,
      );

      expect(counts, {DateTime(2026, 9, 1): isEmpty});
    });
  });
}
