part of 'router.dart';

Widget _pageTransition(BuildContext __, Animation<double> animation, _, Widget child) {
  final scaleAnimation = Tween(begin: .8, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
    ),
  );

  return ScaleTransition(
    scale: scaleAnimation,
    child: FadeTransition(
      opacity: animation,
      child: child,
    ),
  );
}
