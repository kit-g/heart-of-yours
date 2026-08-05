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
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = .round;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), line..color = track);

    // The domain runs from the origin to the furthest point in play, so ticks
    // sit where the targets actually are relative to one another — an evenly
    // spaced stepper would imply the rungs are equal effort, and they are not.
    final span = [...targets, ?current].reduce((a, b) => a > b ? a : b);
    if (span <= 0) return;

    double x(double value) => (value / span).clamp(0.0, 1.0) * size.width;

    if (current case final double value) {
      // Progress is only filled where "more" means "closer". For pace — the one
      // metric where progress goes down — a bar filling rightwards would read
      // exactly backwards, so that case gets a position marker and no fill.
      switch (lowerIsBetter) {
        case false:
          canvas.drawLine(Offset(0, y), Offset(x(value), y), line..color = fill);
        case true:
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
      final isAchieved = index < achieved.length && achieved[index];
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

  @override
  bool shouldRepaint(_LadderPainter old) {
    return old.current != current || old.targets != targets || old.fill != fill || old.track != track;
  }
}
