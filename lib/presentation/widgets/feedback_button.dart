import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Button with a haptic feedback and an [InkWell] around it
class FeedbackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ShapeBorder? inkwellBorder;

  const FeedbackButton({
    super.key,
    required this.child,
    this.onPressed,
    this.inkwellBorder,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        customBorder:
            inkwellBorder ??
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(4),
              ),
            ),
        onTap: onPressed == null ? null : _onPressed,
        child: child,
      ),
    );
  }

  void _onPressed() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }
}
