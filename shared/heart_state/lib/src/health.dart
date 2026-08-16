import 'package:flutter/material.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

/// Health readings from the device, mirrored locally so charts can be drawn
/// offline and without re-reading the store on every rebuild.
///
/// **Nothing here is ever sent to a server.** There is deliberately no remote
/// service alongside [_local] — health data is device-only, the OS store is the
/// backup, and this mirror is disposable. See `docs/2026-08-02.wearables.md`.
class Health with ChangeNotifier implements SignOutStateSentry {
  /// The device's store — HealthKit or Health Connect.
  final HealthService _device;

  /// The local mirror. `LocalDatabase` in the app, a mock in tests.
  final HealthSampleStore _local;

  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// How stale the mirror has to be before a plain resume is worth a pass.
  ///
  /// A constructor argument only so tests can collapse it; nothing in the app
  /// passes it.
  final Duration resumeInterval;

  /// The floor the backfill walks down to. Defaults to [epoch]; a constructor
  /// argument only so tests can ask for a short walk instead of twelve years.
  final DateTime since;

  new({
    required this._device,
    required this._local,
    this.onError,
    this.resumeInterval = const Duration(minutes: 15),
    DateTime? since,
  }) : since = since ?? epoch;

  /// What we read. Deliberately small: every entry is a metric the app can
  /// actually show or reason about, and each one is a permission the user is
  /// asked to grant. Adding one is a product decision, not a technicality.
  static const tracked = <HealthMetric>{
    .restingHeartRate,
    .heartRateVariability,
    .sleepAsleep,
    .steps,
    .activeEnergy,
    .bodyMass,
  };

  /// How far back Heart will ever look.
  ///
  /// Everything the store has, in practice: HealthKit shipped with iOS 8 in
  /// September 2014 and Health Connect is younger, so nothing predates this.
  /// A floor rather than a window because the detail chart zooms out to years
  /// — capping the mirror at a year would make that control a lie.
  static final epoch = DateTime.utc(2014, 9);

  /// How much history one device read asks for at a time.
  ///
  /// The store answers with every sample in the window at once, in memory. A
  /// decade of step counts is hundreds of thousands of objects and would take
  /// the app down, so the walk is chunked — and each chunk is persisted before
  /// the next begins, which is also what makes an interrupted backfill
  /// resumable rather than restartable.
  static const _chunk = Duration(days: 90);

  static Health of(BuildContext context) => Provider.of<Health>(context, listen: false);

  static Health watch(BuildContext context) => Provider.of<Health>(context, listen: true);

  String? userId;

  final _daily = <HealthMetric, List<HealthDailyValue>>{};

  bool _initialized = false;

  bool get initialized => _initialized;

  HealthStoreStatus _status = HealthStoreStatus.unavailable;

  HealthStoreStatus get status => _status;

  bool _syncing = false;

  bool get syncing => _syncing;

  /// Whether this platform has a health store at all — false on web, where the
  /// whole feature should be absent rather than empty.
  bool get isSupported => _device.isSupported;

  /// The daily series for [metric], oldest first. Empty until [init] has run.
  List<HealthDailyValue> operator [](HealthMetric metric) => _daily[metric] ?? const [];

  /// Whether anything at all was read.
  ///
  /// **This, not a permission check, is what the UI should branch on.** iOS
  /// will not disclose whether read access was granted — see [HealthAccess.unknown]
  /// — so "connected" is unknowable, while "we have data" is a fact. It also
  /// collapses the two cases that should look identical to a user: permission
  /// declined, and permission granted but the store is empty.
  bool get hasData => _daily.values.any((series) => series.isNotEmpty);

  /// Metrics with at least one day of data, in [tracked] order.
  Iterable<HealthMetric> get available {
    return tracked.where((metric) => (_daily[metric] ?? const []).isNotEmpty);
  }

