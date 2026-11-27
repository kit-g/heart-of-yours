import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

/// The local half of suspicious entries (#428): the mirror of the server's
/// list, and the decisions this device has taken and not pushed yet.
/// `LocalDatabase` satisfies it through an adapter in the app, as it does
/// [AnomalyService]'s other local counterparts.
abstract interface class LocalAnomalyService {
  /// Newest found first.
  Future<List<Anomaly>> getAnomalies(String userId);

  Future<List<Anomaly>> unsyncedAnomalies(String userId);

  /// A full read from the server, keeping a decision not pushed yet while it
  /// still answers the anomaly it was taken on.
  Future<void> storeAnomalies(Iterable<Anomaly> anomalies, String userId);

  /// One anomaly as the server answered it.
  Future<void> storeAnomaly(Anomaly anomaly, String userId);

  /// What the user made of one, unsynced until [storeAnomaly].
  Future<void> resolveAnomaly(String anomalyId, AnomalyStatus status, {required DateTime at});
}

/// Suspicious entries (#428, heart-api#42): what the server's sweep found odd
/// in the log — a set far from the exercise's usual weight, a workout left
/// running — and what the user made of each.
///
/// Nothing is corrected. A decision is written locally first and pushed when
/// the remote leg is open; a decision can be changed, and the latest counts.
/// Held whatever the feature's switch says (`docs/opt-in.md`): the switch
/// decides what the app shows and counts, never what it keeps or syncs.
class Anomalies with ChangeNotifier, Iterable<Anomaly> implements SignOutStateSentry {
  final LocalAnomalyService _service;
  final AnomalyService _remoteService;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// The page size of a read: the server's largest.
  static const _page = 100;

  var _anomalies = const <Anomaly>[];

  String? userId;

  /// A pull in flight, which a second caller joins rather than repeats.
  Future<void>? _pulling;

  new({
    required this._service,
    required this._remoteService,
    this.onError,
    RemoteAccess? remote,
  }) : _remote = remote ?? RemoteAccess();

  static Anomalies of(BuildContext context) => Provider.of<Anomalies>(context, listen: false);

  static Anomalies watch(BuildContext context) => Provider.of<Anomalies>(context, listen: true);

  /// Newest found first, pending and decided.
  @override
  Iterator<Anomaly> get iterator => _anomalies.iterator;

  Iterable<Anomaly> get pending => where((anomaly) => anomaly.status == .pending);

  /// The anomaly on [setId], if it has one: an entry has one at most.
  Anomaly? ofSet(String setId) => _bySet[setId];

  /// The anomaly on [workoutId]'s duration, if it has one.
  Anomaly? durationOf(String workoutId) => _byDuration[workoutId];

  /// Every anomaly in [workoutId], its sets' and its duration's.
  Iterable<Anomaly> ofWorkout(String workoutId) => where((anomaly) => anomaly.workoutId == workoutId);

  /// The sets the user discarded: out of every count while the feature is on.
  UnmodifiableSetView<String> get discardedSets => UnmodifiableSetView(_discardedSets);

  /// The workouts whose duration the user discarded: they still count, with
  /// no time.
  UnmodifiableSetView<String> get discardedDurations => UnmodifiableSetView(_discardedDurations);

  var _bySet = const <String, Anomaly>{};
  var _byDuration = const <String, Anomaly>{};
  var _discardedSets = const <String>{};
  var _discardedDurations = const <String>{};

  void _take(List<Anomaly> anomalies) {
    _anomalies = anomalies;
    _bySet = {
      for (final anomaly in anomalies)
        if (anomaly.setId case final String id) id: anomaly,
    };
    _byDuration = {
      for (final anomaly in anomalies)
        if (anomaly.setId == null) anomaly.workoutId: anomaly,
    };
    _discardedSets = {
      for (final MapEntry(key: id, value: anomaly) in _bySet.entries)
        if (anomaly.status == .invalid) id,
    };
    _discardedDurations = {
      for (final MapEntry(key: id, value: anomaly) in _byDuration.entries)
        if (anomaly.status == .invalid) id,
    };
    notifyListeners();
  }

  /// The mirror, then the server's list over it.
  Future<void> init() async {
    final userId = this.userId;
    if (userId == null) return;
    try {
      _take(await _service.getAnomalies(userId));
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
    await pull();
  }

  /// Pushes the decisions owed, then reads the server's whole list. Flags
  /// arrive late — the sweep runs nightly — so this is asked again whenever
  /// the list is looked at. Quiet with the remote leg closed: an anonymous
  /// session has nothing on a server to be flagged.
  Future<void> pull() {
    return _pulling ??= _pull().whenComplete(() => _pulling = null);
  }

  Future<void> _pull() async {
    final userId = this.userId;
    if (userId == null || !_remote.allowed) return;
    try {
      for (final owed in await _service.unsyncedAnomalies(userId)) {
        await _push(owed, userId);
      }
      final read = <Anomaly>[];
      String? cursor;
      do {
        final page = await _remoteService.getAnomalies(userId: userId, cursor: cursor, limit: _page);
        read.addAll(page);
        cursor = page.hasMore ? page.lastOrNull?.id : null;
      } while (cursor != null);
      // the session changed hands while the list was on its way
      if (userId != this.userId) return;
      await _service.storeAnomalies(read, userId);
      _take(await _service.getAnomalies(userId));
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  /// What the user made of [anomaly]: it stands ([AnomalyStatus.valid]), or it
  /// stays in the log and stops counting ([AnomalyStatus.invalid]). Written
  /// here at once, and on the server when it can be.
  Future<void> resolve(Anomaly anomaly, AnomalyStatus status) async {
    final userId = this.userId;
    if (userId == null || anomaly.status == status) return;
    try {
      await _service.resolveAnomaly(anomaly.id, status, at: DateTime.timestamp());
      _take(await _service.getAnomalies(userId));
      if (!_remote.allowed) return;
      if (where((each) => each.id == anomaly.id).firstOrNull case final Anomaly owed) {
        await _push(owed, userId);
      }
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
    }
  }

  Future<void> _push(Anomaly owed, String userId) async {
    final answered = await _remoteService.resolveAnomaly(userId: userId, anomalyId: owed.id, status: owed.status);
    if (answered != null) await _service.storeAnomaly(answered, userId);
    // null: the server forgot it, and the next full read drops it here too
  }

  @override
  void onSignOut() {
    userId = null;
    _take(const []);
  }
}
