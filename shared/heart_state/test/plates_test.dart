import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

Exercise _exercise({String? key, String category = 'Barbell'}) {
  return Exercise.fromJson({
    'id': 'muffin-${key ?? 'own'}',
    'key': key,
    'name': 'Muffin press',
    'category': category,
    'target': 'Chest',
  });
}

void main() {
  group('loadPlates', () {
    const kg = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

    test('loads a weight exactly, heaviest plates first', () {
      final result = loadPlates(target: 100, bar: 20, plates: kg);
      expect(result, isA<ExactLoad>());
      expect((result as ExactLoad).load, const PlateLoad(total: 100, perSide: [25, 15]));
    });

    test('the fewest plates, where the heaviest first would not make it', () {
      final result = loadPlates(target: 60, bar: 20, plates: [15, 10]);
      expect((result as ExactLoad).load.perSide, [10, 10]);
    });

    test('the bar alone is an exact load with no plates', () {
      final result = loadPlates(target: 20, bar: 20, plates: kg);
      expect((result as ExactLoad).load, const PlateLoad(total: 20, perSide: []));
    });

    test('fractional plates stay exact', () {
      final result = loadPlates(target: 22.5, bar: 20, plates: kg);
      expect((result as ExactLoad).load.perSide, [1.25]);
    });

    test('a weight it cannot make gives the nearest below and above', () {
      final result = loadPlates(target: 101, bar: 20, plates: kg);
      expect(result, isA<NearestLoads>());
      final NearestLoads(:below, :above) = result as NearestLoads;
      expect(below.total, 100);
      expect(above?.total, 102.5);
      expect(above?.perSide, [25, 15, 1.25]);
    });

    test('unticked plates are not used', () {
      final result = loadPlates(target: 102.5, bar: 20, plates: [25, 20, 15, 10, 5, 2.5]);
      final NearestLoads(:below, :above) = result as NearestLoads;
      expect(below.total, 100);
      expect(above?.total, 105);
    });

    test('pounds', () {
      final result = loadPlates(target: 225, bar: 45, plates: [45, 35, 25, 10, 5, 2.5]);
      expect((result as ExactLoad).load.perSide, [45, 45]);
    });

    test('lighter than the bar', () {
      expect(loadPlates(target: 15, bar: 20, plates: kg), isA<UnderBar>());
    });

    test('with no plates, only the bar can be made', () {
      final result = loadPlates(target: 30, bar: 20, plates: const []);
      final NearestLoads(:below, :above) = result as NearestLoads;
      expect(below.total, 20);
      expect(above, isNull);
    });

    test('a machine with no starting weight', () {
      final result = loadPlates(target: 90, bar: 0, plates: kg);
      expect((result as ExactLoad).load.perSide, [25, 20]);
    });
  });

  group('Bar', () {
    test('defaults by equipment', () {
      expect(Bar.defaultFor(_exercise(key: 'bench-press-barbell')), Bar.olympic);
      expect(Bar.defaultFor(_exercise(key: 'squat-smith-machine', category: 'Machine')), Bar.smith);
      expect(Bar.defaultFor(_exercise(key: 'trap-bar-deadlift')), Bar.trap);
      expect(Bar.defaultFor(_exercise(key: 'curl-ez-bar')), Bar.ez);
      expect(Bar.defaultFor(_exercise(key: 'leg-press', category: 'Machine')), Bar.none);
      expect(Bar.defaultFor(_exercise()), Bar.olympic);
    });

    test('a named bar is native to each unit', () {
      expect(Bar.olympic.weightIn(.metric), 20);
      expect(Bar.olympic.weightIn(.imperial), 45);
    });

    test('a custom bar converts', () {
      expect(const CustomBar(20, .metric).weightIn(.imperial), 44.092);
      expect(const CustomBar(20, .metric).weightIn(.metric), 20);
    });

    test('round-trips through storage', () {
      for (final bar in [const NamedBar(Bar.trap), const CustomBar(42.5, .imperial)]) {
        expect(BarWeight.decode(bar.encoded), bar);
      }
      expect(BarWeight.decode('bar:unicycle'), isNull);
      expect(BarWeight.decode('custom:-3:metric'), isNull);
      expect(BarWeight.decode(null), isNull);
    });
  });

  group('Preferences', () {
    late Preferences sut;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sut = Preferences();
      await sut.init();
    });

    test('an exercise takes its default bar until one is chosen', () {
      final squat = _exercise(key: 'squat-smith-machine', category: 'Machine');
      expect(sut.barWeightFor(squat), const NamedBar(Bar.smith));
      sut.setBarWeight(squat, const CustomBar(7.5, .metric));
      expect(sut.barWeightFor(squat), const CustomBar(7.5, .metric));
    });

    test('the full set of plates until one is unticked, per unit', () {
      expect(sut.platesIn(.metric), standardPlates(.metric));
      sut.setPlate(.metric, 1.25, on: false);
      expect(sut.platesIn(.metric), [25, 20, 15, 10, 5, 2.5]);
      expect(sut.platesIn(.imperial), standardPlates(.imperial));
      sut.setPlate(.metric, 1.25, on: true);
      expect(sut.platesIn(.metric), standardPlates(.metric));
    });

    test('storage keys are pinned: renaming one would lose every bar and plate set', () async {
      sut
        ..setBarWeight(_exercise(key: 'squat-barbell'), const NamedBar(Bar.womens))
        ..setPlate(.imperial, 2.5, on: false);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getString('barWeight-muffin-squat-barbell'), 'bar:womens');
      expect(stored.getStringList('platesWithout-imperial'), ['2.5']);
    });

    test('plate calculator is an opt-in, off until answered', () {
      expect(sut.isOn(Feature.plateCalculator), isFalse);
      expect(sut.shouldOffer(Feature.plateCalculator), isTrue);
    });
  });
}
