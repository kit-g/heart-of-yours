import 'package:heart_models/heart_models.dart';

/// The bars and starting weights the plate calculator knows by name (#132).
/// Each is native to both units — an Olympic bar is 20 kg or 45 lb, never
/// 44.1 lb — so a bar picked by name reads right whichever unit it is shown in.
/// [value] is the storage key and never changes once shipped.
enum Bar {
  olympic('olympic', kg: 20, lb: 45),
  womens('womens', kg: 15, lb: 35),
  ez('ez', kg: 10, lb: 25),
  trap('trap', kg: 25, lb: 55),
  smith('smith', kg: 15, lb: 35),

  /// A plate-loaded machine whose sled weighs nothing worth counting, or one
  /// whose starting weight the user has not told us.
  none('none', kg: 0, lb: 0);

  final String value;
  final double kg;
  final double lb;

  new(this.value, {required this.kg, required this.lb});

  double weightIn(MeasurementUnit unit) {
    return switch (unit) {
      .metric => kg,
      .imperial => lb,
    };
  }

  /// The bar [exercise] most likely uses: by its library slug where that names
  /// the equipment, else by its category. A guess the user can always change.
  static Bar defaultFor(Exercise exercise) {
    final key = exercise.key ?? '';
    return switch (exercise.category) {
      _ when key.contains('smith-machine') => smith,
      _ when key.contains('trap-bar') => trap,
      _ when key.contains('ez-bar') => ez,
      .barbell => olympic,
      .machine ||
      .dumbbell ||
      .weightedBodyWeight ||
      .assistedBodyWeight ||
      .repsOnly ||
      .cardio ||
      .duration ||
      .weightedDistance ||
      .weightedDuration => none,
    };
  }
}

/// What an exercise's bar weighs: one of the named [Bar]s, or a number the
/// user typed, in the unit they typed it in.
sealed class BarWeight {
  const new();

  double weightIn(MeasurementUnit unit);

  /// How it is stored: `bar:olympic`, `custom:42.5:imperial`.
  String get encoded;

  /// The stored form back, or null for anything this version cannot read.
  static BarWeight? decode(String? stored) {
    return switch (stored?.split(':')) {
      ['bar', final String value] => switch (Bar.values.where((bar) => bar.value == value).firstOrNull) {
        Bar bar => NamedBar(bar),
        null => null,
      },
      ['custom', final String value, final String unit] => switch ((
        double.tryParse(value),
        MeasurementUnit.values.where((each) => each.name == unit).firstOrNull,
      )) {
        (double value, MeasurementUnit unit) when value >= 0 => CustomBar(value, unit),
        _ => null,
      },
      _ => null,
    };
  }
}

final class NamedBar extends BarWeight {
  final Bar bar;

  const new(this.bar);

  @override
  double weightIn(MeasurementUnit unit) => bar.weightIn(unit);

  @override
  String get encoded => 'bar:${bar.value}';

  @override
  bool operator ==(Object other) => other is NamedBar && other.bar == bar;

  @override
  int get hashCode => bar.hashCode;
}

final class CustomBar extends BarWeight {
  final double value;
  final MeasurementUnit unit;

  const new(this.value, this.unit);

  @override
  double weightIn(MeasurementUnit unit) {
    return switch ((this.unit, unit)) {
      (.metric, .metric) || (.imperial, .imperial) => value,
      (.metric, .imperial) => _thousandths(value.asPounds),
      (.imperial, .metric) => _thousandths(value.asKilograms),
    };
  }

  @override
  String get encoded => 'custom:$value:${unit.name}';

  @override
  bool operator ==(Object other) => other is CustomBar && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

/// The plates a gym has in [unit], heaviest first: the full standard set, which
/// is what the calculator assumes until the user unticks what theirs lacks.
List<double> standardPlates(MeasurementUnit unit) {
  return switch (unit) {
    .metric => const [25, 20, 15, 10, 5, 2.5, 1.25],
    .imperial => const [45, 35, 25, 10, 5, 2.5],
  };
}

/// A way to load the bar: [total] with the bar, and the plates on each side,
/// heaviest first.
final class PlateLoad {
  final double total;
  final List<double> perSide;

