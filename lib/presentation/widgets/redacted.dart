import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:heart/core/env/config.dart';

/// Hides [child] while the in-app bug reporter is capturing the screen.
///
/// `feedback` screenshots the entire widget tree and uploads the PNG to our
/// backend. A user reporting a bug from the profile dashboard would therefore
/// send us a picture of their resting heart rate — health data leaving the
/// device inside an image, which is precisely the thing the feature promises
/// never happens. The package has no per-widget exclusion, so the values take
/// themselves off screen for the duration of the capture.
///
/// Redacted rather than blanked, deliberately. The user is looking at the screen
/// while they annotate it, and a number that silently vanished reads as a
/// rendering bug; a bar that is obviously covering something reads as a choice.
class const RedactedInCapture({required final Widget child, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // `BetterFeedback` is only mounted when the feature is on (see `app.dart`),
    // and `of` throws without it. No reporter means no screenshot to leak into,
    // so there is nothing to hide from either.
    if (!AppConfig.of(context).allowsFeedbackFeature) return child;

    final controller = BetterFeedback.of(context);

    return AnimatedBuilder(
      animation: controller,
      // The subtree is passed through untouched so it is not rebuilt on every
      // toggle — only the wrapper around it changes.
      child: child,
      builder: (context, child) {
        if (!controller.isVisible) return child!;
        return _Redaction(child: child!);
      },
    );
  }
}

class const _Redaction({required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ColorScheme(:onSurfaceVariant) = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Kept in the tree at zero opacity so the redaction is exactly the size
        // of what it covers, and nothing around it shifts as the reporter opens.
        Opacity(opacity: 0, child: child),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: onSurfaceVariant.withValues(alpha: .25),
              borderRadius: const .all(.circular(4)),
            ),
          ),
        ),
      ],
    );
  }
}
