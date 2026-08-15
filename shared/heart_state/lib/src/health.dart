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

  new({
    required this._device,
    required this._local,
    this.onError,
  });

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

  /// How far back the first sync reaches.
  ///
  /// A year makes the very first chart worth looking at — a trend over three
  /// weeks says nothing about training. Later syncs are incremental from the
  /// stored watermark, so this cost is paid once.
  static const _backfill = Duration(days: 365);

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

  @override
  void onSignOut() {
    userId = null;
    _daily.clear();
    _initialized = false;
    _syncing = false;
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
    notifyListeners();

    await sync();
  }

  /// Shows the OS permission sheet, then syncs.
  ///
  /// The returned bool says only that the sheet was presented — on iOS it is
  /// not an answer about access. Callers should look at [hasData] afterwards
  /// rather than trusting it.
  Future<bool> connect() async {
    final asked = await _device.requestAccess(tracked);

    // Re-read the status rather than trusting the one taken at launch. If that
    // check threw, [_status] is stuck at its `unavailable` default and [sync]
    // returns early forever — and outside Android's [openInstaller] there is
    // nothing else that would ever reopen the gate.
    _status = await _device.status();

    // The first sync backfills a year across every tracked metric, so the sheet
    // is routinely answered while it is still running. Join that pass rather
    // than racing it, then run a fresh one: the windows it already read were
    // read before consent existed, so its results say nothing about what the
    // user just granted.
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

  Future<void>? _inFlight;

  Future<void> _sync() async {
    _syncing = true;
    notifyListeners();

    try {
      final now = DateTime.now();

      for (final metric in tracked) {
        final last = await _local.lastHealthSampleAt(userId: userId!, metric: metric);
        final from = last?.subtract(const Duration(days: 1)) ?? now.subtract(_backfill);

        final samples = await _device.read(metrics: {metric}, from: from, to: now);
        if (samples.isNotEmpty) {
          await _local.storeHealthSamples(samples, userId!);
        }
      }

      await _loadLocal();
    } catch (error, stacktrace) {
      // Reported without the samples themselves — see the note on onError in
      // the app's wiring. A failed sync is not worth surfacing to the user:
      // the charts simply show what was already mirrored.
      onError?.call(error, stacktrace: stacktrace);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocal() async {
    if (userId case String id) {
      final now = DateTime.now();
      final from = now.subtract(_backfill);

      for (final metric in tracked) {
        _daily[metric] = await _local.getDailyHealth(userId: id, metric: metric, from: from, to: now);
      }
    }
  }

  /// Erases every mirrored sample and forgets it in memory.
  ///
  /// The whole delete — there is no server copy to chase, which is the point of
  /// the device-only decision. Backs a user-facing "forget my health data";
  /// the OS store is untouched, so a later [sync] would rebuild the mirror.
  Future<void> forget() async {
    if (userId case String id) {
      await _local.deleteHealthSamples(id);
    }
    _daily.clear();
    notifyListeners();
  }

  /// Sends the user to install or update Health Connect. Android only.
  Future<void> openInstaller() async {
    await _device.openInstaller();
    _status = await _device.status();
    notifyListeners();
  }

  /// Sends the user where this platform keeps health permissions — on iOS the
  /// Health app, not Settings › Heart. False means there was nowhere to send
  /// them and the caller should fall back; see [HealthService.openPermissions].
  Future<bool> openPermissions() => _device.openPermissions();
}
