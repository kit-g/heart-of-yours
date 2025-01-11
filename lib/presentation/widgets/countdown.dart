import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';

Future<void> showCountdownDialog(BuildContext context, int totalDuration) {
  return showAdaptiveDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Wrap(
          children: [
            Countdown(total: totalDuration),
          ],
        ),
      );
    },
  );
}

class Countdown extends StatefulWidget {
  final int total;

  const Countdown({
    super.key,
    required this.total,
  });

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  final _remaining = ValueNotifier<int>(0);
  final _total = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _total.value = widget.total;
    _remaining.value = widget.total;

    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remaining.dispose();
    _total.dispose();

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_remaining.value > 0) {
          _remaining.value--;
        } else {
          timer.cancel();
        }
      },
    );
  }

  void _adjustTime(int adjustment) {
    _remaining.value += adjustment;
    if (_remaining.value < 0) _remaining.value = 0;
    if (_remaining.value > _total.value) _total.value = _remaining.value;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:skip, :addSeconds, :subtractSeconds, :restTimer, :restTimerSubtitle) = L.of(context);
    return Column(
      spacing: 32,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                  ),
                ),
                const SizedBox()
              ],
            ),
            Text(
              restTimer,
              style: textTheme.titleLarge,
            ),
          ],
        ),
        Text(
          restTimerSubtitle,
          style: textTheme.bodyLarge,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _total,
              builder: (_, total, __) {
                return ValueListenableBuilder<int>(
                  valueListenable: _remaining,
                  builder: (_, remaining, __) {
                    final progress = remaining / total;

                    return CustomPaint(
                      size: const Size(200, 200),
                      painter: CircularTimerPainter(
                        progress: progress,
                        strokeColor: colorScheme.primary,
                        backgroundColor: colorScheme.inversePrimary.withValues(alpha: .3),
                      ),
                    );
                  },
                );
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _remaining,
                  builder: (_, remaining, __) {
                    return Text(
                      _format(remaining),
                      style: textTheme.headlineMedium,
                    );
                  },
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _total,
                  builder: (_, total, __) {
                    return Text(
                      _format(total),
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.secondary),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            spacing: 8,
            children: [
              Expanded(
                child: PrimaryButton.wide(
                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                  onPressed: () => _adjustTime(-10),
                  child: Center(
                    child: Text(subtractSeconds),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryButton.wide(
                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                  onPressed: () => _adjustTime(10),
                  child: Center(
                    child: Text(addSeconds),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryButton.wide(
                  backgroundColor: colorScheme.primaryContainer,
                  onPressed: () {
                    _timer?.cancel();
                  },
                  child: Center(
                    child: Text(skip),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _format(int duration) {
    return "${_pad(duration ~/ 60)}:${_pad(duration % 60)}";
  }

  static String _pad(int t) {
    return t.toString().padLeft(2, '0');
  }
}

class CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color backgroundColor;

  const CircularTimerPainter({
    required this.progress,
    required this.strokeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas
      ..drawCircle(size.center(Offset.zero), size.width / 2, basePaint)
      ..drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2),
        math.pi / -2,
        sweepAngle,
        false,
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(CircularTimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
