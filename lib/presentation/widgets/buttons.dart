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

  const new({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.inkShape,
    this.border,
    this.splashFactory,
  });

  const new rounded({
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

/// The inset [PrimaryButton] puts around its label.
///
/// Public so `textButtonTheme` can share it: a text button sitting beside a
/// primary button should put its label on the same inset, and writing the
/// numbers down twice is how the two drift apart.
const primaryButtonPadding = EdgeInsets.symmetric(horizontal: 8.0, vertical: 6);

/// The corner [PrimaryButton] clips its ink to, shared for the same reason.
const primaryButtonRadius = Radius.circular(8);

/// The height [PrimaryButton] comes out at with a single line of label.
///
/// A floor rather than a fixed size, so text scaling still grows the button.
/// It exists because matching padding is not enough to match height: a
/// TextButton lays its label out through `ButtonStyle`, and the ascent/descent
/// rounding lands a point shy of the same text rendered plainly inside a
/// PrimaryButton. Setting the floor states the intent — the two are the same
/// height — instead of chasing it with a padding fudge.
const primaryButtonMinHeight = 32.0;

const _defaultMargin = primaryButtonPadding;

class PrimaryButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool wide;
  final EdgeInsets margin;
  final Color? backgroundColor;
  final bool enableFeedback;
  final BoxBorder? border;
  final InteractiveInkFeatureFactory? splashFactory;

  const new shrunk({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
    this.enableFeedback = true,
    this.border,
    this.splashFactory = InkRipple.splashFactory,
  }) : wide = false;

  const new wide({
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
    final colorScheme = Theme.of(context).colorScheme;
    // On the default (accent) fill the ambient text color cannot be trusted
    // — pale ink on the accent is illegible in dark mode — so the button owns
    // its content color. Callers passing a background keep owning theirs.
    final content = switch (backgroundColor) {
      null => DefaultTextStyle.merge(
        style: TextStyle(color: colorScheme.onTertiaryContainer),
        child: IconTheme.merge(
          data: IconThemeData(color: colorScheme.onTertiaryContainer),
          child: child,
        ),
      ),
      _ => child,
    };
    return SizedBox(
      width: wide ? double.infinity : null,
      child: InkButton.rounded(
        border: border,
        onPressed: onPressed == null ? null : _onPressed,
        backgroundColor: backgroundColor ?? colorScheme.tertiaryContainer,
        child: Padding(
          padding: margin,
          child: content,
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

/// "Sign in with Google" and its siblings: the provider's mark on the leading
/// edge, the label centred across the button.
///
/// It was an [OutlinedButton] with the label centred inside it and the mark
/// laid over the top by a `Positioned(left: 24)` in a [Stack]. Nothing
/// connected the two — the label was centred across the *whole* button,
/// including the strip the mark sat in — so as soon as the copy grew past the
/// English it ran underneath the mark. On a phone that is every language we
/// ship but English: "Iniciar sesión con Google" rendered as
/// "GIniciar sesión con Google", on the one screen App Review always walks.
///
/// So the mark is a child now rather than an overlay, and the label gets the
/// space that is left, with a gutter of the mark's own width opposite it so the
/// two still read as centred. Copy that outgrows the row is scaled down to fit
/// it instead of colliding with the mark.
class ProviderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const new({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const _mark = 24.0;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: _mark),
          Expanded(
            child: Padding(
              padding: const .symmetric(horizontal: 8),
              // Scaled to one line rather than wrapped. A provider button is a
              // single control with a single label; broken over two lines it
              // stops matching the plain sign-in button above it and starts
              // reading as a paragraph. The shrink is small — Spanish is the
              // longest of the five and clears the row at a hair under full
              // size — and English never scales at all.
              child: FittedBox(
                fit: .scaleDown,
                child: Text(label),
              ),
            ),
          ),
          // balances the mark, so the label is centred on the button and not
          // merely on the room the mark leaves it
          const SizedBox(width: _mark),
        ],
      ),
    );
  }
}
