import 'dart:async';
import 'dart:math';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// A rest in progress, as the device keeps it (#141): what survives a process
/// death, so that a lock screen acting on the rest — or the app coming back —
/// finds it still running rather than lost. The exercise is the workout's
/// (`WorkoutExercise.id`), which is what ties the rest to a workout.
typedef SavedRest = ({String exerciseId, DateTime end, int total});

/// Where [SavedRest] lives between launches. Null-safe by construction: a
/// store that has nothing answers null, and every call may be repeated.
abstract interface class RestStore {
  Future<SavedRest?> read();

  Future<void> write(SavedRest rest);

  Future<void> clear();
}

class Alarms with ChangeNotifier implements SignOutStateSentry {
  final VoidCallback? cancelRestTimerNotifications;
  final Duration _tick;

  /// The rest's home between launches (#141); null keeps it in memory only.
  final RestStore? _store;

  /// Whether [restore] has had its say this launch — true from the start with
  /// no store, since there is nothing to pick up. A command about the rest
  /// that arrives before this would find no rest and be dropped as stale,
  /// though the rest is on its way: what waits on it waits on this too.
  bool get hasRestored => _restored;
  bool _restored;

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
    this._store,
  }) : _now = now ?? DateTime.now,
       _restored = _store == null;

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

  /// When the running countdown runs out — the wall-clock end the ticks are
  /// derived from, moved by every adjustment. For surfaces that count down on
  /// their own (the lock screen) and need an instant rather than a stream.
  DateTime? get activeExerciseEnd => _activeExercise?.end;

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
    _store?.clear();
    notifyListeners();
  }

  /// Picks up the rest a previous process left running, if it belongs to
  /// [active] and has not run out — the app was killed mid-rest, or the lock
  /// screen acted on one while it was (#141). The "rest complete" notification
  /// scheduled back then is still pending, so none is scheduled here. A rest
  /// that is over, or belongs to an exercise [active] does not have, is
  /// forgotten.
  Future<void> restore(Workout? active) async {
    try {
      final saved = await _store?.read();
      if (saved == null) return;
      final remaining = saved.end.difference(_now()).inMilliseconds;
      final owned = active?.any((exercise) => exercise.id == saved.exerciseId) ?? false;
      if (!owned || remaining <= 0 || _activeExercise != null) {
        await _store?.clear();
        return;
      }
      _start(
        remaining: (remaining / 1000).ceil(),
        total: saved.total,
        end: saved.end,
        exerciseId: saved.exerciseId,
      );
    } finally {
      // said, whatever was found: listeners waiting on it (the lock screen's
      // queued buttons) go ahead now
      _restored = true;
      notifyListeners();
    }
  }

  void startActiveExerciseTimer(
    int duration, {
    required String exerciseId,
    void Function(DateTime)? scheduleNotification,
    VoidCallback? onComplete,
  }) {
    // replaces any running countdown — the notification needs no explicit
    // cancel, scheduling the new one overwrites it (single notification id)
    final endTime = _now().add(Duration(seconds: duration));
    scheduleNotification?.call(endTime);
    _start(remaining: duration, total: duration, end: endTime, exerciseId: exerciseId, onComplete: onComplete);
  }

  void _start({
    required int remaining,
    required num total,
    required DateTime end,
    required String exerciseId,
    VoidCallback? onComplete,
  }) {
    _stopActiveExerciseTimer();
    _activeExercise = (
      remains: ValueNotifier<int>(remaining),
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
            // run out, not skipped: nothing to withdraw, nothing to keep
            _store?.clear();
            notifyListeners();
          }
        },
      ),
      total: total,
      end: end,
      exerciseId: exerciseId,
    );
    _store?.write((exerciseId: exerciseId, end: end, total: total.toInt()));
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
        _store?.write((exerciseId: exerciseId, end: rescheduled, total: max(0, total + adjustment).toInt()));
        notifyListeners();
    }
  }
}
