import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/goals/goals.dart';

/// How far the ladder bar fills.
///
/// Asserted on the paint calls rather than a golden, because what matters is
/// one number — where the fill stops — and a golden would fail for a rounded
/// cap or a nudged tick without saying which.
void main() {
  const width = 100.0;
  const track = Color(0xFFEEEEEE);
  const fill = Color(0xFF3355FF);

  Future<void> pump(
    WidgetTester tester, {
    required List<double> targets,
    required List<bool> achieved,
    double? current,
    bool lowerIsBetter = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: GoalLadderBar(
                targets: targets,
                achieved: achieved,
                current: current,
                lowerIsBetter: lowerIsBetter,
                track: track,
                fill: fill,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // finders are lazy, so this resolves against whatever is pumped
  final bar = find.descendant(
    of: find.byType(GoalLadderBar),
    matching: find.byType(CustomPaint),
  );

  testWidgets('fills to the current value while rungs are still ahead', (tester) async {
    await pump(tester, targets: [10, 20, 30, 40], achieved: [false, false, false, false], current: 24);

    // 24 of a 40 span: three fifths across
    expect(bar, paints..something((method, arguments) => method == #drawLine && (arguments[1] as Offset).dx == 60.0));
  });

  testWidgets('fills past the current value to the furthest rung already cleared', (tester) async {
    // every rung met, but the latest ride was shorter than the best one — the
    // reading a milestone goal reports is the most recent, not the peak
    await pump(tester, targets: [10, 20, 30, 40], achieved: [true, true, true, true], current: 24);

    // the bar reads Complete, so it has to look complete: filling to 24 left
    // the three cleared ticks beyond it stranded on the pale track
    expect(bar, paints..something((method, arguments) => method == #drawLine && (arguments[1] as Offset).dx == width));
  });

  testWidgets('fills to a cleared rung even when the current value cannot be read', (tester) async {
    // no current: a per-exercise goal whose history the app cannot resolve.
    // Clearing a rung is still a fact, and the bar should say so.
    await pump(tester, targets: [10, 20], achieved: [true, false], current: null);

    expect(bar, paints..something((method, arguments) => method == #drawLine && (arguments[1] as Offset).dx == 50.0));
  });

  testWidgets('leaves the bar empty when nothing is cleared and nothing is measured', (tester) async {
    await pump(tester, targets: [10, 20], achieved: [false, false], current: null);

    // the track is drawn regardless; what must not appear is a second line
    // over it in the fill colour
    expect(
      bar,
      isNot(paints..something((method, arguments) => method == #drawLine && (arguments[2] as Paint).color == fill)),
    );
  });

  testWidgets('marks position instead of filling where lower is better', (tester) async {
    // pace: a bar filling rightwards would read exactly backwards, so this one
    // gets a vertical marker at the current value and no fill
    await pump(tester, targets: [10, 20], achieved: [true, false], current: 15, lowerIsBetter: true);

    expect(
      bar,
      paints..something(
        (method, arguments) {
          if (method != #drawLine) return false;
          final (from, to) = (arguments[0] as Offset, arguments[1] as Offset);
          // vertical: the marker runs top to bottom at one x
          return from.dx == to.dx && from.dy != to.dy;
        },
      ),
    );
  });

  testWidgets('the fill ends flat, so only rungs read as dots', (tester) async {
    // a round cap draws a half-disc wherever progress stops, which looked like
    // one more rung — the bar seemed to show dots filled and hollow at random
    await pump(tester, targets: [10, 20], achieved: [false, false], current: 12);

    expect(
      bar,
      paints..something(
        (method, arguments) {
          if (method != #drawLine) return false;
          // the fill is the short line; the track runs the full width
          final to = arguments[1] as Offset;
          if (to.dx != 60.0) return false;
          return (arguments[2] as Paint).strokeCap == StrokeCap.butt;
        },
      ),
    );
  });

  testWidgets('the track keeps its rounded ends, which are the bar\'s own', (tester) async {
    await pump(tester, targets: [10, 20], achieved: [false, false], current: 12);

    expect(
      bar,
      paints..something(
        (method, arguments) {
          if (method != #drawLine) return false;
          final to = arguments[1] as Offset;
          if (to.dx != width) return false;
          return (arguments[2] as Paint).strokeCap == StrokeCap.round;
        },
      ),
    );
  });

  group('a rung reads as met', () {
    testWidgets('when the current value satisfies it, even unstamped', (tester) async {
      // a recurring goal is never stamped — it resets each period, so
      // observeProgress skips it — and its rung sat hollow at six workouts
      // against a target of four
      await pump(tester, targets: [4], achieved: [false], current: 6);

      expect(
        bar,
        paints..something(
          (method, arguments) {
            return method == #drawCircle && (arguments[2] as Paint).style == PaintingStyle.fill;
          },
        ),
      );
    });

    testWidgets('and not when it falls short', (tester) async {
      await pump(tester, targets: [4], achieved: [false], current: 2);

      expect(
        bar,
        isNot(
          paints..something(
            (method, arguments) {
              return method == #drawCircle && (arguments[2] as Paint).style == PaintingStyle.fill;
            },
          ),
        ),
      );
    });

    testWidgets('stays met once stamped, even after the reading falls back', (tester) async {
      // the whole point of recording when a milestone first fell
      await pump(tester, targets: [100], achieved: [true], current: 60);

      expect(
        bar,
        paints..something(
          (method, arguments) {
            return method == #drawCircle && (arguments[2] as Paint).style == PaintingStyle.fill;
          },
        ),
      );
    });
  });
}
