import 'package:flutter/material.dart';
import 'package:heart_language/heart_language.dart';

class Logo extends StatelessWidget {
  final double titleFontSize;

  const new({
    super.key,
    this.titleFontSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LogoTitle(),
        Motto(),
      ],
    );
  }
}

class LogoTitle extends StatelessWidget {
  final double fontSize;

  const new({
    super.key,
    this.fontSize = 48,
  });

  // lowercase is the logotype, not the name: the app is still called
  // "Heart of yours" everywhere a name is read — the stores, the home
  // screen label, `APP_NAME`
  static const logotype = 'Heart of Yours';

  /// The mark's face, out here so [LogoStripe] can measure the mark with the
  /// same style it renders it in rather than a guess at one.
  ///
  /// The wordmark does not follow the preset, and is deliberately not one of
  /// the preset faces. It has to agree with the launcher icon and the site,
  /// neither of which knows which preset a user picked — and a logotype set in
  /// the UI's own face stops reading as a mark, which is what Literata did on
  /// Ink.
  static TextStyle styleFor(double fontSize) {
    return TextStyle(
      fontFamily: 'DM Sans',
      fontWeight: .w600,
      fontSize: fontSize,
      letterSpacing: fontSize * -0.015,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(logotype, style: styleFor(fontSize));
  }
}

class Motto extends StatelessWidget {
  final double fontSize;
  final FontWeight? weight;

  const new({
    super.key,
    this.fontSize = 18,
    this.weight,
  });

  static TextStyle styleFor(double fontSize, [FontWeight? weight]) {
    return TextStyle(
      fontFamily: 'DM Sans',
      fontStyle: .normal,
      fontSize: fontSize,
      fontWeight: weight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(L.of(context).motto, style: styleFor(fontSize, weight));
  }
}

class LogoStripe extends StatelessWidget {
  final Color? backgroundColor;

  const new({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final color = backgroundColor ?? Theme.of(context).colorScheme.secondaryContainer;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: .2),
            color,
          ],
        ),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 16.0, vertical: 4),
        // The stripe is one line and a fixed height — it hangs in a
        // `PreferredSize` — so the two halves have to be made to fit rather
        // than allowed to wrap.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              mainAxisAlignment: .spaceBetween,
              crossAxisAlignment: .baseline,
              textBaseline: .alphabetic,
              children: [
                const LogoTitle(fontSize: _titleSize),
                // Measured, not scaled: a `FittedBox` reports the unscaled
                // child's baseline, which is the one thing this row aligns on.
                if (_mottoFor(context, constraints.maxWidth) case double size) Motto(fontSize: size, weight: .w400),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _titleSize = 28.0;

  static const _mottoSize = 18.0;

  /// Below this the motto is not copy any more, just texture — the mark goes
  /// out alone rather than trailing something unreadable.
  static const _mottoFloor = 11.0;

  /// The gap the two halves are never allowed to close on each other.
  static const _gap = 12.0;

  /// The motto set as large as it fits beside the mark, or null when it does
  /// not fit at all.
  ///
  /// The mark is the half that may not shrink — it has to agree with the
  /// launcher icon and the site — so the motto is the half that gives. It is
  /// copy, and copy is a different length in every language: at 18pt the
  /// French motto ran a 390pt phone 66px over, and English was 10px over.
  /// A line's width scales with its point size, so the ratio between what
  /// there is and what it wants is the size it can have.
  static double? _mottoFor(BuildContext context, double room) {
    final direction = Directionality.of(context);

    double widthOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      return painter.width;
    }

    final left = room - widthOf(LogoTitle.logotype, LogoTitle.styleFor(_titleSize)) - _gap;
    final wanted = widthOf(L.of(context).motto, Motto.styleFor(_mottoSize, .w400));

    if (wanted <= left) return _mottoSize;

    final fitted = _mottoSize * left / wanted;
    return switch (fitted >= _mottoFloor) {
      true => fitted,
      false => null,
    };
  }
}
