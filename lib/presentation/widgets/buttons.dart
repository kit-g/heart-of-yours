import 'package:flutter/material.dart';

/// Flat coloured (or transparent by default) button with an ink well
class InkButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final ShapeBorder? inkShape;
  final Color? backgroundColor;

  const InkButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.inkShape,
  });

  const InkButton.rounded({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
  }) : inkShape = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        );

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: switch (inkShape) {
        RoundedRectangleBorder border => border.borderRadius,
        _ => null,
      },
      color: backgroundColor,
      child: InkWell(
        splashColor: backgroundColor?.withValues(alpha: .5),
        customBorder: inkShape,
        onTap: onPressed,
        child: child,
      ),
    );
  }
}

const _defaultMargin = EdgeInsets.symmetric(horizontal: 8.0, vertical: 6);

class PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final bool wide;
  final EdgeInsets margin;
  final Color? backgroundColor;

  const PrimaryButton.shrunk({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
  }) : wide = false;

  const PrimaryButton.wide({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
  }) : wide = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: InkButton.rounded(
        onPressed: onPressed,
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: margin,
          child: child,
        ),
      ),
    );
  }
}
