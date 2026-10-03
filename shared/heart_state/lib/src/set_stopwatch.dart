import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:heart_models/heart_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ephemeral, device-local state (#171). Only the completed duration belongs
/// to the workout model; a running clock never enters the database or sync.
class SetStopwatch extends ChangeNotifier {
  static const _key = 'setStopwatch.running';
  final bool _persistent;
  final DateTime Function() _now;
  SharedPreferences? _prefs;
  ({String workoutId, String setId, DateTime start})? _running;
  Timer? _timer;
  final seconds = ValueNotifier(0);

  new({this._persistent = false, DateTime Function()? now}) : _now = now ?? DateTime.now;

  String? get setId => _running?.setId;
  DateTime? get startedAt => _running?.start;
  bool get isRunning => _running != null;
  bool isTiming(ExerciseSet set) => set.id == setId;
  int get elapsed => switch (_running) {
    (:final start, workoutId: _, setId: _) => max(0, _now().difference(start).inSeconds),
    null => 0,
  };

  Future<void> restore(Workout? workout) async {
    if (!_persistent) return;
    _prefs ??= await SharedPreferences.getInstance();
    if (_running != null) return;
    try {
      final raw = _prefs?.get(_key);
      if (raw is String) {
        switch (jsonDecode(raw)) {
          case {'workoutId': String workoutId, 'setId': String setId, 'start': String instant}:
            final start = DateTime.tryParse(instant);
            final valid =
                workout?.id == workoutId &&
                (workout
                        ?.expand((exercise) => exercise)
                        .any(
                          (set) =>
                              set.id == setId &&
                              !set.isCompleted &&
                              (set.category == .duration || set.category == .cardio),
                        ) ??
                    false);
            if (start != null && valid) {
              _running = (workoutId: workoutId, setId: setId, start: start);
              _tick();
              notifyListeners();
              return;
            }
        }
      }
    } on FormatException {
      // A damaged or obsolete local entry is not a running set.
    }
    await _prefs?.remove(_key);
  }

  Future<void> start(Workout workout, ExerciseSet set) async {
    if (isRunning || set.isCompleted || !workout.expand((exercise) => exercise).contains(set)) return;
    if (set.category != .duration && set.category != .cardio) return;
    _running = (workoutId: workout.id, setId: set.id, start: _now().toUtc());
    _tick();
    notifyListeners();
    if (_persistent) {
      _prefs ??= await SharedPreferences.getInstance();
      // Stop may have happened while preferences were opening.
      if (_running case final running?) {
        await _prefs?.setString(
          _key,
          jsonEncode({
            'workoutId': running.workoutId,
            'setId': running.setId,
            'start': running.start.toIso8601String(),
          }),
        );
      }
    }
  }

  /// Returns the wall-clock seconds for the caller to write and complete via
  /// the ordinary set path. Clearing the clock does not itself tick a set.
  int stop() {
    // A tap within the first second still logs a valid, completable set.
    final duration = isRunning ? max(1, elapsed) : 0;
    clear();
    return duration;
  }

  void clear() {
    if (!isRunning) return;
    _running = null;
    _timer?.cancel();
    _timer = null;
    seconds.value = 0;
    unawaited(_prefs?.remove(_key));
    notifyListeners();
  }

  void _tick() {
    _timer?.cancel();
    seconds.value = elapsed;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value = elapsed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    seconds.dispose();
    super.dispose();
  }
}
