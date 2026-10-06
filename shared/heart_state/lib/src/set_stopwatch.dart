import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' hide Category;
import 'package:heart_models/heart_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ephemeral, device-local state (#171). Only the completed duration belongs
/// to the workout model; a running clock never enters the database or sync.
///
/// The clock is an effective start and, while paused, the instant it paused:
/// elapsed is `(pausedAt ?? now) - start`, and resuming moves the start
/// forward by the pause. Nothing ticks to keep count, so backgrounding and a
/// cold start lose nothing.
class SetStopwatch extends ChangeNotifier {
  static const _key = 'setStopwatch.running';
  final bool _persistent;
  final DateTime Function() _now;
  SharedPreferences? _prefs;
  ({String workoutId, String setId, DateTime start, DateTime? pausedAt})? _running;
  Timer? _timer;
  final seconds = ValueNotifier(0);

  new({this._persistent = false, DateTime Function()? now}) : _now = now ?? DateTime.now;

  String? get setId => _running?.setId;

  /// The effective start: now minus elapsed, pauses taken out.
  DateTime? get startedAt => _running?.start;

  /// When it paused, while it is paused.
  DateTime? get pausedAt => _running?.pausedAt;

  /// A set is being timed, counting or paused.
  bool get isRunning => _running != null;
  bool get isPaused => _running?.pausedAt != null;
  bool isTiming(ExerciseSet set) => set.id == setId;

  int get elapsed => switch (_running) {
    (:final start, :final pausedAt, workoutId: _, setId: _) => max(0, (pausedAt ?? _now()).difference(start).inSeconds),
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
          case {'workoutId': String workoutId, 'setId': String setId, 'start': String instant} && final stored:
            final start = DateTime.tryParse(instant);
            final pausedAt = switch (stored['pausedAt']) {
              String at => DateTime.tryParse(at),
              _ => null,
            };
            final valid =
                workout?.id == workoutId &&
                (workout
                        ?.expand((exercise) => exercise)
                        .any(
                          (set) => set.id == setId && !set.isCompleted && set.category.isTimed,
                        ) ??
                    false);
            if (start != null && valid) {
              _running = (workoutId: workoutId, setId: setId, start: start, pausedAt: pausedAt);
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
    if (!set.category.isTimed) return;
    _running = (workoutId: workout.id, setId: set.id, start: _now().toUtc(), pausedAt: null);
    _tick();
    notifyListeners();
    await _store();
  }

  Future<void> pause() async {
    if (_running case final running? when running.pausedAt == null) {
      _running = (workoutId: running.workoutId, setId: running.setId, start: running.start, pausedAt: _now().toUtc());
      _timer?.cancel();
      _timer = null;
      seconds.value = elapsed;
      notifyListeners();
      await _store();
    }
  }

  Future<void> resume() async {
    if (_running case (:final workoutId, :final setId, :final start, pausedAt: final DateTime pausedAt)) {
      _running = (
        workoutId: workoutId,
        setId: setId,
        start: start.add(_now().toUtc().difference(pausedAt)),
        pausedAt: null,
      );
      _tick();
      notifyListeners();
      await _store();
    }
  }

  /// Returns the seconds for the caller to write and complete via the
  /// ordinary set path. Clearing the clock does not itself tick a set.
  int stop() {
    // A tap within the first second still logs a valid, completable set.
    final duration = isRunning ? max(1, elapsed) : 0;
    clear();
    return duration;
  }

  /// Drops the clock, writing nothing: a cancel, or its set going away.
  void clear() {
    if (!isRunning) return;
    _running = null;
    _timer?.cancel();
    _timer = null;
    seconds.value = 0;
    unawaited(_prefs?.remove(_key));
    notifyListeners();
  }

  Future<void> _store() async {
    if (!_persistent) return;
    _prefs ??= await SharedPreferences.getInstance();
    // a stop may have landed while preferences were opening
    if (_running case final running?) {
      await _prefs?.setString(
        _key,
        jsonEncode({
          'workoutId': running.workoutId,
          'setId': running.setId,
          'start': running.start.toIso8601String(),
          if (running.pausedAt case final at?) 'pausedAt': at.toIso8601String(),
        }),
      );
    }
  }

  void _tick() {
    _timer?.cancel();
    _timer = null;
    seconds.value = elapsed;
    if (isPaused) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => seconds.value = elapsed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    seconds.dispose();
    super.dispose();
  }
}
