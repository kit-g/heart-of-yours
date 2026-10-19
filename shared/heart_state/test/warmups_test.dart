import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

void main() {
  List<WarmupSet> plan(
    double working, {
    Category category = .barbell,
    MeasurementUnit unit = .metric,
    Iterable<WarmupStep> scheme = defaultWarmupScheme,
  }) {
    return warmupSets(working: working, category: category, unit: unit, scheme: scheme);
  }

  group('warmupSets (#158)', () {
    test('40/60/80 of 100 kg, as plates load', () {
      expect(plan(100), [(weight: 40.0, reps: 5), (weight: 60.0, reps: 3), (weight: 80.0, reps: 1)]);
    });

    test('rounds to the nearest 2.5 kg', () {
      // 34.8, 52.2, 69.6
      expect(plan(87).map((set) => set.weight), [35.0, 52.5, 70.0]);
    });

    test('rounds to the nearest 5 lb in pounds, stored back in kilograms', () {
      // 225 lb: 90, 135, 180
      final sets = plan(225.asKilograms, unit: .imperial);
      expect(sets.map((set) => set.weight.asPounds.round()), [90, 135, 180]);
    });

    test('never under the empty bar, and the bar only once', () {
      // 40 kg: 16 → 20, 24 → 25, 32 → 32.5
      expect(plan(40).map((set) => set.weight), [20.0, 25.0, 32.5]);
      // 30 kg: 12 and 18 both land on the bar
      expect(plan(30), [(weight: 20.0, reps: 5), (weight: 25.0, reps: 1)]);
      // 65 lb: 26 and 39 both land on the 45 lb bar, 52 → 50 lb
      expect(plan(65.asKilograms, unit: .imperial).map((set) => set.weight.asPounds.round()), [45, 50]);
    });

    test('nothing at or over the working weight: the empty bar has no warm-up', () {
      expect(plan(20), isEmpty);
      expect(plan(22.5), [(weight: 20.0, reps: 5)]);
    });

    test('a machine has no bar: one step is the least', () {
      expect(plan(10, category: .machine).map((set) => set.weight), [5.0, 7.5]);
    });

    test('only bars and stacks warm up', () {
      for (final category in Category.values) {
        expect(plan(100, category: category).isNotEmpty, warmsUp(category), reason: '$category');
      }
      expect(warmsUp(.barbell) && warmsUp(.machine), isTrue);
    });

    test('takes the ramp lightest first, and skips a rung it cannot hold', () {
      final scheme = [(percent: 75, reps: 2), (percent: 100, reps: 1), (percent: 50, reps: 4)];
      expect(plan(100, scheme: scheme), [(weight: 50.0, reps: 4), (weight: 75.0, reps: 2)]);
    });
  });
}