  /// Whether the provider that owns this notifier has been torn down.
  ///
  /// Nothing here is awaited by the app — [init] is fired and forgotten on the
  /// start-up path, and the backfill it kicks off can run for minutes. A widget
  /// test that pumps a screen and moves on disposes the provider underneath all
  /// of that, and `notifyListeners` on a disposed `ChangeNotifier` throws —
  /// which in `flutter test` takes the whole shell process down, not just the
  /// one test.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [notifyListeners], unless nobody is listening any more.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void onSignOut() {
    userId = null;
    _daily.clear();
    _initialized = false;
    _syncing = false;
    _syncedAt = null;
    _leftForPermissions = false;
  }

  /// Loads whatever is already mirrored, then tops it up from the device.
  ///
  /// Local first so a chart paints immediately on launch; the device read is
  /// the slow part and lands after. Safe to call when access was never granted
  /// — the read simply returns nothing.
  Future<void> init() async {
    if (userId == null) return;

    // Runs on the start-up path alongside the other local initializers, so it
    // swallows its own failures: a health store that cannot be reached is a
    // feature that renders empty, never a launch that dies.
    try {
      _status = await _device.status();
      await _loadLocal();
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }

    _initialized = true;
    _notify();

    await sync();
  }

  /// Shows the OS permission sheet, then syncs.
  ///
  /// The returned bool says only that the sheet was presented — on iOS it is
  /// not an answer about access. Callers should look at [hasData] afterwards
  /// rather than trusting it.
  Future<bool> connect() async {
    final asked = await _device.requestAccess(tracked);

    // A second, separate prompt on Android: without it every read stops 30 days
    // back, however far the backfill walks. Declining is survivable, so its
    // answer does not change ours.
    await _device.requestHistoryAccess();

    // Re-read the status rather than trusting the one taken at launch. If that
    // check threw, [_status] is stuck at its `unavailable` default and [sync]
    // returns early forever — and outside Android's [openInstaller] there is
    // nothing else that would ever reopen the gate.
    _status = await _device.status();

    // Everything already walked was walked under the old answer. A backfill
    // that ran while access was denied read nothing and recorded that it had
    // searched the whole history — true, and worthless now: without this the
    // walk would never run again and years of history would stay invisible
    // behind a permission the user has just granted.
    if (userId case String id) {
      await _local.clearHealthBackfill(id);
    }

    // The first sync walks years across every tracked metric, so the sheet is
    // routinely answered while it is still running. Join that pass rather than
    // racing it, then run a fresh one: the windows it already read were read
    // before consent existed, so its results say nothing about what the user
    // just granted.
    await _inFlight;
    await sync();

    return asked;
  }

  /// Reads everything recorded since the last sample we hold, per metric.
  ///
  /// Each metric carries its own watermark because they arrive at wildly
  /// different rates — steps every few minutes, body mass when the user
  /// remembers the scale. One shared watermark would either re-read steps
  /// constantly or never notice a new weigh-in.
  ///
  /// The window deliberately overlaps the last known sample: the store can
  /// backfill a reading behind the watermark once a watch syncs. Overlap is
  /// free because rows collide on the platform's sample UUID.
  Future<void> sync() {
    if (userId == null) return Future.value();
    if (_status != .available) return Future.value();

    // Concurrent callers join the pass already running instead of starting a
    // second one over the same windows. [connect] is the one caller that needs
    // a genuinely fresh read, and it awaits [_inFlight] first to get one.
    return _inFlight ??= _sync().whenComplete(() => _inFlight = null);
  }

  /// The return leg of a permissions trip.
  ///
  /// Asks for history access before reading, because the trip may well have
  /// been the user granting the six data permissions in the platform's own
  /// settings — a route that never passes through [connect], and so would leave
  /// them capped at 30 days of history for good.
  ///
  /// Then forgets how far back each metric has been walked, for the same reason
  /// [connect] does and one more: a walk that ran *before* history access was
  /// granted saw only the last 30 days, found nothing older, and recorded the
  /// whole history as searched. Proved on a Pixel 7 — permissions granted, the
  /// walk already complete, and a store that would have stayed empty forever.
  Future<void> _resync() async {
    await _device.requestHistoryAccess();
    if (userId case String id) {
      await _local.clearHealthBackfill(id);
    }
    await sync();
  }

  Future<void>? _inFlight;

  /// When a pass last finished, whatever it found. Drives the resume throttle.
  DateTime? _syncedAt;

  /// Whether the user was last seen leaving for the platform's permission UI.
  bool _leftForPermissions = false;

  /// The app came back to the foreground.
  ///
  /// The reason this exists: changing health permissions means leaving Heart
  /// for the platform's own UI, and nothing tells us what happened out there —
  /// iOS will not disclose read access even after the fact (see
  /// [HealthAccess.unknown]). Coming back is the only moment we can act on, and
  /// re-reading is the only way to find out. Without it a user grants access,
  /// returns, and sees the same empty card that sent them away.
  ///
  /// It also picks up plain staleness: an app left in the background over a
  /// weekend comes forward showing Friday.
  Future<void> onResume() {
    // The trip out never waits its turn. It is the one case where the answer
    // genuinely may have changed, and the user came back to look at the result.
    if (_leftForPermissions) {
      _leftForPermissions = false;
      return _resync();
    }

    return switch (_syncedAt) {
      // Alt-tabbing is not new data. Re-reading six metrics every time the app
      // comes forward costs a platform round trip each and finds nothing.
      DateTime at when DateTime.now().difference(at) < resumeInterval => Future.value(),
      _ => sync(),
    };
  }

  Future<void> _sync() async {
    _syncing = true;
    _notify();

    try {
      final now = DateTime.now();

      // Recent first, every metric, before anything walks backwards. A first
      // run against years of history takes minutes; this way the dashboard
      // fills in seconds and the past arrives behind it.
      for (final metric in tracked) {
        final last = await _local.lastHealthSampleAt(userId: userId!, metric: metric);
        final from = last?.subtract(const Duration(days: 1)) ?? now.subtract(_chunk);
        await _read(metric, from: from, to: now);
      }

      await _loadLocal();
      _notify();

      await _backfill(until: now);
    } catch (error, stacktrace) {
      // Reported without the samples themselves — see the note on onError in
      // the app's wiring. A failed sync is not worth surfacing to the user:
      // the charts simply show what was already mirrored.
      onError?.call(error, stacktrace: stacktrace);
    } finally {
      _syncing = false;
      // Stamped even on a failed pass: the throttle is about how recently we
      // asked the store, not about how much came back.
      _syncedAt = DateTime.now();
      _notify();
    }
  }

  /// Reads `[from, to)` from the device in [_chunk]-sized windows, newest
  /// first, storing each as it lands.
  Future<void> _read(HealthMetric metric, {required DateTime from, required DateTime to}) async {
    var end = to;
    while (!_disposed && end.isAfter(from)) {
      final start = switch (end.subtract(_chunk)) {
        DateTime candidate when candidate.isBefore(from) => from,
        DateTime candidate => candidate,
      };

      final samples = await _device.read(metrics: {metric}, from: start, to: end);
      if (samples.isNotEmpty) {
        await _local.storeHealthSamples(samples, userId!);
      }

      end = start;
    }
  }

  /// Walks every metric backwards to [since], a chunk at a time, remembering
  /// how far each got.
  ///
  /// All six advance together rather than one being finished before the next
  /// begins. Depth is visible — it is the range of the chart — and a walk that
  /// completed resting heart rate before it started body mass would show three
  /// years of one beside three months of the other, which reads as broken data
  /// rather than as an unfinished read.
  ///
  /// The markers are what stop this being work repeated forever. Someone whose
  /// history starts last September would otherwise have eleven empty years
  /// re-read on every launch, because "we found nothing there" and "we never
  /// looked" are the same answer from a query.
  Future<void> _backfill({required DateTime until}) async {
    final floors = {
      for (final metric in tracked) metric: await _local.healthBackfilledTo(userId: userId!, metric: metric) ?? until,
    };

    while (!_disposed && floors.values.any((floor) => floor.isAfter(since))) {
      for (final metric in tracked) {
        if (_disposed) return;
        final floor = floors[metric]!;
        if (!floor.isAfter(since)) continue;

        final start = switch (floor.subtract(_chunk)) {
          DateTime candidate when candidate.isBefore(since) => since,
          DateTime candidate => candidate,
        };

        final samples = await _device.read(metrics: {metric}, from: start, to: floor);
        if (samples.isNotEmpty) {
          await _local.storeHealthSamples(samples, userId!);
        }

        floors[metric] = start;
        await _local.setHealthBackfilledTo(start, userId: userId!, metric: metric);
      }

      // One reload per round, not per chunk: the charts deepen evenly as the
      // walk runs instead of jumping a metric at a time.
      await _loadLocal();
      _notify();
    }
  }

  Future<void> _loadLocal() async {
    if (userId case String id) {
      final now = DateTime.now();

      for (final metric in tracked) {
        _daily[metric] = await _local.getDailyHealth(userId: id, metric: metric, from: since, to: now);
      }
    }
  }

  /// Erases every mirrored sample and forgets it in memory.
  ///
  /// The whole delete — there is no server copy to chase, which is the point of
  /// the device-only decision. Backs a user-facing "forget my health data";
  /// the OS store is untouched, so a later [sync] would rebuild the mirror.
  ///
  /// **Revoking a permission deliberately does not come here.** iOS never
  /// reports a revocation — reads simply stop returning anything — so "they
  /// turned it off" is indistinguishable from "they haven't worn the watch".
  /// Deleting on that signal would throw away a year of history because someone
  /// spent a weekend off their wrist. Erasing stays where the user put the
  /// intent: this, and sign-out.
  Future<void> forget() async {
    if (userId case String id) {
      await _local.deleteHealthSamples(id);
      // The progress markers go with the samples. Left behind they would claim
      // the history had already been walked, and the rebuild this delete
      // promises would fetch only the last ninety days.
      await _local.clearHealthBackfill(id);
    }
    _daily.clear();
    _notify();
  }

  /// Sends the user to install or update Health Connect. Android only.
  Future<void> openInstaller() async {
    await _device.openInstaller();
    _status = await _device.status();
    _notify();
  }

  /// Sends the user where this platform keeps health permissions — on iOS the
  /// Health app, not Settings › Heart. False means there was nowhere to send
  /// them and the caller should fall back; see [HealthService.openPermissions].
  ///
  /// Either way the user is about to leave, so [onResume] is armed regardless
  /// of the answer: the fallback lands them somewhere they can change their
  /// mind too.
  Future<bool> openPermissions() {
    _leftForPermissions = true;
    return _device.openPermissions();
  }
}
