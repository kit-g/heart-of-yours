import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:heart/core/utils/visual.dart' show lineWidth;
import 'package:material_ui/material_ui.dart';

/// Flat coloured (or transparent by default) button with an ink well
class InkButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final ShapeBorder? inkShape;
  final Color? backgroundColor;
  final BoxBorder? border;
  final InteractiveInkFeatureFactory? splashFactory;

  /// The ripple's colour: half the fill's, unless given. A clear fill has none
  /// to halve.
  final Color? splashColor;

  const new({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.inkShape,
    this.border,
    this.splashFactory,
    this.splashColor,
  });

  const new rounded({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.border,
    this.splashFactory,
    this.splashColor,
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
        // what had no fill gets none by being disabled
        null when backgroundColor?.a == 0 => backgroundColor,
        null => disabledBackground,
        _ => backgroundColor,
      },

      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: border,
        ),
        child: InkWell(
          splashColor: splashColor ?? backgroundColor?.withValues(alpha: .5),
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

/// The inset that makes a [PrimaryButton] a full 48pt tap target: a page's
/// main action, and the pair of answers a sheet or page ends in.
const tallButtonPadding = EdgeInsets.symmetric(horizontal: 8.0, vertical: 14);

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
  final Color? splashColor;

  /// The height the button answers taps over, when it is more than it draws:
  /// a dialog's answers keep the house 32pt look and a full tap target, the
  /// band above and below it taking the tap too.
  final double? hitHeight;

  /// What a button with only an icon in it does, on a long press and to a
  /// screen reader. Inside the button's own node: a [Tooltip] wrapped around
  /// the button labels the node above it instead.
  final String? tooltip;

  const new shrunk({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.margin = _defaultMargin,
    this.enableFeedback = true,
    this.border,
    this.splashFactory = InkRipple.splashFactory,
    this.splashColor,
    this.hitHeight,
    this.tooltip,
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
    this.splashColor,
    this.hitHeight,
    this.tooltip,
  }) : wide = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // On the default (accent) fill the ambient text color cannot be trusted
    // — pale ink on the accent is illegible in dark mode — so the button owns
    // its content color. Callers passing a background keep owning theirs.
    // Disabled, the ink is the disabled one, over either.
    final content = switch (backgroundColor) {
      null when onPressed != null => DefaultTextStyle.merge(
        style: TextStyle(color: colorScheme.onTertiaryContainer),
        child: IconTheme.merge(
          data: IconThemeData(color: colorScheme.onTertiaryContainer),
          child: child,
        ),
      ),
      _ => child,
    };
    final drawn = SizedBox(
      width: wide ? double.infinity : null,
      child: InkButton.rounded(
        border: border,
        onPressed: onPressed == null ? null : _onPressed,
        backgroundColor: backgroundColor ?? colorScheme.tertiaryContainer,
        splashFactory: splashFactory,
        splashColor: splashColor,
        child: Padding(
          padding: margin,
          child: content,
        ),
      ),
    );
    final button = switch (tooltip) {
      final String message => Tooltip(message: message, child: drawn),
      null => drawn,
    };
    // a node of its own with a button's role: the ink alone announces a tap
    // and its label, not that this is a button, or whether it is enabled.
    // Wrapping the hit band too, the node is as tall as what answers a tap
    final announced = Semantics(
      button: true,
      container: true,
      enabled: onPressed != null,
      child: switch (hitHeight) {
        final double height => GestureDetector(
          behavior: .opaque,
          onTap: onPressed == null ? null : _onPressed,
          excludeFromSemantics: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            // sized to the button, then centred in the band
            child: Align(widthFactor: 1, heightFactor: 1, child: button),
          ),
        ),
        null => button,
      },
    );
    return switch ((wide, hitHeight)) {
      // only over what it draws: stretched by a column, the band would answer
      // taps on the empty page beside it
      (false, _?) => Align(widthFactor: 1, heightFactor: 1, child: announced),
      _ => announced,
    };
  }

  void _onPressed() {
    if (enableFeedback) {
      HapticFeedback.mediumImpact();
    }
    onPressed?.call();
  }
}

