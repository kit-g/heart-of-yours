import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// [text], wrapped, at the reader's text size, or at the largest one under it
/// that sets the longest word on a line of its own.
///
/// Flutter does not hyphenate, so a word wider than its line is broken wherever
/// the line ends. At the largest text sizes a headline is 87pt and «пожаловать»
/// alone is wider than a phone: onboarding read "Добро пожалова / ть" (#704).
/// Large type has room to give; a broken word has not. Never taken under the
/// style's own size, which is what the layout was drawn for.
class WholeWords extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  /// As far as the text follows the reader's size, for a line in a surface
  /// that cannot grow without end. Null follows it all the way.
  final double? maxScale;

  const new(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxScale,
  });

  /// A word set to exactly its line's width is a rounding error from breaking.
  static const _slack = 1.0;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // as `Text` draws it: the ambient style under ours, bold when asked for
    final drawn = DefaultTextStyle.of(context).style
        .merge(style)
        .merge(MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: .bold) : null);
    final direction = Directionality.of(context);

    // The reader's size as one factor, so a smaller one can be asked for.
    // Read at the style's own size: a scaler need not treat every size alike
    // (Android's leaves large type nearly alone).
    final size = drawn.fontSize ?? 14;
    final asked = scaler.scale(size) / size;
    final wanted = math.min(asked, maxScale ?? asked);

    TextScaler at(double factor) => factor == asked ? scaler : .linear(factor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double fit(double factor) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: drawn),
            textDirection: direction,
            textScaler: at(factor),
          )..layout();
          final longest = painter.minIntrinsicWidth;
          painter.dispose();
          if (longest <= width) return factor;
          return math.min(factor, math.max(1.0, factor * (width - _slack) / longest));
        }

        return Text(
          text,
          style: style,
          textAlign: textAlign,
          // as wide as its longest line, so what sits beside it stays beside it
          textWidthBasis: .longestLine,
          // Fitted twice: letter spacing does not shrink with the type, so the
          // first answer can be a hair wide.
          textScaler: at(fit(fit(wanted))),
        );
      },
    );
  }
}
