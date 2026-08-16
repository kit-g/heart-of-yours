import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_state/src/health.dart';
import 'package:provider/provider.dart';

import 'test_utils.dart';

void main() {
  late _FakeDevice device;
  late _FakeStore store;
  late List<Object> errors;
  late Health sut;

  const userId = 'user-123';

  /// Every metric [Health] reads, in the order it reads them.
  final tracked = Health.tracked.toList();

  void build() {
    errors = [];
    device = _FakeDevice();
    store = _FakeStore();
    sut = Health(
      device: device,
      local: store,
      onError: (error, {stacktrace}) => errors.add(error),
      // A short floor: these tests are about what the walk does, not how far it
      // goes, and the real epoch is a twelve-year walk in every single one.
      since: DateTime.utc(2026, 5),
    )..userId = userId;
  }

  setUp(build);

  group('init', () {
    test('paints from the local mirror before reading the device', () async {
      store.daily[HealthMetric.restingHeartRate] = [
        (day: DateTime(2026, 7, 1), value: 61),
        (day: DateTime(2026, 7, 2), value: 60),
      ];

      final probe = ListenerProbe()..attach(sut);
      await sut.init();

      expect(sut.initialized, isTrue);
      expect(sut[HealthMetric.restingHeartRate], hasLength(2));
      expect(sut.hasData, isTrue);
      expect(probe.notifications, greaterThan(0));

      // The mirror is what makes a chart paint on launch, so it has to be read
      // before the slow device round-trip, not after it.
      expect(
        store.log.first,
        'getDailyHealth',
        reason: 'the local mirror must be loaded before the device is touched',
      );
      expect(device.log, contains('read'));
    });

    test('does nothing without a user', () async {
      sut.userId = null;

      await sut.init();

      expect(sut.initialized, isFalse);
      expect(device.log, isEmpty);
      expect(store.log, isEmpty);
    });

    test('survives a store that throws and still finishes initializing', () async {
      store.loadError = StateError('no such table: health_samples');

      await sut.init();

      expect(sut.initialized, isTrue, reason: 'a broken health store is an empty feature, never a dead launch');
      expect(errors, everyElement(isStateError));

      // Twice, not once: `init` catches the failed mirror load, then the `sync`
      // it kicks off reloads the mirror and trips over the same thing. One
      // broken table is two Sentry events per launch.
      expect(errors, hasLength(2));
    });
  });

  group('sync', () {
    test('reads each metric from its own watermark, overlapping by a day', () async {
      final lastStep = DateTime(2026, 7, 30, 14, 20);
      store.watermarks[HealthMetric.steps] = lastStep;

      await sut.init();

      final steps = device.readsFor(HealthMetric.steps).first;
      expect(
        steps.from,
        lastStep.subtract(const Duration(days: 1)),
        reason: 'the window overlaps the watermark so a late watch sync is not missed',
      );

      // Metrics arrive at wildly different rates, so a watermark is per-metric.
      // Body mass has never been recorded here, so it opens on a recent chunk
      // and the rest of its history arrives behind that.
      final mass = device.readsFor(HealthMetric.bodyMass).first;
      expect(mass.to.difference(mass.from).inDays, 90);
    });

    test('reads one metric at a time, never the whole set at once', () async {
      await sut.init();

      expect(device.reads, isNotEmpty);
      for (final read in device.reads) {
        expect(read.metrics, hasLength(1));
      }
    });

    // Minutes, on a first run against years of history. Reading the recent
    // window for everything first is what puts numbers on the dashboard in
    // seconds and leaves the past to arrive behind them.
    test('reads the recent window for every metric before walking backwards', () async {
      await sut.init();

      final firstSix = device.reads.take(tracked.length).map((read) => read.metrics.single);
      expect(firstSix, containsAll(tracked));
    });

    test('stores what came back and reloads the mirror', () async {
      device.samples = [_sample('a', HealthMetric.steps, 900)];

      await sut.init();

      expect(store.stored, isNotEmpty);
      expect(store.log, contains('getDailyHealth'));
    });

    test('skips the write when a metric returned nothing', () async {
      await sut.init();

      expect(store.log, isNot(contains('storeHealthSamples')));
    });

    test('reports a failed read without surfacing it, keeping the mirror intact', () async {
      store.daily[HealthMetric.steps] = [(day: DateTime(2026, 7, 1), value: 8000)];
      device.readError = StateError('health store went away');

      await sut.init();

      expect(errors, hasLength(1));
      expect(sut[HealthMetric.steps], hasLength(1), reason: 'a failed sync shows what was already mirrored');
      expect(sut.syncing, isFalse);
    });

    test('does not run while the store is unavailable', () async {
      device.storeStatus = HealthStoreStatus.unavailable;

      await sut.init();

      expect(device.reads, isEmpty);
    });
  });

  group('hasData', () {
    // iOS will not disclose read permission, so "declined" and "granted but the
    // user owns no watch" are the same observable state. Both must land here.
    test('is false when nothing came back, however that happened', () async {
      await sut.init();

      expect(sut.hasData, isFalse);
      expect(sut.available, isEmpty);
      expect(sut[HealthMetric.restingHeartRate], isEmpty);
    });

    test('lists only the metrics that actually have days, in tracked order', () async {
      store.daily[HealthMetric.bodyMass] = [(day: DateTime(2026, 7, 1), value: 80)];
      store.daily[HealthMetric.restingHeartRate] = [(day: DateTime(2026, 7, 1), value: 61)];

      await sut.init();

      expect(sut.available, [HealthMetric.restingHeartRate, HealthMetric.bodyMass]);
    });
  });

  group('forget', () {
    test('erases the mirror and leaves the OS store to refill it', () async {
      store.daily[HealthMetric.steps] = [(day: DateTime(2026, 7, 1), value: 8000)];
      store.watermarks[HealthMetric.steps] = DateTime(2026, 7, 1);
      await sut.init();
      expect(sut.hasData, isTrue);

      final probe = ListenerProbe()..attach(sut);
      await sut.forget();

      expect(store.deleted, [userId]);
      expect(sut.hasData, isFalse);
      expect(probe.notifications, 1);

      // The watermark went with the samples, so the next sync backfills a full
      // year rather than picking up where the deleted rows left off.
      device.reads.clear();
      await sut.sync();
      expect(
        device.readsFor(HealthMetric.steps).first.to.difference(device.readsFor(HealthMetric.steps).first.from).inDays,
        90,
      );
    });
  });

  group('onSignOut', () {
    test('drops the user and everything read for them', () async {
      store.daily[HealthMetric.steps] = [(day: DateTime(2026, 7, 1), value: 8000)];
      await sut.init();

      sut.onSignOut();

      expect(sut.userId, isNull);
      expect(sut.hasData, isFalse);
      expect(sut.initialized, isFalse);
      expect(sut.syncing, isFalse);
    });
  });

  group('openInstaller', () {
    test('re-reads the status afterwards, since the user may have fixed it', () async {
      device.storeStatus = HealthStoreStatus.unavailable;
      await sut.init();
      expect(sut.status, HealthStoreStatus.unavailable);

      device.storeStatus = HealthStoreStatus.available;
      final probe = ListenerProbe()..attach(sut);
      await sut.openInstaller();

      expect(sut.status, HealthStoreStatus.available);
      expect(probe.notifications, 1);
    });
  });

  // Nothing here is awaited by the app: `init` is fired and forgotten, and the
  // backfill it starts can run for minutes. A widget test that pumps a screen
  // and moves on disposes the provider underneath all of it, and notifying a
  // disposed ChangeNotifier throws — which in `flutter test` takes the whole
  // shell process down rather than one test.
  group('disposal', () {
    test('a sync still in flight neither notifies nor keeps reading', () async {
      device.gateFirstRead();
      final syncing = sut.init();
      await pumpEventQueue();

      sut.dispose();
      device.releaseGate();
      await syncing;

      expect(errors, isEmpty, reason: 'notifying a disposed notifier would have thrown');
      // The walk stops rather than reading chunk after chunk for a screen that
      // is gone.
      final reads = device.reads.length;
      await pumpEventQueue();
      expect(device.reads, hasLength(reads));
    });
  });

  group('openPermissions', () {
    // Straight through, and it stays that way: only the device knows where its
    // permissions live, and the UI must not be tempted to guess.
    test('is the device answering', () async {
      expect(await sut.openPermissions(), isTrue);
      expect(device.log, contains('openPermissions'));

      device.permissionsReachable = false;
      expect(await sut.openPermissions(), isFalse);
    });
  });

  group('onResume', () {
    // The whole point: permissions are granted in another app, and coming back
    // is the only moment we get. Without this the user grants access, returns,
    // and is looking at the same empty card that sent them away.
    test('a return from the permission trip re-reads, however recent the last pass', () async {
      await sut.init();
      device.reads.clear();

      await sut.openPermissions();
      await sut.onResume();

      expect(device.reads.map((read) => read.metrics.single), containsAll(tracked));
    });

    // Including when there was nowhere to send them: the fallback lands the
    // user on a page they can still change their mind from.
    test('arms even when the platform had nowhere to send them', () async {
      await sut.init();
      device.reads.clear();
      device.permissionsReachable = false;

      await sut.openPermissions();
      await sut.onResume();

      expect(device.reads.map((read) => read.metrics.single), containsAll(tracked));
    });

    test('an ordinary resume soon after a sync reads nothing', () async {
      await sut.init();
      device.reads.clear();

      await sut.onResume();

      expect(device.reads, isEmpty, reason: 'alt-tabbing is not new data');
    });

    test('an ordinary resume picks up staleness once the mirror has aged', () async {
      sut = Health(device: device, local: store, resumeInterval: Duration.zero)..userId = userId;
      await sut.init();
      device.reads.clear();

      await sut.onResume();

      expect(device.reads.map((read) => read.metrics.single), containsAll(tracked));
    });

    // Nothing has been read for anyone yet, so there is no recent pass to
    // throttle against — and [sync] itself is what declines to run.
    test('is harmless before anything has been read', () async {
      await sut.onResume();

      expect(device.reads, isEmpty);
      expect(errors, isEmpty);
    });
  });

  group('backfill', () {
    // The whole point of going unbounded: the detail chart zooms out to years,
    // and a mirror capped at a year would make that control a lie.
    test('walks back to the floor and remembers getting there', () async {
      await sut.init();

      final steps = device.readsFor(HealthMetric.steps);
      expect(steps.map((read) => read.from).reduce((a, b) => a.isBefore(b) ? a : b), sut.since);
      expect(store.backfilled[(userId, HealthMetric.steps)], sut.since);
    });

    // A first run against a decade takes minutes, and users close apps. Losing
    // that work would mean starting the decade again on the next launch.
    test('resumes from where it stopped rather than starting over', () async {
      final floor = DateTime.utc(2026, 6);
      for (final metric in tracked) {
        store.backfilled[(userId, metric)] = floor;
      }

      await sut.init();

      final earliest = device
          .readsFor(HealthMetric.steps)
          .map((read) => read.from)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      expect(earliest, sut.since);
      expect(
        device.readsFor(HealthMetric.steps).every((read) => !read.to.isAfter(floor) || read.to.isAfter(floor)),
        isTrue,
      );
      // Nothing above the marker was walked a second time.
      expect(
        device.readsFor(HealthMetric.steps).where((read) => read.from.isBefore(floor)),
        isNotEmpty,
      );
    });

    // Depth is visible — it is the range of the chart. Finishing one metric
    // before starting the next would show three years of resting heart rate
    // beside three months of body mass, which reads as broken data rather than
    // as a read that has not finished.
    test('deepens every metric together rather than one at a time', () async {
      await sut.init();

      final depths = {
        for (final metric in tracked)
          metric: device.readsFor(metric).map((read) => read.from).reduce((a, b) => a.isBefore(b) ? a : b),
      };
      expect(depths.values.toSet(), hasLength(1), reason: 'the six walked in step');
    });

    // The trap this device actually fell into: the walk completed while history
    // access was denied, so it saw 30 days, found nothing older, and recorded
    // the whole history as searched. Granting afterwards has to re-open it.
    test('re-opens the history after a permissions trip, not just after connect', () async {
      await sut.init();
      expect(store.backfilled[(userId, HealthMetric.steps)], sut.since, reason: 'the first walk finished');

      device.reads.clear();
      await sut.openPermissions();
      await sut.onResume();

      expect(device.readsFor(HealthMetric.steps).map((read) => read.from), contains(sut.since));
    });

    // Android's second prompt. Without it every read stops 30 days back however
    // far the walk goes, and the route that skips `connect` entirely — granting
    // in the platform's own settings — would cap a user there for good.
    test('asks for history access on both routes into permission', () async {
      await sut.init();
      expect(device.historyRequests, 0, reason: 'a plain launch must not prompt');

      await sut.connect();
      expect(device.historyRequests, 1);

      await sut.openPermissions();
      await sut.onResume();
      expect(device.historyRequests, 2, reason: 'the settings route never passes through connect');
    });

    // The flip side of the marker, and the case that makes it dangerous: a walk
    // that ran while access was denied read nothing and recorded that it had
    // searched everything. Perfectly true, and worthless the moment the user
    // grants access — without this the history would stay invisible forever.
    test('is walked again after the user answers the permission sheet', () async {
      await sut.init();
      expect(store.backfilled[(userId, HealthMetric.steps)], sut.since, reason: 'the first walk finished');

      device.reads.clear();
      await sut.connect();

      expect(
        device.readsFor(HealthMetric.steps).map((read) => read.from),
        contains(sut.since),
        reason: 'granting access has to re-open the history, not just the last window',
      );
    });

    // Same trap, other door: the markers have to go with the samples, or the
    // rebuild this delete promises fetches only the most recent window.
    test('is walked again after the local copy is deleted', () async {
      await sut.init();
      await sut.forget();

      expect(store.backfilled, isEmpty);

      device.reads.clear();
      await sut.sync();

      expect(device.readsFor(HealthMetric.steps).map((read) => read.from), contains(sut.since));
    });

    // "We found nothing there" and "we never looked" are the same thing to a
    // query, so without the marker a user with no old data re-reads years of
    // nothing on every single launch.
    test('does not walk the same empty years twice', () async {
      await sut.init();
      final first = device.reads.length;

      device.reads.clear();
      await sut.sync();

      expect(device.reads.length, lessThan(first), reason: 'the floor was already reached');
      expect(device.reads.map((read) => read.metrics.single), containsAll(tracked));
    });
  });

  group('connect', () {
    test('shows the sheet and syncs', () async {
      await sut.init();
      device.reads.clear();

      final asked = await sut.connect();

      expect(asked, isTrue);
      expect(device.requestAccessCalls, 1);
      expect(device.reads.map((read) => read.metrics.single), containsAll(tracked));
    });

    test('syncs even when the launch sync is still in flight', () async {
      // The first sync backfills a year across six metrics, so a user who taps
      // connect while it runs is the normal case, not a race. Whatever they just
      // granted has to be read — `sync`'s reentrancy guard must not swallow it.
      device.gateFirstRead();
      final launch = sut.init();
      await pumpEventQueue();

      // The tap lands mid-backfill. Connect must not be awaited before the
      // launch pass is let go, because a correct connect waits for it.
      final connecting = sut.connect();
      await pumpEventQueue();
      device.releaseGate();

      final asked = await connecting;
      await launch;

      expect(asked, isTrue);
      expect(
        device.reads.length,
        greaterThanOrEqualTo(tracked.length * 2),
        reason: 'connect() must read after the permission sheet, not drop its sync',
      );
    });

    test('recovers when the launch status check failed', () async {
      // `status()` is only read on launch and by openInstaller, which is Android
      // only. If it throws once on iOS, `_status` is stuck at its `unavailable`
      // default and the sync gate never opens again for the whole session —
      // connect() is the user's only remaining move and it must work.
      device.statusError = StateError('transient');
      await sut.init();
      expect(errors, hasLength(1));

      device.statusError = null;
      await sut.connect();

      expect(device.reads, isNotEmpty, reason: 'a one-off status failure must not disable the feature for the session');
    });
  });

  group('providers', () {
    testWidgets('of() and watch() resolve the same instance', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<Health>.value(
          value: sut,
          child: Builder(
            builder: (context) {
              expect(identical(Health.of(context), sut), isTrue);
              expect(identical(Health.watch(context), sut), isTrue);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}

HealthSample _sample(String id, HealthMetric metric, double value) {
  final start = DateTime(2026, 7, 30, 9);
  return HealthSample(
    id: id,
    metric: metric,
    value: value,
    start: start,
    end: start.add(const Duration(minutes: 5)),
    source: const HealthSource(id: 'com.apple.health', name: 'Health', deviceModel: 'Apple Watch'),
  );
}

typedef _Read = ({Set<HealthMetric> metrics, DateTime from, DateTime to});

/// A health store we can stall, break and reprogram mid-test — none of which
/// mockito expresses comfortably, and the reentrancy tests need all three.
class _FakeDevice implements HealthService {
  final log = <String>[];
  final reads = <_Read>[];

  HealthStoreStatus storeStatus = HealthStoreStatus.available;
  Object? statusError;
  Object? readError;
  List<HealthSample> samples = const [];
  int requestAccessCalls = 0;
  int openInstallerCalls = 0;

  Completer<void>? _gate;
  var _gateUsed = false;

  /// Holds the next [read] open until [releaseGate].
  void gateFirstRead() {
    _gate = Completer<void>();
    _gateUsed = false;
  }

  void releaseGate() {
    if (_gate case Completer<void> gate when !gate.isCompleted) gate.complete();
  }

  List<_Read> readsFor(HealthMetric metric) {
    return reads.where((read) => read.metrics.contains(metric)).toList();
  }

  @override
  bool get isSupported => true;

  @override
  Future<HealthStoreStatus> status() async {
    log.add('status');
    if (statusError case Object error) throw error;
    return storeStatus;
  }

  @override
  Future<HealthAccess> access(Set<HealthMetric> metrics) async => HealthAccess.unknown;

  @override
  Future<bool> requestAccess(Set<HealthMetric> metrics) async {
    log.add('requestAccess');
    requestAccessCalls++;
    return true;
  }

  @override
  Future<List<HealthSample>> read({
    required Set<HealthMetric> metrics,
    required DateTime from,
    required DateTime to,
  }) async {
    log.add('read');
    reads.add((metrics: metrics, from: from, to: to));

    // Only the first read stalls; the rest of the pass runs normally, so a test
    // can hold a sync open without freezing everything behind it.
    if (_gate case Completer<void> gate when !_gateUsed) {
      _gateUsed = true;
      await gate.future;
    }

    if (readError case Object error) throw error;
    return samples.where((sample) => metrics.contains(sample.metric)).toList();
  }

  int historyRequests = 0;
  bool historyReachable = true;

  @override
  Future<bool> requestHistoryAccess() async {
    log.add('requestHistoryAccess');
    historyRequests++;
    return historyReachable;
  }

  @override
  Future<void> openInstaller() async {
    log.add('openInstaller');
    openInstallerCalls++;
  }

  bool permissionsReachable = true;

  @override
  Future<bool> openPermissions() async {
    log.add('openPermissions');
    return permissionsReachable;
  }
}

class _FakeStore implements HealthSampleStore {
  final log = <String>[];
  final stored = <HealthSample>[];
  final deleted = <String>[];
  final watermarks = <HealthMetric, DateTime>{};
  final daily = <HealthMetric, List<HealthDailyValue>>{};

  Object? loadError;

  @override
  Future<void> storeHealthSamples(Iterable<HealthSample> samples, String userId) async {
    log.add('storeHealthSamples');
    stored.addAll(samples);
  }

  @override
  Future<List<HealthSample>> getHealthSamples({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async {
    log.add('getHealthSamples');
    return stored.where((sample) => sample.metric == metric).toList();
  }

  @override
  Future<DateTime?> lastHealthSampleAt({
    required String userId,
    required HealthMetric metric,
  }) async {
    log.add('lastHealthSampleAt');
    return watermarks[metric];
  }

  @override
  Future<List<HealthDailyValue>> getDailyHealth({
    required String userId,
    required HealthMetric metric,
    required DateTime from,
    required DateTime to,
  }) async {
    log.add('getDailyHealth');
    if (loadError case Object error) throw error;
    return daily[metric] ?? const [];
  }

  final backfilled = <(String, HealthMetric), DateTime>{};

  @override
  Future<DateTime?> healthBackfilledTo({required String userId, required HealthMetric metric}) async {
    return backfilled[(userId, metric)];
  }

  @override
  Future<void> setHealthBackfilledTo(DateTime at, {required String userId, required HealthMetric metric}) async {
    backfilled[(userId, metric)] = at;
  }

  @override
  Future<void> clearHealthBackfill(String userId) async {
    backfilled.removeWhere((key, _) => key.$1 == userId);
  }

  @override
  Future<void> deleteHealthSamples(String userId) async {
    log.add('deleteHealthSamples');
    deleted.add(userId);
    stored.clear();
    watermarks.clear();
    daily.clear();
  }
}
