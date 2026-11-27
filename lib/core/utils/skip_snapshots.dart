import 'package:heart/core/utils/muscle_volume.dart' show muscleGroupsOf;
import 'package:heart_db/heart_db.dart';
import 'package:heart_health/heart_health.dart' show HealthMetric;
import 'package:heart_state/heart_state.dart';

/// Presents [LocalDatabase] as the [SkipSnapshotStore] the [SkipSnapshots]
/// taker wants (#445): the row's maps to the model and back. Pure
/// delegation, for the reason `LocalGoals` is.
class LocalSkipSnapshots implements SkipSnapshotStore {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<SkipSnapshot?> getSkipSnapshot(String skipId) async {
    return switch (await _db.getSkipSnapshot(skipId)) {
      (:final takenAt, :final training, :final body) => SkipSnapshot(
        takenAt: takenAt,
        training: SkipTraining.fromMap(training),
        // a metric a newer build kept and this one has never heard of is
        // left in the row and out of what this build shows
        body: {
          for (final metric in HealthMetric.values)
            if (body?[metric.value] case final double value) metric: value,
        },
      ),
      null => null,
    };
  }

  @override
  Future<void> storeSkipSnapshot(String skipId, String userId, SkipSnapshot snapshot) {
    return _db.storeSkipSnapshot(skipId, userId, (
      takenAt: snapshot.takenAt,
      training: snapshot.training.toMap(),
      body: {for (final MapEntry(:key, :value) in snapshot.body.entries) key.value: value},
    ));
  }

  @override
  Future<void> deleteSkipSnapshot(String skipId) => _db.deleteSkipSnapshot(skipId);

  @override
  Future<void> moveSkipSnapshot(String from, String to) => _db.moveSkipSnapshot(from, to);
}

/// How far back a skip's training is read: far enough to say how long it had
/// been, and to hold the week and the two days [trainingOf] counts.
const skipTrainingReach = Duration(days: 28);

/// The training behind a moment (#312), folded from [rows], the working sets
/// of the weeks before [at]: when the last workout began, the sets of the
/// week before, and the muscle groups of the two days before.
SkipTraining trainingOf(Iterable<LensSets> rows, DateTime at) {
  final before = rows.where((row) => !row.start.isAfter(at)).toList();
  final week = at.subtract(const Duration(days: 7));
  final recent = at.subtract(const Duration(hours: 48));
  return SkipTraining(
    lastWorkoutAt: before
        .map((row) => row.start)
        .fold<DateTime?>(
          null,
          (latest, start) => switch (latest) {
            final DateTime latest when latest.isAfter(start) => latest,
            _ => start,
          },
        ),
    setsWeek: before.where((row) => row.start.isAfter(week)).fold(0, (sum, row) => sum + row.sets),
    recovering: {
      for (final row in before.where((row) => row.start.isAfter(recent)))
        for (final group in muscleGroupsOf(row).keys) group.id,
    },
  );
}