/// The quiet button of the Goals header's pair ("Achieved" beside "Add
/// goal"): a dialog's way out, or a page's side action. It draws the house
/// 32pt and answers taps over a full target, so it is never drawn tall.
///
/// [danger] for an answer that can't be taken back; [plain] with no fill, for
/// one inside a line of content or a corner.
class QuietButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool danger;
  final bool plain;

  /// The label's colour, where the place it sits in has one of its own.
  final Color? color;
  final double iconSize;

  const new({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.danger = false,
    this.plain = false,
    this.color,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (fill, own) = switch ((plain, danger)) {
      (true, true) => (Colors.transparent, colorScheme.error),
      (true, false) => (Colors.transparent, colorScheme.primary),
      (false, true) => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      (false, false) => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
    };
    final ink = switch (onPressed) {
      null => colorScheme.onSurface.withValues(alpha: .38),
      _ => color ?? own,
    };
    return PrimaryButton.shrunk(
      backgroundColor: fill,
      splashColor: ink.withValues(alpha: .12),
      hitHeight: kMinInteractiveDimension,
      enableFeedback: danger,
      onPressed: onPressed,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: ink),
        child: ConstrainedBox(
          // with the button's own inset, as wide as a target is at the least
          constraints: const BoxConstraints(minWidth: 32),
          child: switch (icon) {
            final IconData icon => Row(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              spacing: 6,
              children: [
                Icon(icon, size: iconSize, color: ink),
                Flexible(child: child),
              ],
            ),
            null => Center(widthFactor: 1, heightFactor: 1, child: child),
          },
        ),
      ),
    );
  }
}

/// The dialogs' pair laid flat: a muted way out beside the one action, the
/// same size, side by side at the full 48pt.
///
/// Side by side only while both labels fit their halves on one line, at the
/// reader's text size, bold or not. A label that would break there ("Ils ne
/// correspondent pas" on a phone at large text broke mid-word) stacks the
/// pair full width instead, the way out first as the dialogs stack it.
class ButtonPair extends StatelessWidget {
  final String cancel;
  final VoidCallback? onCancel;
  final Key? cancelKey;
  final String action;
  final VoidCallback? onAction;
  final Key? actionKey;

  const new({
    super.key,
    required this.cancel,
    required this.onCancel,
    this.cancelKey,
    required this.action,
    required this.onAction,
    this.actionKey,
  });

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final widest = math.max(lineWidth(context, cancel), lineWidth(context, action));
    final ColorScheme(:surfaceContainerHighest, :onSurface) = Theme.of(context).colorScheme;
    // a button given its own fill draws its label in the ambient color,
    // which under a sheet is not the one that reads on this fill
    final wayOut = PrimaryButton.wide(
      key: cancelKey,
      backgroundColor: surfaceContainerHighest,
      margin: tallButtonPadding,
      onPressed: onCancel,
      child: Center(
        child: Text(
          cancel,
          textAlign: .center,
          style: TextStyle(color: onSurface),
        ),
      ),
    );
    final go = PrimaryButton.wide(
      key: actionKey,
      margin: tallButtonPadding,
      onPressed: onAction,
      child: Center(child: Text(action, textAlign: .center)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - _gap) / 2 - tallButtonPadding.horizontal;
        return switch (widest <= half) {
          // sized together all the same: a fallback glyph can still make
          // one label a hair taller than the other
          true => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: .stretch,
              spacing: _gap,
              children: [
                Expanded(child: wayOut),
                Expanded(child: go),
              ],
            ),
          ),
          false => Column(
            crossAxisAlignment: .stretch,
            spacing: _gap,
            children: [wayOut, go],
          ),
        };
      },
    );
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
