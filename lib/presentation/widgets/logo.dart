import 'dart:math' as math;

import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

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
        padding: const .symmetric(horizontal: 16.0, vertical: _inset),
        // The stripe is one line and a fixed height — it hangs in a
        // `PreferredSize` — so the two halves have to be made to fit rather
        // than allowed to wrap.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final (:title, :motto) = _sizesFor(context, constraints.maxWidth);
            // The sizes above already answer the reader's text size, as far as
            // one fixed line can; scaled a second time by `Text`, "Every beat
            // counts." ran 89px off a 360pt phone at 1.3× (#762).
            return MediaQuery.withNoTextScaling(
              child: Row(
                mainAxisAlignment: .spaceBetween,
                crossAxisAlignment: .baseline,
                textBaseline: .alphabetic,
                children: [
                  LogoTitle(fontSize: title),
                  // Measured, not scaled: a `FittedBox` reports the unscaled
                  // child's baseline, which is the one thing this row aligns on.
                  if (motto case double size) Motto(fontSize: size, weight: .w400),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// What every page hangs the stripe in: a `PreferredSize` this tall, which
  /// reserves the height and does not hold its child to it.
  static const _height = 56.0;

  static const _inset = 4.0;

  static const _titleSize = 28.0;

  static const _mottoSize = 18.0;

  /// Below this the motto is not copy any more, just texture — the mark goes
  /// out alone rather than trailing something unreadable.
  static const _mottoFloor = 11.0;

  /// The gap the two halves are never allowed to close on each other.
  static const _gap = 12.0;

  /// The mark's size, and the motto's: as large as it fits beside the mark, or
  /// null when it does not fit at all.
  ///
  /// The mark is the half that may not shrink — it has to agree with the
  /// launcher icon and the site — so the motto is the half that gives. It is
  /// copy, and copy is a different length in every language: at 18pt the
  /// French motto ran a 390pt phone 66px over, and English was 10px over.
  /// A line's width scales with its point size, so the ratio between what
  /// there is and what it wants is the size it can have.
  ///
  /// A larger text size grows the two together, as one lockup, and only while
  /// both still fit: the line is [_height] tall, and the motto never pays for
  /// the mark's growth. On a phone, where the motto has already given to fit,
  /// that is no growth at all — the stripe is the mark, not something to read,
  /// and the page's title above it does grow.
  static ({double title, double? motto}) _sizesFor(BuildContext context, double room) {
    final direction = Directionality.of(context);
    // as `Text` draws them: over the ambient style, bold when asked for
    final ambient = DefaultTextStyle.of(context).style;
    final bold = MediaQuery.boldTextOf(context) ? const TextStyle(fontWeight: .bold) : null;

    Size sizeOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: ambient.merge(style).merge(bold)),
        maxLines: 1,
        textDirection: direction,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final mark = sizeOf(LogoTitle.logotype, LogoTitle.styleFor(_titleSize));
    double mottoAt(double size) => sizeOf(L.of(context).motto, Motto.styleFor(size, .w400)).width;
    final wanted = mottoAt(_mottoSize);

    // At ordinary text: the mark whole, the motto in what is left. Measured
    // again at the size it comes to, since the ambient letter spacing does not
    // shrink with the type and the ratio alone runs a pixel or two wide.
    final left = room - mark.width - _gap;
    final first = math.min(_mottoSize, _mottoSize * left / wanted);
    final motto = switch (first > 0 ? math.min(first, first * left / mottoAt(first)) : first) {
      final fitted when fitted >= _mottoFloor => fitted,
      _ => null,
    };

    // then the two together, as far as the reader asks and the stripe allows
    final lockup = switch (motto) {
      final size? => mark.width + _gap + wanted * size / _mottoSize,
      null => mark.width,
    };
    final asked = MediaQuery.textScalerOf(context).scale(_titleSize) / _titleSize;
    final allowed = math.min((_height - _inset * 2) / mark.height, room / lockup);
    final scale = asked.clamp(1.0, math.max(1.0, allowed));

    return (
      // narrower than the mark itself: nothing is left to give but the mark
      title: math.min(_titleSize * scale, _titleSize * room / mark.width),
      motto: motto == null ? null : motto * scale,
    );
  }
}

/// The heart: the launcher icon's and the splash's mark, one shape from one
/// source (the confetti heart, `routes/done/heart.dart`, fitted to a 64-unit
/// square — `ic_splash_heart.xml` carries the same curves).
class HeartMark extends StatelessWidget {
  final double size;
  final Color? color;

  const new({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: .square(size),
      painter: _HeartPainter(color ?? Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _HeartPainter extends CustomPainter {
  final Color color;

  const new(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 64;
    final path = Path()
      ..moveTo(32.00, 13.42)
      ..cubicTo(10.07, -8.51, -22.82, 28.04, 32.00, 57.27)
      ..cubicTo(86.82, 28.04, 53.93, -8.51, 32.00, 13.42)
      ..close();
    canvas
      ..scale(scale)
      ..drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}
