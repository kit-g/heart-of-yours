part of 'goals.dart';

/// How long the card takes to turn. Shared so the heading and the buttons
/// resolve on the same beat as the card itself — three separate durations read
/// as three things happening, rather than one card turning over.
const _flipDuration = Duration(milliseconds: 420);

const _flipCurve = Curves.easeInOutCubic;

/// Turns a card over to show what is on the other side.
///
/// A flip rather than a filter or a second screen because the two faces are the
/// same object seen from opposite sides: goals you are working on, and goals you
/// finished. Sliding between them would imply they sit next to each other in a
/// list; a flip says it is one card with a back.
///
/// The halves are swapped at the quarter turn, when the face is edge-on and
/// invisible, so neither is ever seen mirrored. The back is pre-rotated a half
/// turn for the same reason — without it, its content reads backwards.
class _FlipCard extends StatelessWidget {
  final bool showsBack;
  final Widget front;
  final Widget back;

  const new({
    required this.showsBack,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: showsBack ? 1 : 0),
      duration: _flipDuration,
      curve: _flipCurve,
      builder: (_, turn, _) {
        final past = turn >= .5;
        return Transform(
          alignment: .center,
          transform: Matrix4.identity()
            // a little perspective, or the card scales rather than turns
            ..setEntry(3, 2, .0012)
            ..rotateY(turn * pi),
          child: switch (past) {
            true => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(pi),
              child: back,
            ),
            false => front,
          },
        );
      },
    );
  }
}
