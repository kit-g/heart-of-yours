import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Button with a haptic feedback and an [InkWell] around it
class FeedbackButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ShapeBorder? inkwellBorder;
  final String? tooltip;

  const FeedbackButton({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
  }) : inkwellBorder = const RoundedRectangleBorder(borderRadius: .all(.circular(4)));

  const FeedbackButton.circular({
    super.key,
    required this.child,
    this.onPressed,
    this.tooltip,
  }) : inkwellBorder = const CircleBorder();

  @override
  Widget build(BuildContext context) {
    final inkwell = InkWell(
      customBorder: inkwellBorder,
      onTap: onPressed == null ? null : _onPressed,
      child: child,
    );

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: switch (tooltip) {
        String t => Tooltip(
          message: t,
          child: inkwell,
        ),
        null => inkwell,
      },
    );
  }

  void _onPressed() {
    HapticFeedback.lightImpact();
    onPressed?.call();
  }
}
