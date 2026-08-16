import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Alarms with ChangeNotifier implements SignOutStateSentry {
  final VoidCallback? cancelRestTimerNotifications;
  final Duration _tick;

  /// The clock the countdown measures against.
  ///
  /// Injectable because the remaining count is *derived* from it rather than
  /// counted: each tick recomputes `end - now`. The tests drive real timers on
  /// a 10ms tick and then assert an exact remaining value, so a loaded CI
  /// runner that overshoots the delay by one tick makes the assertion fail —
  /// 498 where 499 was expected — with nothing actually wrong. A clock the test
  /// advances itself makes that arithmetic deterministic.
  final DateTime Function() _now;

  new({
    this._tick = const Duration(seconds: 1),
    this.cancelRestTimerNotifications,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

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

  ({Timer timer, ValueNotifier<int> remains, num total, DateTime end, String exerciseId})? _activeExercise;

  Timer? get activeExerciseTimer => _activeExercise?.timer;

  ValueNotifier<int>? get remainsInActiveExercise => _activeExercise?.remains;

  num? get activeExerciseTotal => _activeExercise?.total;

  /// The exercise the running countdown belongs to. There is only ever one
  /// countdown; this is what lets the UI draw it on that exercise alone.
  String? get activeExerciseId => _activeExercise?.exerciseId;

  static DateTime _now() => DateTime.now();
  /// The exercise the running countdown belongs to. There is only ever one
  /// countdown; this is what lets the UI draw it on that exercise alone.
  String? get activeExerciseId => _activeExercise?.exerciseId;

  void _stopActiveExerciseTimer() {
    _activeExercise
      ?..timer.cancel()
      ..remains.dispose();
    _activeExercise = null;
  }

  /// Abandons the countdown before it ran out — a skip or a sign-out — so the
  /// pending "rest complete" notification is withdrawn along with it. Natural
  /// completion never comes through here: cancelling right after the
  /// notification fired would wipe it from the notification center.
  void stopActiveExerciseTimer() {
    _stopActiveExerciseTimer();
    cancelRestTimerNotifications?.call();
    notifyListeners();
  }

  void startActiveExerciseTimer(
    int duration, {
    required String exerciseId,
    void Function(DateTime)? scheduleNotification,
    VoidCallback? onComplete,
  }) {
    // replaces any running countdown — the notification needs no explicit
    // cancel, scheduling the new one overwrites it (single notification id)
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
            _stopActiveExerciseTimer();
            notifyListeners();
          }
        },
      ),
      total: duration,
      end: endTime,
      exerciseId: exerciseId,
    );
    notifyListeners();
  }

  void adjustActiveExerciseTime(
    int adjustment, {
    void Function(DateTime)? rescheduleNotification,
  }) {
    switch (_activeExercise) {
      case (:Timer timer, :ValueNotifier<int> remains, :num total, :DateTime end, :String exerciseId):
        final rescheduled = end.add(Duration(seconds: adjustment));

        rescheduleNotification?.call(rescheduled);
        final newRemains = rescheduled.difference(_now()).inMilliseconds;

        _activeExercise = (
          timer: timer,
          remains: remains..value = max(0, (newRemains / 1000).ceil()),
          total: max(0, total + adjustment),
          end: rescheduled,
          exerciseId: exerciseId,
        );
        notifyListeners();
    }
  }
}
