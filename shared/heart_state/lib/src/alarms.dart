import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Alarms with ChangeNotifier implements SignOutStateSentry {
  final VoidCallback? cancelRestTimerNotifications;
  final Duration _tick;

  Alarms({
    Duration tick = const Duration(seconds: 1),
    this.cancelRestTimerNotifications,
  }) : _tick = tick;

  @override
  void onSignOut() {
    stopActiveExerciseTimer();
  }

  static Alarms of(BuildContext context) {
    return Provider.of<Alarms>(context, listen: false);
  }

  static Alarms watch(BuildContext context) {
    return Provider.of<Alarms>(context, listen: true);
  }

  ({Timer timer, ValueNotifier<int> remains, num total, DateTime end})? _activeExercise;

  Timer? get activeExerciseTimer => _activeExercise?.timer;

  ValueNotifier<int>? get remainsInActiveExercise => _activeExercise?.remains;

  num? get activeExerciseTotal => _activeExercise?.total;

  static DateTime _now() => DateTime.now();

  void _stopActiveExerciseTimer() {
    _activeExercise
      ?..timer.cancel()
      ..remains.dispose();
    _activeExercise = null;
  }

  void stopActiveExerciseTimer() {
    _stopActiveExerciseTimer();
    notifyListeners();
  }

  void startActiveExerciseTimer(
    int duration, {
    final void Function(DateTime)? scheduleNotification,
    VoidCallback? onComplete,
  }) {
    _stopActiveExerciseTimer();
    final endTime = _now().add(Duration(seconds: duration));
    scheduleNotification?.call(endTime);

    _activeExercise = (
      remains: ValueNotifier<int>(duration),
      timer: Timer.periodic(
        _tick,
        (timer) {
          final currentEnd = _activeExercise?.end;
          if (currentEnd == null) return;

          final remains = currentEnd.difference(_now()).inMilliseconds;
          if (remains > 0) {
            _activeExercise?.remains.value = (remains / _tick.inMilliseconds).ceil();
          } else {
            _activeExercise?.remains.value = 0;
            if (timer.isActive) {
              onComplete?.call();
            }
            stopActiveExerciseTimer();
          }
        },
      ),
      total: duration,
      end: endTime,
    );
    notifyListeners();
  }

  void adjustActiveExerciseTime(
    int adjustment, {
    final void Function(DateTime)? rescheduleNotification,
  }) {
    switch (_activeExercise) {
      case (:Timer timer, :ValueNotifier<int> remains, :num total, :DateTime end):
        final rescheduled = end.add(Duration(seconds: adjustment));

        rescheduleNotification?.call(rescheduled);
        final newRemains = rescheduled.difference(_now()).inMilliseconds;

        _activeExercise = (
          timer: timer,
          remains: remains..value = max(0, (newRemains / 1000).ceil()),
          total: max(0, total + adjustment),
          end: rescheduled,
        );
        notifyListeners();
    }
  }
}
