import 'package:flutter_test/flutter_test.dart';
import 'package:heart_charts/src/nice_axis.dart';

typedef Axis = ({double min, double max, double interval});

void main() {
  // The gridlines HistoryChart actually labels: interior ticks, min/max excluded.
  List<double> interiorTicks(Axis a) {
    final ticks = <double>[];
    for (var v = a.min + a.interval; v < a.max - 1e-9; v += a.interval) {
      ticks.add(v);
    }
    return ticks;
  }

  // A value lies on the tick grid if it's an integer number of steps away from 0.
  bool onGrid(double value, double interval) {
    final ratio = value / interval;
    return (ratio - ratio.round()).abs() < 1e-6;
  }

  // Invariants that must hold for every axis regardless of input.
  void expectWellFormed(Axis a, double dataMin, double dataMax) {
    expect(a.interval, greaterThan(0));
    expect(a.interval.isFinite, isTrue);
    expect(a.min, lessThanOrEqualTo(dataMin), reason: 'axis must contain the data');
    expect(a.max, greaterThanOrEqualTo(dataMax), reason: 'axis must contain the data');
    expect(a.min, lessThan(a.max));
    expect(onGrid(a.min, a.interval), isTrue, reason: 'min must sit on the tick grid');
    expect(onGrid(a.max, a.interval), isTrue, reason: 'max must sit on the tick grid');
    expect(a.max - dataMax, greaterThanOrEqualTo(a.interval / 2 - 1e-9),
        reason: 'top headroom so the peak is not clipped');
    expect(
      a.max - dataMax,
      greaterThanOrEqualTo(a.interval / 2 - 1e-9),
      reason: 'top headroom so the peak is not clipped',
    );
    expect(dataMin - a.min, greaterThanOrEqualTo(a.interval / 2 - 1e-9), reason: 'bottom headroom');
    final steps = (a.max - a.min) / a.interval;
    expect(steps - steps.round(), closeTo(0, 1e-6), reason: 'span must be a whole number of steps');
    expect(steps, inInclusiveRange(2, 12), reason: 'a sane number of gridlines');
  }

  group('niceYAxis — invariants across a wide range of inputs', () {
    const cases = <(double, double)>[
      (10, 12),
      (5, 12),
      (0, 100),
      (60, 105),
      (270, 330),
      (100, 100), // flat
      (-5, 5), // straddles zero
      (-100, -10), // fully negative
      (100, 101), // very tight
      (0.1, 0.9), // sub-unit
      (1, 1000000), // huge
      (999, 1001), // large magnitude, small range
    ];

    for (final (lo, hi) in cases) {
      test('($lo, $hi) yields a well-formed axis', () {
        expectWellFormed(niceYAxis(lo, hi), lo, hi);
      });
    }

    test('every interior gridline lands exactly on the grid (no off-tick labels)', () {
      for (final (lo, hi) in cases) {
        final a = niceYAxis(lo, hi);
        for (final tick in interiorTicks(a)) {
          expect(onGrid(tick, a.interval), isTrue, reason: 'tick $tick off grid for ($lo,$hi)');
        }
      }
    });
  });

  group('niceYAxis — generic 1/2/5 steps', () {
    test('a small range snaps to nice bounds and a nice interval', () {
      final a = niceYAxis(10, 12);
      expect(a.interval, 0.5);
      expect(a.min, 9.5);
      expect(a.max, 12.5);
    });

    test('an integer (reps-like) range', () {
      final a = niceYAxis(5, 12);
      expect(a.interval, 2);
      expect(a.min, 4); // 5 is not on the grid -> tight floor, no extra headroom
      expect(a.max, 14); // 12 is on the grid -> a step of headroom added
    });

    test('interval is always a 1/2/5 multiple of a power of ten', () {
      for (final range in [3.0, 7.0, 15.0, 42.0, 88.0, 240.0, 4200.0]) {
        final interval = niceYAxis(0, range).interval;
        // strip the power of ten, leaving a mantissa that must be 1, 2 or 5
        var mantissa = interval;
        while (mantissa >= 10) {
          mantissa /= 10;
        }
        while (mantissa < 1) {
          mantissa *= 10;
        }
        expect([1.0, 2.0, 5.0], contains(double.parse(mantissa.toStringAsFixed(6))));
      }
    });
  });

  group('niceYAxis — headroom', () {
    test('adds a step of headroom when a point sits exactly on a bound', () {
      // 10 and 20 are both multiples of the chosen step -> both bounds move out
      final a = niceYAxis(10, 20);
      expect(a.min, lessThan(10));
      expect(a.max, greaterThan(20));
    });

    test('does not pad when the data is already off the grid', () {
      final a = niceYAxis(5, 11); // neither bound is a step multiple
      expect(a.min, lessThanOrEqualTo(5));
      expect(a.max, greaterThanOrEqualTo(11));
      expect(a.max - 11, lessThan(a.interval)); // ceil only, no extra step
    });
  });

  group('niceYAxis — degenerate series', () {
    test('a flat series bands around the value without throwing', () {
      final a = niceYAxis(100, 100);
      expectWellFormed(a, 100, 100);
      expect(a.min, lessThan(100));
      expect(a.max, greaterThan(100));
    });

    test('an empty (0, 0) series is safe', () {
      final a = niceYAxis(0, 0);
      expect(a.interval, greaterThan(0));
      expect(a.min, lessThan(a.max));
    });

    test('an inverted range (max < min) is treated as degenerate', () {
      final a = niceYAxis(50, 10);
      expect(a.interval, greaterThan(0));
      expect(a.min, lessThan(a.max));
    });
  });

  group('niceYAxis — targetTicks', () {
    test('fewer target ticks -> coarser interval', () {
      final coarse = niceYAxis(0, 100, targetTicks: 3).interval;
      final fine = niceYAxis(0, 100, targetTicks: 8).interval;
      expect(coarse, greaterThan(fine));
    });
  });

  group('niceYAxis — duration step candidates', () {
    const steps = <double>[15, 30, 60, 120, 300, 600, 900, 1800, 3600];

    test('interval snaps to one of the candidates', () {
      final a = niceYAxis(270, 330, stepCandidates: steps); // 04:30..05:30
      expect(steps, contains(a.interval));
      expectWellFormed(a, 270, 330);
    });

    test('interior ticks are unique and strictly increasing (no duplicate 04:30)', () {
      final a = niceYAxis(270, 330, stepCandidates: steps);
      final ticks = interiorTicks(a);
      expect(ticks, isNotEmpty);
      expect(ticks.toSet().length, ticks.length);
      for (var i = 1; i < ticks.length; i++) {
        expect(ticks[i], greaterThan(ticks[i - 1]));
      }
    });

    test('coarsens the step as the range widens', () {
      final narrow = niceYAxis(270, 330, stepCandidates: steps).interval;
      final wide = niceYAxis(60, 3600, stepCandidates: steps).interval;
      expect(wide, greaterThan(narrow));
      expect(steps, contains(wide));
    });

    test('picks the smallest candidate that fits the tick budget', () {
      // range 60s over ~4 intervals: 15s fits (4 ticks), so 15 is chosen over 30
      final a = niceYAxis(270, 330, stepCandidates: steps);
      expect(a.interval, 15);
    });

    test('clamps to the coarsest candidate for an enormous range', () {
      final a = niceYAxis(0, 100000, stepCandidates: steps);
      expect(a.interval, steps.last);
    });

    test('ignores an empty candidate list and falls back to generic', () {
      final a = niceYAxis(270, 330, stepCandidates: const []);
      expectWellFormed(a, 270, 330);
    });
  });
}
