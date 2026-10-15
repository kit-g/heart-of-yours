import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Balance (#342): pairs of patterns set against each other, from the pattern
/// lens's rows.
void main() {
  LensSets row({required DateTime start, List<String> patterns = const [], int sets = 3}) {
    return (
      workoutId: 'w${start.day}',
      exerciseId: patterns.join('+'),
      start: start,
      movement: Movement.fromJson({'groups': patterns}),
      muscles: MuscleTagging.empty(),
      target: Target.other,
      sets: sets,
    );
  }

  final now = DateTime(2026, 9, 16, 12);
  final weeks = lastWeeksOf(4, now: now);
  BalanceCount count(String key, List<LensSets> rows) {
    return countBalance(rows, pairs: balancePairs, weeks: weeks, weekOfStart: weekOf).firstWhere(
      (count) => count.pair.key == key,
    );
  }

  group('readBalancePairs', () {
    test('reads the pairs Heart holds', () {
      expect(balancePairs.map((pair) => pair.key), ['push_pull', 'hinge_squat', 'elbow', 'knee']);
      final push = balancePairs.first;
      expect(push.left.key, 'push');
      expect(push.right.patterns, {'horizontal_row', 'vertical_pull'});
    });

    test('leaves out what it cannot read and keeps the rest', () {
      final pairs = readBalancePairs([
        {'key': 'no_sides'},
        {
          'key': 'empty_side',
          'left': {'key': 'a', 'patterns': <String>[]},
          'right': {
            'key': 'b',
            'patterns': ['x'],
          },
        },
        {
          'key': 'fine',
          'left': {
            'key': 'a',
            'patterns': ['x', 7],
          },
          'right': {
            'key': 'b',
            'patterns': ['y'],
          },
          'unknown': true,
        },
      ]);
      expect(pairs.map((pair) => pair.key), ['fine']);
      expect(pairs.single.left.patterns, {'x'});
      expect(readBalancePairs('not a list'), isEmpty);
    });
  });

  group('countBalance', () {
    test('counts each side over the window, and the weeks either side was trained', () {
      final push = count('push_pull', [
        row(start: DateTime(2026, 9, 14), patterns: ['horizontal_press'], sets: 4),
        row(start: DateTime(2026, 9, 15), patterns: ['vertical_press']),
        row(start: DateTime(2026, 9, 8), patterns: ['horizontal_row'], sets: 5),
        // before the window
        row(start: DateTime(2026, 8, 10), patterns: ['vertical_pull'], sets: 9),
        // on neither side
        row(start: DateTime(2026, 9, 14), patterns: ['squat_bilateral'], sets: 5),
      ]);
      expect(push.left, 7);
      expect(push.right, 5);
      expect(push.weeks, 2);
      expect(push.enough, isTrue);
    });

    test('an exercise with two patterns on one side counts once toward it', () {
      final push = count('push_pull', [
        row(start: DateTime(2026, 9, 14), patterns: ['horizontal_press', 'chest_dip'], sets: 3),
      ]);
      expect(push.left, 3);
    });

    test('a thruster is a squat and a press, so it counts toward both pairs', () {
      final rows = [
        row(start: DateTime(2026, 9, 14), patterns: ['squat_bilateral', 'vertical_press']),
      ];
      expect(count('push_pull', rows).left, 3);
      expect(count('hinge_squat', rows).right, 3);
    });

    test('one week, or a handful of sets, is not enough to compare', () {
      final oneWeek = count('push_pull', [
        row(start: DateTime(2026, 9, 14), patterns: ['horizontal_press'], sets: 10),
      ]);
      expect(oneWeek.enough, isFalse);

      final few = count('push_pull', [
        row(start: DateTime(2026, 9, 14), patterns: ['horizontal_press'], sets: 2),
        row(start: DateTime(2026, 9, 7), patterns: ['horizontal_row'], sets: 2),
      ]);
      expect(few.weeks, 2);
      expect(few.enough, isFalse);
    });

    test('a pair with nothing on either side counts zero', () {
      final knee = count('knee', []);
      expect((knee.left, knee.right, knee.weeks), (0, 0, 0));
    });
  });
}
