import 'package:heart_health/models.dart';
import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// The training behind a day set aside (#312), as it stood at that moment:
/// when the last workout before it began, the working sets of the week
/// before it, and the muscle groups trained in the two days before it, by the
/// name the app's map gives them.
final class SkipTraining {
  final DateTime? lastWorkoutAt;
  final int setsWeek;
  final Set<String> recovering;

  const new({required this.lastWorkoutAt, required this.setsWeek, required this.recovering});

  factory fromMap(Map<String, Object?> map) {
    return SkipTraining(
      lastWorkoutAt: switch (map['lastWorkoutAt']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
      setsWeek: switch (map['setsWeek']) {
        final num sets => sets.toInt(),
        _ => 0,
      },
      recovering: switch (map['recovering']) {
        final List groups => {...groups.whereType<String>()},
        _ => const {},
      },
    );
  }

  Map<String, Object?> toMap() {
    return {
      'lastWorkoutAt': lastWorkoutAt?.toUtc().toIso8601String(),
      'setsWeek': setsWeek,
      'recovering': recovering.toList(),
    };
  }
}

/// What a day looked like when it was set aside (#445): taken once, at the
/// skip, so a workout deleted later or a day's steps still climbing never
/// change what the skip's page says.
///
/// Device-only, [body] above all (`docs/2026-09-05.health-data.md`): the skip
/// syncs, this never does.
final class SkipSnapshot {
  final DateTime takenAt;
  final SkipTraining training;

  /// What Health had for the day, by metric, in each metric's stored unit.
  /// Empty with nothing read, or once the health mirror was forgotten.
  final Map<HealthMetric, double> body;

  const new({required this.takenAt, required this.training, this.body = const {}});
}

/// Where snapshots are kept: this device's database, and nowhere else.
abstract interface class SkipSnapshotStore {
  Future<SkipSnapshot?> getSkipSnapshot(String skipId);

  /// Keeps [snapshot] unless [skipId] has one already.
  Future<void> storeSkipSnapshot(String skipId, String userId, SkipSnapshot snapshot);

  Future<void> deleteSkipSnapshot(String skipId);

  /// Hands [from]'s snapshot to [to]: the same skip, stored again under a
  /// new id.
  Future<void> moveSkipSnapshot(String from, String to);
}

/// What Health can say about a day someone chose not to train.
const skipBodyMetrics = [
  HealthMetric.sleepAsleep,
  HealthMetric.heartRateVariability,
  HealthMetric.restingHeartRate,
  HealthMetric.steps,
];

/// Takes and reads the snapshot of each skip (#445).
///
/// No remote leg, by construction: health values pass through here, and the
/// only thing it can reach is [SkipSnapshotStore]. Its failures carry values
/// too — a database error quotes what it was binding — so they go to
/// [onError], which the app points at its redacting reporter.
class SkipSnapshots {
  final SkipSnapshotStore _store;

  /// The training before [at], read from the workouts this device holds.
  final Future<SkipTraining> Function(DateTime at, String userId) _trainingBefore;

  /// The health mirror's series for a metric, a value a day.
  final List<HealthDailyValue> Function(HealthMetric metric) _healthOf;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required this._store,
    required this._trainingBefore,
    required this._healthOf,
    this.onError,
  });

  static SkipSnapshots of(BuildContext context) => Provider.of<SkipSnapshots>(context, listen: false);

  /// Takes [skip]'s snapshot, once: a skip that has one keeps it.
  /// Never throws: a snapshot that could not be taken is a skip without one.
  Future<void> take(TrainingSkip skip, String userId, {DateTime? now}) async {
    final id = skip.id;
    if (id == null) return;
    try {
      final takenAt = now ?? DateTime.now();
      final snapshot = SkipSnapshot(
        takenAt: takenAt,
        training: await _trainingBefore(skip.at, userId),
        body: bodyOn(skip.at, takenAt: takenAt),
      );
      await _store.storeSkipSnapshot(id, userId, snapshot);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Forgets [skipId]'s snapshot: the skip was taken back.
  Future<void> drop(String skipId) async {
    try {
      await _store.deleteSkipSnapshot(skipId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Hands [from]'s snapshot to [to]: a reason given is the same skip stored
  /// again under a new id, and it is still the same moment.
  Future<void> move(String from, String to) async {
    try {
      await _store.moveSkipSnapshot(from, to);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// [skipId]'s snapshot; null for a skip made before snapshots, on another
  /// device, or one that could not be read.
  Future<SkipSnapshot?> read(String skipId) async {
    try {
      return await _store.getSkipSnapshot(skipId);
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
      return null;
    }
  }

  /// What the mirror holds for the calendar day of [at], by metric.
  ///
  /// Steps are a day's running total, so they are the day so far only while
  /// the snapshot is taken on that day. A skip that arrives later, one made
  /// outside the app and applied when it next opens, would read the whole
  /// day's, which is not what the day looked like: it is left out.
  Map<HealthMetric, double> bodyOn(DateTime at, {required DateTime takenAt}) {
    final day = at.toLocal();
    final sameDay = _sameDay(day, takenAt.toLocal());
    return {
      for (final metric in skipBodyMetrics)
        if (metric != .steps || sameDay)
          if (_healthOf(metric).where((each) => _sameDay(each.day, day)).lastOrNull case (:final value, day: _))
            metric: value,
    };
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
