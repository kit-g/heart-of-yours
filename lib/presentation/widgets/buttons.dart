import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flat coloured (or transparent by default) button with an ink well
class InkButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ShapeBorder? inkShape;
  final Color? backgroundColor;
  final BoxBorder? border;
  final InteractiveInkFeatureFactory? splashFactory;

  const InkButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.inkShape,
    this.border,
    this.splashFactory,
  });

  const InkButton.rounded({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.border,
    this.splashFactory,
  }) : inkShape = const RoundedRectangleBorder(
         borderRadius: BorderRadius.all(Radius.circular(8)),
       );

  @override
  Widget build(BuildContext context) {
    final borderRadius = switch (inkShape) {
      RoundedRectangleBorder border => border.borderRadius,
      _ => null,
    };

    final theme = Theme.of(context);
    final disabledForeground = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final disabledBackground = theme.colorScheme.onSurface.withValues(alpha: 0.12);

    final contentChild = switch (onPressed) {
      null => IconTheme.merge(
        data: IconThemeData(color: disabledForeground),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: disabledForeground),
          child: child,
        ),
      ),
      _ => child,
    };

    return Material(
      borderRadius: borderRadius,
      color: switch (onPressed) {
        null => disabledBackground,
        _ => backgroundColor,
      },

      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: border,
        ),
        child: InkWell(
          splashColor: backgroundColor?.withValues(alpha: .5),
          customBorder: inkShape,
          onTap: onPressed,
          splashFactory: splashFactory,
          child: contentChild,
        ),
      ),
    );
  }
}

const _defaultMargin = EdgeInsets.symmetric(horizontal: 8.0, vertical: 6);

class PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool wide;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final bool enableFeedback;
  final BoxBorder? border;
  final InteractiveInkFeatureFactory? splashFactory;

  const PrimaryButton.shrunk({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
    this.enableFeedback = true,
    this.border,
    this.splashFactory = InkRipple.splashFactory,
  }) : wide = false;

  const PrimaryButton.wide({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
    this.enableFeedback = true,
    this.border,
    this.splashFactory = InkRipple.splashFactory,
  }) : wide = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: InkButton.rounded(
        border: border,
        onPressed: onPressed == null ? null : _onPressed,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: margin,
          child: child,
        ),
      ),
    );
  }

  void _onPressed() {
    if (enableFeedback) {
      HapticFeedback.mediumImpact();
    }
    onPressed?.call();
  }
}
