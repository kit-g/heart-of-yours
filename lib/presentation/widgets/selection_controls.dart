import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// Read off from the output on iOS 12. This color does not vary with the
// application's theme color.
const double _kSelectionHandleOverlap = 1.5;
// Extracted from https://developer.apple.com/design/resources/.
const double _kSelectionHandleRadius = 6;

/// As per https://github.com/flutter/flutter/issues/74890#issuecomment-1874304044
class CustomColorCursorSelectionHandle extends CupertinoTextSelectionControls {
  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    // iOS selection handles do not respond to taps.
    final customPaint = CustomPaint(
      painter: _TextSelectionHandlePainter(
        Theme.of(context).textSelectionTheme.selectionHandleColor ?? CupertinoTheme.of(context).primaryColor,
      ),
    );

    // [buildHandle]'s widget is positioned at the selection cursor's bottom
    // baseline. We transform the handle such that the SizedBox is superimposed
    // on top of the text selection endpoints.
    switch (type) {
      case .left:
        return SizedBox.fromSize(
          size: getHandleSize(textLineHeight),
          child: customPaint,
        );
      case .right:
        final desiredSize = getHandleSize(textLineHeight);
        return Transform(
          transform: Matrix4.identity()
            // ignore: deprecated_member_use
            ..translate(desiredSize.width / 2, desiredSize.height / 2)
            ..rotateZ(math.pi)
            // ignore: deprecated_member_use
            ..translate(-desiredSize.width / 2, -desiredSize.height / 2),
          child: SizedBox.fromSize(
            size: desiredSize,
            child: customPaint,
          ),
        );
      // iOS doesn't draw anything for collapsed selections.
      case .collapsed:
        return const SizedBox.shrink();
    }
  }
}

class _TextSelectionHandlePainter extends CustomPainter {
  const _TextSelectionHandlePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double halfStrokeWidth = 1.0;
    final Paint paint = Paint()..color = color;
    final Rect circle = Rect.fromCircle(
      center: const Offset(_kSelectionHandleRadius, _kSelectionHandleRadius),
      radius: _kSelectionHandleRadius,
    );
    final Rect line = Rect.fromPoints(
      const Offset(
        _kSelectionHandleRadius - halfStrokeWidth,
        2 * _kSelectionHandleRadius - _kSelectionHandleOverlap,
      ),
      Offset(_kSelectionHandleRadius + halfStrokeWidth, size.height),
    );
    final Path path = Path()
      ..addOval(circle)
      ..addRect(line);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TextSelectionHandlePainter oldPainter) => color != oldPainter.color;
}

extension TextSelectionExtension on BuildContext {
  TextSelectionControls? platformSpecificSelectionControls() {
    return switch (Theme.of(this).platform) {
      .macOS || .iOS => CustomColorCursorSelectionHandle(),
      _ => null,
    };
  }
}