  const new({required this.total, required this.perSide});

  @override
  bool operator ==(Object other) {
    return other is PlateLoad &&
        other.total == total &&
        other.perSide.length == perSide.length &&
        other.perSide.indexed.every((each) => perSide[each.$1] == each.$2);
  }

  @override
  int get hashCode => Object.hash(total, Object.hashAll(perSide));

  @override
  String toString() => 'PlateLoad($total: $perSide)';
}

/// What the calculator makes of a target weight.
sealed class PlateResult {
  const new();
}

/// The target, loaded exactly — with no plates at all when it is the bar.
final class ExactLoad extends PlateResult {
  final PlateLoad load;

  const new(this.load);
}

/// A target the plates cannot make: the nearest loads either side of it.
/// [above] is null when there are no plates to go up with.
final class NearestLoads extends PlateResult {
  final PlateLoad below;
  final PlateLoad? above;

  const new({required this.below, this.above});
}

/// A target lighter than the bar itself.
final class UnderBar extends PlateResult {
  const new();
}

/// Loads [target] on a bar weighing [bar] from [plates], all in one unit.
///
/// Each side takes the same plates, as many of each size as needed, and the
/// fewest plates that make the weight — greedy would miss 20 a side from
/// 15s and 10s. Worked in thousandths, so 1.25s and odd totals stay exact.
PlateResult loadPlates({required double target, required double bar, required Iterable<double> plates}) {
  final want = _milli(target - bar);
  if (want < 0) return const UnderBar();

  // a pair of plates is what a total moves by
  final pairs = {
    for (final plate in plates)
      if (plate > 0) _milli(plate) * 2,
  }.toList()..sort((a, b) => b - a);
  if (pairs.isEmpty) {
    return switch (want) {
      0 => ExactLoad(PlateLoad(total: bar, perSide: const [])),
      _ => NearestLoads(
        below: PlateLoad(total: bar, perSide: const []),
      ),
    };
  }

  final step = pairs.reduce(_gcd);
  final heaviest = pairs.first ~/ step;
  final reach = want ~/ step + heaviest;
  final coins = [for (final pair in pairs) pair ~/ step];

  // fewest[n]: fewest pairs summing to n steps; via[n]: the last one taken
  final fewest = List<int?>.filled(reach + 1, null)..[0] = 0;
  final via = List<int>.filled(reach + 1, 0);
  for (final n in Iterable<int>.generate(reach, (i) => i + 1)) {
    for (final coin in coins) {
      if (coin > n) continue;
      if (fewest[n - coin] case final int count when fewest[n] == null || count + 1 < fewest[n]!) {
        fewest[n] = count + 1;
        via[n] = coin;
      }
    }
  }

  // the pairs behind n steps, walked back through what each step took
  Iterable<double> sides(int n) sync* {
    for (var left = n; left > 0; left -= via[left]) {
      yield via[left] * step / 2000;
    }
  }

  PlateLoad loadAt(int n) {
    return PlateLoad(
      total: _thousandths(bar + n * step / 1000),
      perSide: sides(n).toList()..sort((a, b) => b.compareTo(a)),
    );
  }

  final exact = want % step == 0 ? want ~/ step : null;
  if (exact case final int n when fewest[n] != null) return ExactLoad(loadAt(n));

  final floor = want ~/ step;
  final below = Iterable<int>.generate(floor + 1, (i) => floor - i).firstWhere((n) => fewest[n] != null);
  final above = Iterable<int>.generate(reach - floor, (i) => floor + 1 + i).where((n) => fewest[n] != null).firstOrNull;
  return NearestLoads(
    below: loadAt(below),
    above: switch (above) {
      int n => loadAt(n),
      null => null,
    },
  );
}

int _milli(double value) => (value * 1000).round();

double _thousandths(double value) => (value * 1000).round() / 1000;

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);
