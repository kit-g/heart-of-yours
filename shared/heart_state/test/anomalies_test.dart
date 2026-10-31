import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';

/// A mirror in memory, keeping a decision unsynced the way the database does.
class _Mirror implements LocalAnomalyService {
  final rows = <String, Anomaly>{};
  final unsynced = <String>{};

  @override
  Future<List<Anomaly>> getAnomalies(String userId) async {
    return rows.values.toList()..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
  }

  @override
  Future<List<Anomaly>> unsyncedAnomalies(String userId) async => [for (final id in unsynced) rows[id]!];

  @override
  Future<void> storeAnomalies(Iterable<Anomaly> anomalies, String userId) async {
    final owed = {for (final id in unsynced) id: rows[id]!};
    rows
      ..clear()
      ..addEntries(anomalies.map((each) => MapEntry(each.id, owed[each.id] ?? each)));
    unsynced.retainWhere(rows.containsKey);
  }

  @override
  Future<void> storeAnomaly(Anomaly anomaly, String userId) async {
    rows[anomaly.id] = anomaly;
    unsynced.remove(anomaly.id);
  }

  @override
  Future<void> resolveAnomaly(String anomalyId, AnomalyStatus status, {required DateTime at}) async {
    rows[anomalyId] = _anomaly(anomalyId, setId: rows[anomalyId]!.setId, status: status.value);
    unsynced.add(anomalyId);
  }
}

Anomaly _anomaly(String id, {String? setId = 's1', String status = 'pending', int day = 2}) {
  return Anomaly.fromJson({
    'id': id,
    'workoutId': 'w1',
    'setId': ?setId,
    'reason': switch (setId) {
      String _ => 'outlier_weight',
      null => 'duration_left_running',
    },
    'observed': {'weight': 630, 'reps': 5},
    'status': status,
    'detectedAt': DateTime.utc(2026, 10, day).toIso8601String(),
  });
}

void main() {
  late _Mirror mirror;
  late MockAnomalyService remote;
  late RemoteAccess access;
  late Anomalies anomalies;

  setUp(() {
    mirror = _Mirror();
    remote = MockAnomalyService();
    access = RemoteAccess();
    anomalies = Anomalies(service: mirror, remoteService: remote, remote: access)..userId = 'muffin';
  });

  void serve(List<List<Anomaly>> pages) {
    for (final (index, page) in pages.indexed) {
      final cursor = index == 0 ? null : pages[index - 1].last.id;
      when(
        remote.getAnomalies(userId: 'muffin', cursor: cursor, limit: anyNamed('limit')),
      ).thenAnswer((_) async => Page(items: page, hasMore: index < pages.length - 1));
    }
  }

  test('init reads every page of the server\'s list into the mirror', () async {
    serve([
      [_anomaly('a3', setId: 's3', day: 4), _anomaly('a2', setId: 's2', day: 3)],
      [_anomaly('a1', setId: null)],
    ]);

    await anomalies.init();

    expect(anomalies.map((each) => each.id), ['a3', 'a2', 'a1']);
    expect(anomalies.ofSet('s2')?.id, 'a2');
    expect(anomalies.durationOf('w1')?.id, 'a1');
    expect(anomalies.pending, hasLength(3));
  });

  test('a decision lands at once, goes up, and counts the entry out', () async {
    serve([
      [_anomaly('a1'), _anomaly('a2', setId: null)],
    ]);
    await anomalies.init();
    when(
      remote.resolveAnomaly(userId: 'muffin', anomalyId: 'a1', status: AnomalyStatus.invalid),
    ).thenAnswer((_) async => _anomaly('a1', status: 'invalid'));

    await anomalies.resolve(anomalies.ofSet('s1')!, .invalid);
    await anomalies.resolve(anomalies.durationOf('w1')!, .invalid);

    expect(anomalies.discardedSets, {'s1'});
    expect(anomalies.discardedDurations, {'w1'});
    expect(mirror.unsynced, {'a2'}, reason: 'the server forgot a2: nothing answered it');
  });

  test('with the remote leg closed a decision waits, and goes up with the next pull', () async {
    serve([
      [_anomaly('a1')],
    ]);
    await anomalies.init();
    access.account = false;

    await anomalies.resolve(anomalies.single, .valid);
    verifyNever(
      remote.resolveAnomaly(userId: anyNamed('userId'), anomalyId: anyNamed('anomalyId'), status: anyNamed('status')),
    );
    expect(anomalies.single.status, AnomalyStatus.valid);

    access.account = true;
    when(
      remote.resolveAnomaly(userId: 'muffin', anomalyId: 'a1', status: AnomalyStatus.valid),
    ).thenAnswer((_) async => _anomaly('a1', status: 'valid'));
    serve([
      [_anomaly('a1', status: 'valid')],
    ]);
    await anomalies.pull();

    expect(mirror.unsynced, isEmpty);
    expect(anomalies.single.status, AnomalyStatus.valid);
  });

  test('a decision can be changed', () async {
    serve([
      [_anomaly('a1')],
    ]);
    await anomalies.init();
    when(
      remote.resolveAnomaly(userId: 'muffin', anomalyId: 'a1', status: anyNamed('status')),
    ).thenAnswer(
      (invocation) async => _anomaly('a1', status: (invocation.namedArguments[#status] as AnomalyStatus).value),
    );

    await anomalies.resolve(anomalies.single, .invalid);
    await anomalies.resolve(anomalies.single, .valid);

    expect(anomalies.single.status, AnomalyStatus.valid);
    expect(anomalies.discardedSets, isEmpty);
  });

  test('sign-out forgets them', () async {
    serve([
      [_anomaly('a1')],
    ]);
    await anomalies.init();

    anomalies.onSignOut();

    expect(anomalies, isEmpty);
    expect(anomalies.ofSet('s1'), isNull);
  });
}
