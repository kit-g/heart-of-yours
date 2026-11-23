import 'package:heart/core/utils/visual.dart';
import 'package:material_ui/material_ui.dart';

/// The quiet note's look, over a page: the live records note (#160) and a
/// push that arrived with the app open (#724). A raised surface, a hairline
/// border and a soft shadow; the accent is left to what it says.
BoxDecoration noteDecoration(ColorScheme colorScheme) {
  return BoxDecoration(
    color: colorScheme.surfaceContainerHigh,
    border: .all(color: colorScheme.outlineVariant, width: .5),
    borderRadius: noteRadius,
    boxShadow: [
      BoxShadow(color: colorScheme.shadow.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );
}

const noteRadius = BorderRadius.all(.circular(12));

/// How a note comes and goes: a short fade and a drop from above, one note
/// making way for the next. With less motion asked for, it is simply there.
class NoteSwitcher extends StatelessWidget {
  final Widget child;

  const new({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: lessMotion(context) ? Duration.zero : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -.3), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
