part of 'goals.dart';

/// The ladder as a number line: a tick per stage, filled to where the user is.
///
/// A bar, not a ring — a ring can only show one target, and a ladder has
/// several. Achieved stages are marked by a filled tick rather than a check or
/// a colour change, so the row reads the same under any accent hue.
class GoalLadderBar extends StatelessWidget {
  final List<double> targets;
  final List<bool> achieved;
  final double? current;
  final bool lowerIsBetter;
  final Color track;
  final Color fill;

  const GoalLadderBar({
    super.key,
    required this.targets,
    required this.achieved,
    required this.current,
    required this.lowerIsBetter,
    required this.track,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        painter: _LadderPainter(
          targets: targets,
          achieved: achieved,
          current: current,
          lowerIsBetter: lowerIsBetter,
          track: track,
          fill: fill,
        ),
        size: const Size(double.infinity, 12),
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  final List<double> targets;
  final List<bool> achieved;
  final double? current;
  final bool lowerIsBetter;
  final Color track;
  final Color fill;

  const _LadderPainter({
    required this.targets,
    required this.achieved,
    required this.current,
    required this.lowerIsBetter,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targets.isEmpty) return;

    final y = size.height / 2;
    // The track is capped round because its ends are the bar's ends. The fill
    // is not: a round cap draws a 3px half-disc wherever progress stops, which
    // reads as one more rung dot — so the bar appeared to show dots that were
    // sometimes filled and sometimes hollow with no rule behind it. Only the
    // circles below are rungs; the fill just ends.
    final rail = Paint()
      ..strokeWidth = 3
      ..strokeCap = .round
      ..color = track;
    final progress = Paint()
      ..strokeWidth = 3
      ..strokeCap = .butt
      ..color = fill;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), rail);

    // The domain runs from the origin to the furthest point in play, so ticks
    // sit where the targets actually are relative to one another — an evenly
    // spaced stepper would imply the rungs are equal effort, and they are not.
    final span = [...targets, ?current].reduce((a, b) => a > b ? a : b);
    if (span <= 0) return;

    double x(double value) => (value / span).clamp(0.0, 1.0) * size.width;

    // Progress is only filled where "more" means "closer". For pace — the one
    // metric where progress goes down — a bar filling rightwards would read
    // exactly backwards, so that case gets a position marker and no fill.
    switch (lowerIsBetter) {
      case false:
        if (_reached case final double value) {
          canvas.drawLine(Offset(0, y), Offset(x(value), y), progress);
        }
      case true:
        if (current case final double value) {
          canvas.drawLine(
            Offset(x(value), 0),
            Offset(x(value), size.height),
            Paint()
              ..color = fill
              ..strokeWidth = 2,
          );
        }
    }

    for (final (index, target) in targets.indexed) {
      final isAchieved = _met(index, target);
      canvas.drawCircle(
        Offset(x(target).clamp(3.0, size.width - 3), y),
        3.5,
        Paint()
          ..color = isAchieved ? fill : track
          ..style = isAchieved ? .fill : .stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Whether a rung reads as met.
  ///
  /// Stamped, or currently satisfied. The stamp alone is not enough: a
  /// recurring goal is never stamped — it resets each period, so
  /// [Goals.observeProgress] skips it — which left its one rung drawn hollow
  /// even at six workouts against a target of four. And the stamp alone is not
  /// redundant either: a milestone stays met after the reading falls back below
  /// it, which is the whole point of recording when it first fell.
  bool _met(int index, double target) {
    if (index < achieved.length && achieved[index]) return true;

    return switch (current) {
      final double value => switch (lowerIsBetter) {
        true => value <= target,
        false => value >= target,
      },
      null => false,
    };
  }

  /// How far along the bar is filled.
  ///
  /// Whichever is further: where the user is now, or the furthest rung already
  /// cleared. Clearing a rung is a ratchet — `achievedAt` records when it was
  /// *first* met — while [current] is only the latest reading, so a shorter ride
  /// than last week's drags it back below rungs that are still met. Filling to
  /// [current] alone left a finished ladder drawn as a part-filled bar with its
  /// own achieved ticks stranded past the end of the fill.
  double? get _reached {
    double? cleared;
    for (final (index, target) in targets.indexed) {
      if (index >= achieved.length || !achieved[index]) continue;
      if (cleared == null || target > cleared) cleared = target;
    }

    return switch ((current, cleared)) {
      (final double now, final double met) => now > met ? now : met,
      (final double now, null) => now,
      (null, final double met) => met,
      _ => null,
    };
  }

  @override
  bool shouldRepaint(_LadderPainter old) {
    return old.current != current ||
        old.targets != targets ||
        old.achieved != achieved ||
        old.fill != fill ||
        old.track != track;
  }
}
