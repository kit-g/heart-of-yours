import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/presentation/widgets/buttons.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

Future<void> showCountdownDialog(
  BuildContext context,
  int totalDuration, {
  VoidCallback? onCountdown,
  required final void Function(DateTime) scheduleNotification,
}) {
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
            Countdown(
              total: totalDuration,
              onCountdown: onCountdown,
              scheduleNotification: scheduleNotification,
            ),
          ],
        ),
      );
    },
  );
}

class Countdown extends StatefulWidget {
  final int total;
  final VoidCallback? onCountdown;
  final void Function(DateTime) scheduleNotification;

  const Countdown({
    super.key,
    required this.total,
    this.onCountdown,
    required this.scheduleNotification,
  });

  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> with AfterLayoutMixin<Countdown> {
  final _total = ValueNotifier<int>(0);
  late final Alarms alarms;

  @override
  void dispose() {
    _total.dispose();
    alarms.remainsInActiveExercise?.removeListener(_tickerListener);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final L(:skip, :addSeconds, :subtractSeconds, :restTimer, :restTimerSubtitle) = L.of(context);

    final alarms = Alarms.watch(context);

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
                const SizedBox(),
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
              builder: (_, total, _) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (alarms.remainsInActiveExercise) {
                    ValueNotifier<int> seconds => ValueListenableBuilder<int>(
                      valueListenable: seconds,
                      builder: (_, remaining, _) {
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
                    ),
                    null => CustomPaint(
                      size: const Size(200, 200),
                      painter: CircularTimerPainter(
                        progress: 0,
                        strokeColor: colorScheme.primary,
                        backgroundColor: colorScheme.inversePrimary.withValues(alpha: .3),
                      ),
                    ),
                  },
                );
              },
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (alarms.remainsInActiveExercise) {
                    ValueNotifier<int> seconds => ValueListenableBuilder<int>(
                      valueListenable: seconds,
                      builder: (_, remaining, _) {
                        return Text(
                          _format(remaining),
                          style: textTheme.headlineMedium,
                        );
                      },
                    ),
                    null => Text(
                      _format(0),
                      style: textTheme.headlineMedium,
                    ),
                  },
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _total,
                  builder: (_, total, _) {
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
                  onPressed: () {
                    alarms.adjustActiveExerciseTime(-10, rescheduleNotification: widget.scheduleNotification);
                    _total.value = math.max(_total.value - 10, 0);
                  },
                  child: Center(
                    child: Text(subtractSeconds),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryButton.wide(
                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: .5),
                  onPressed: () {
                    alarms.adjustActiveExerciseTime(10, rescheduleNotification: widget.scheduleNotification);
                    _total.value += 10;
                  },
                  child: Center(
                    child: Text(addSeconds),
                  ),
                ),
              ),
              Expanded(
                child: PrimaryButton.wide(
                  backgroundColor: colorScheme.primary,
                  onPressed: () {
                    Navigator.of(context).pop();
                    alarms.stopActiveExerciseTimer();
                  },
                  child: Center(
                    child: Text(
                      skip,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    alarms = Alarms.of(context);

    _total.value = math.max(widget.total, alarms.activeExerciseTotal?.toInt() ?? 0);

    if (alarms.remainsInActiveExercise == null) {
      alarms.startActiveExerciseTimer(
        widget.total,
        onComplete: widget.onCountdown,
        scheduleNotification: widget.scheduleNotification,
      );
    }
    alarms.remainsInActiveExercise?.addListener(_tickerListener);
  }

  void _tickerListener() {
    if (!context.mounted) return;
    if (Alarms.of(context).remainsInActiveExercise?.value case int seconds when seconds == 0) {
      Navigator.of(context).pop();
    }
  }

  String _format(int duration) {
    return '${_pad(duration ~/ 60)}:${_pad(duration % 60)}';
  }

  static String _pad(int t) {
    return t.toString().padLeft(2, '0');
  }
}

class CircularTimerPainter extends CustomPainter {
  final double progress;
  final Color strokeColor;
  final Color backgroundColor;
  final double strokeWidth;

  const CircularTimerPainter({
    required this.progress,
    required this.strokeColor,
    required this.backgroundColor,
    this.strokeWidth = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
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
