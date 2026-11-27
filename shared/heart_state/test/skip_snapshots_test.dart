import 'package:flutter_test/flutter_test.dart';
import 'package:heart_health/models.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class _Store implements SkipSnapshotStore {
  final kept = <String, (String userId, SkipSnapshot snapshot)>{};
  bool failing = false;

  @override
  Future<SkipSnapshot?> getSkipSnapshot(String skipId) async {
    if (failing) throw StateError('bound value 4200');
    return kept[skipId]?.$2;
  }

  @override
  Future<void> storeSkipSnapshot(String skipId, String userId, SkipSnapshot snapshot) async {
    if (failing) throw StateError('bound value 4200');
    kept.putIfAbsent(skipId, () => (userId, snapshot));
  }

  @override
  Future<void> deleteSkipSnapshot(String skipId) async {
    kept.remove(skipId);
  }

  @override
  Future<void> moveSkipSnapshot(String from, String to) async {
    if (kept.remove(from) case final moved?) kept[to] = moved;
  }
}

/// What a day looked like when it was set aside (#445): taken once, at the
/// skip, from what this device holds at that moment.
void main() {
  late _Store store;
  late Map<HealthMetric, List<HealthDailyValue>> health;
  late List<Object> errors;
  late SkipSnapshots snapshots;
  var sets = 12;

  // a Thursday morning, local
  final at = DateTime(2026, 11, 26, 7, 30);
  TrainingSkip skip([String? id = 's1']) => TrainingSkip(id: id, at: at.toUtc());

  setUp(() {
    store = _Store();
    errors = [];
    sets = 12;
    health = {
      .steps: [(day: DateTime(2026, 11, 25), value: 9000), (day: DateTime(2026, 11, 26), value: 1200)],
      .sleepAsleep: [(day: DateTime(2026, 11, 26), value: 395)],
      .restingHeartRate: [(day: DateTime(2026, 11, 24), value: 52)],
      // tracked, and nothing a skipped day is asked about
      .bodyMass: [(day: DateTime(2026, 11, 26), value: 80)],
    };
    snapshots = SkipSnapshots(
      store: store,
      trainingBefore: (at, userId) async {
        return SkipTraining(lastWorkoutAt: DateTime(2026, 11, 24, 18), setsWeek: sets, recovering: const {'chest'});
      },
      healthOf: (metric) => health[metric] ?? const [],
      onError: (error, {stacktrace}) => errors.add(error as Object),
    );
  });

  test('takes the training before the skip and the day in Health, as they stand', () async {
    await snapshots.take(skip(), 'user-1', now: at);

    final taken = await snapshots.read('s1');
    expect(taken?.takenAt, at);
    expect(taken?.training.setsWeek, 12);
    expect(taken?.training.recovering, {'chest'});
    expect(taken?.training.lastWorkoutAt, DateTime(2026, 11, 24, 18));
    // the day's own readings, of the metrics a skipped day is asked about
    expect(taken?.body, {HealthMetric.steps: 1200.0, HealthMetric.sleepAsleep: 395.0});
    expect(store.kept['s1']?.$1, 'user-1');
  });

  test('reads the same after the log and the day move on', () async {
    await snapshots.take(skip(), 'user-1', now: at);

    // a workout deleted, the steps of the rest of the day
    sets = 0;
    health[HealthMetric.steps] = [(day: DateTime(2026, 11, 26), value: 11000)];
    await snapshots.take(skip(), 'user-1', now: at.add(const Duration(hours: 9)));

    final taken = await snapshots.read('s1');
    expect(taken?.training.setsWeek, 12);
    expect(taken?.body[HealthMetric.steps], 1200.0);
  });

  test('a skip recorded on a later day leaves out the steps: they are no longer the day so far', () async {
    await snapshots.take(skip(), 'user-1', now: DateTime(2026, 11, 28, 8));

    final taken = await snapshots.read('s1');
    expect(taken?.body.keys, [HealthMetric.sleepAsleep]);
  });

  test('with nothing in Health the body is empty, and the training is kept', () async {
    health.clear();

    await snapshots.take(skip(), 'user-1', now: at);

    final taken = await snapshots.read('s1');
    expect(taken?.body, isEmpty);
    expect(taken?.training.setsWeek, 12);
  });

  test('taken back, it is gone; said again under a new id, it moves', () async {
    await snapshots.take(skip(), 'user-1', now: at);

    await snapshots.move('s1', 's2');
    expect(await snapshots.read('s1'), isNull);
    expect((await snapshots.read('s2'))?.training.setsWeek, 12);

    await snapshots.drop('s2');
    expect(await snapshots.read('s2'), isNull);
  });

  test('a skip with no id has nothing to keep one under', () async {
    await snapshots.take(skip(null), 'user-1', now: at);

    expect(store.kept, isEmpty);
  });

  test('a failure is reported, never thrown: the skip stands without a snapshot', () async {
    store.failing = true;

    await snapshots.take(skip(), 'user-1', now: at);
    expect(await snapshots.read('s1'), isNull);

    expect(errors, hasLength(2));
  });

  test('the training reads back from its row, and a row from a newer build costs nothing', () {
    const training = SkipTraining(lastWorkoutAt: null, setsWeek: 3, recovering: {'legs', 'core'});

    final back = SkipTraining.fromMap(training.toMap());
    expect((back.lastWorkoutAt, back.setsWeek), (null, 3));
    expect(back.recovering, {'legs', 'core'});

    final odd = SkipTraining.fromMap(const {'setsWeek': 'many', 'recovering': 7, 'later': true});
    expect((odd.lastWorkoutAt, odd.setsWeek), (null, 0));
    expect(odd.recovering, isEmpty);
  });
}
