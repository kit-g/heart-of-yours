import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

class Alarms with ChangeNotifier implements SignOutStateSentry {
  Alarms({Duration tick = const Duration(seconds: 1)}) : _tick = tick;

  final Duration _tick;

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

  ({Timer timer, ValueNotifier<int> remains, num total})? _activeExercise;

  Timer? get activeExerciseTimer => _activeExercise?.timer;

  ValueNotifier<int>? get remainsInActiveExercise => _activeExercise?.remains;

  num? get activeExerciseTotal => _activeExercise?.total;

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

  void startActiveExerciseTimer(int duration, {VoidCallback? onComplete}) {
    _stopActiveExerciseTimer();
    _activeExercise = (
      remains: ValueNotifier<int>(duration),
      timer: Timer.periodic(
        _tick,
        (timer) {
          if ((_activeExercise?.remains.value ?? 0) > 0) {
            _activeExercise?.remains.value--;
          } else {
            if (timer.isActive) {
              onComplete?.call();
            }
            stopActiveExerciseTimer();
          }
        },
      ),
      total: duration,
    );
    notifyListeners();
  }

  void adjustActiveExerciseTime(int adjustment) {
    switch (_activeExercise) {
      case (:Timer timer, :ValueNotifier<int> remains, :num total):
        _activeExercise = (
          timer: timer,
          remains: remains..value = max(0, remains.value + adjustment),
          total: max(0, total + adjustment),
        );
        notifyListeners();
    }
  }
}
