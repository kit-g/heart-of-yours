import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/src/movement_filters.dart';

import 'test_utils.dart';

void main() {
  group('MovementFilter semantics', () {
    test('a pattern matches on any annotated group, not just the first', () {
      // groups are ordered most-representative first, but membership is a set
      final lunge = ex('Lunge', movement: movement(['squat_unilateral', 'lunge']));

      expect(lunge.matchesMovement([const PatternFilter('lunge')]), isTrue);
      expect(lunge.matchesMovement([const PatternFilter('squat_unilateral')]), isTrue);
      expect(lunge.matchesMovement([const PatternFilter('horizontal_press')]), isFalse);
    });

    test('two filters in one dimension widen the result', () {
      final press = ex('Bench Press', movement: movement(['horizontal_press']));

      expect(
        press.matchesMovement([
          const PatternFilter('horizontal_press'),
          const PatternFilter('squat_bilateral'),
        ]),
        isTrue,
      );
    });

    test('filters in different dimensions narrow it', () {
      final press = ex('Bench Press', movement: movement(['horizontal_press'], skill: 'high'));

      // the pattern matches but the ceiling does not, so the exercise is out
      expect(
        press.matchesMovement([
          const PatternFilter('horizontal_press'),
          const SkillCeiling(SkillLevel.low),
        ]),
        isFalse,
      );
    });

    test('a skill ceiling admits everything below it, not just its own level', () {
      final easy = ex('Leg Press', movement: movement(['squat_bilateral'], skill: 'low'));
      final hard = ex('Snatch', movement: movement(['squat_bilateral'], skill: 'high'));

      // the trap the doc names: chip semantics would exclude `low` here
      expect(easy.matchesMovement([const SkillCeiling(SkillLevel.moderate)]), isTrue);
      expect(hard.matchesMovement([const SkillCeiling(SkillLevel.moderate)]), isFalse);
    });

    test('stability is equality, being categorical rather than ordinal', () {
      final machine = ex('Hack Squat', movement: movement(['squat_bilateral'], stability: 'machine'));

      expect(machine.matchesMovement([const StabilityFilter(Stability.machine)]), isTrue);
      expect(machine.matchesMovement([const StabilityFilter(Stability.free)]), isFalse);
    });

    test('an unannotated exercise never matches an active movement filter', () {
      // `Movement.empty()` reads as skill: low / stability: free / axialLoad:
      // none, so without the guard a user-created exercise would surface under
      // every permissive filter while claiming nothing
      final mine = ex('My Curl');

      expect(mine.matchesMovement([const SkillCeiling(SkillLevel.high)]), isFalse);
      expect(mine.matchesMovement([const StabilityFilter(Stability.free)]), isFalse);
      expect(mine.matchesMovement([const PatternFilter('curl')]), isFalse);
    });

    test('an unannotated exercise still shows when no movement filter is set', () {
      final mine = ex('My Curl');

      expect(mine.matchesMovement([]), isTrue);
      expect(mine.matchesMovement([Category.barbell, Target.chest]), isTrue);
    });

    test('filters it does not recognise are passed, mirroring fits', () {
      final press = ex('Bench Press', movement: movement(['horizontal_press']));

      expect(press.matchesMovement([Category.barbell, Target.chest]), isTrue);
    });
  });

  group('MovementFilter identity', () {
    test('equal filters collapse in a set, so the chip row cannot duplicate', () {
      // `Exercises` holds filters in a set and `addFilter` is just `add`, so a
      // chip tapped twice must not leave two entries behind. Enums get this
      // for free; these carry a payload and have to earn it.
      final filters = <ExerciseFilter>{}
        ..add(const PatternFilter('lunge'))
        ..add(const PatternFilter('lung${'e'}'))
        ..add(const SkillCeiling(SkillLevel.low))
        ..add(SkillCeiling(SkillLevel.values.first));

      expect(filters, hasLength(2));
    });

    test('a filter removes by value, so a rebuilt chip still deletes', () {
      final filters = <ExerciseFilter>{const PatternFilter('lunge')}..remove(const PatternFilter('lunge'));

      expect(filters, isEmpty);
    });
  });

  group('MovementFilter identifiers', () {
    // `value` is what the filter *is*, not what it reads as — the wording is
    // the presentation layer's, which is the only place the localizations are
    // reachable. These pin that no copy leaks back in here.
    test('a pattern carries its raw key', () {
      expect(const PatternFilter('horizontal_press').value, 'horizontal_press');
    });

    test('a ceiling carries its enum value', () {
      expect(const SkillCeiling(SkillLevel.moderate).value, 'moderate');
    });

    test('stability carries its enum value', () {
      expect(const StabilityFilter(Stability.machine).value, 'machine');
    });
  });
}
