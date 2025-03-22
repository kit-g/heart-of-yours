part of 'done.dart';

void _drawHeart(Canvas canvas, double x, double y, double size, Paint paint) {
  final width = size;
  final height = size;
  final path = Path();
  final startX = (size / 2) - (width / 2);
  final startY = (size / 2) - height * 0.6;

  path
    ..moveTo(
      startX + (0.5 * width),
      startY + (height * 0.4),
    )
    ..cubicTo(
      startX + (0.2 * width),
      startY + (height * 0.1),
      startX + (-0.25 * width),
      startY + (height * 0.6),
      startX + (0.5 * width),
      startY + height,
    )
    ..moveTo(
      startX + (0.5 * width),
      startY + (height * 0.4),
    )
    ..cubicTo(
      startX + (0.8 * width),
      startY + (height * 0.1),
      startX + (1.25 * width),
      startY + (height * 0.6),
      startX + (0.5 * width),
      startY + height,
    );

  canvas.drawPath(path, paint);
}
