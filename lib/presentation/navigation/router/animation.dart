part of 'router.dart';

Widget _pageTransition(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
  return _scaleFade(context, animation, child, from: .8, curve: Curves.easeOutBack);
}

/// A page scaling up from [from] as it fades in, along [curve].
Widget _scaleFade(
  BuildContext _,
  Animation<double> animation,
  Widget child, {
  required double from,
  required Curve curve,
}) {
  return ScaleTransition(
    scale: Tween(begin: from, end: 1.0).animate(CurvedAnimation(parent: animation, curve: curve)),
    child: FadeTransition(opacity: animation, child: child),
  );
}

/// Set while the user is crossing between spaces (#685), by the two ways
/// across, so that only that arrival fades through: the same shells are
/// rebuilt by many other trips (a finished workout, a sign-in, a gate) that
/// should keep arriving at once.
var _crossingSpaces = false;
Timer? _crossing;

/// Marks the next arrival of a space's shell as a crossing.
void _crossSpaces() {
  _crossingSpaces = true;
  _crossing?.cancel();
  // long enough for the router to build the new shell's route
  _crossing = Timer(const Duration(milliseconds: 500), () => _crossingSpaces = false);
}

/// A space's whole shell (#685): the user's own, or Coaching. Crossing
/// between them is crossing between two apps' navigation, so it fades
/// through the page colour rather than snapping, the same way in both
/// directions; any other arrival, or one asked for less motion, is at once.
CustomTransitionPage<void> _spacePage(BuildContext context, {required LocalKey key, required Widget child}) {
  final duration = _crossingSpaces && !lessMotion(context) ? const Duration(milliseconds: 300) : Duration.zero;
  final background = Theme.of(context).scaffoldBackgroundColor;
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    // the space going out is gone at once: through the page colour, not
    // the window's black
    transitionsBuilder: (context, animation, _, child) => ColoredBox(
      color: background,
      child: _scaleFade(context, animation, child, from: .96, curve: Curves.easeOutCubic),
    ),
  );
}
