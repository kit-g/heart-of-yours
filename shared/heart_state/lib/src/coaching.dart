import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

/// What the server does with an account's connections and hidden workouts
/// (heart-of-yours#552).
///
/// Defined here, like `ApiTokenService`: it is the app's view of a handful of
/// routes, not a contract the server implements. The app adapts `Api` onto it.
/// A connection's routes take its [Connection.connectionId].
abstract interface class CoachingService {
  /// Every connection, both directions, ended ones included.
  Future<List<Connection>> getConnections();

  /// Replaces what the student of a coach connection shares. Only the student
  /// may.
  /// By name: one this build doesn't know goes back as it came.
  Future<Connection> setConnectionShares(String connectionId, Set<String> shares);

  Future<Connection> setConnectionStatus(String connectionId, ConnectionStatus status);

  /// Ends it for both people. The server keeps the row, as `severed`.
  Future<void> endConnection(String connectionId);

  Future<List<HiddenWorkout>> getHiddenWorkouts();

  Future<void> hideWorkout(String workoutId, {DateTime? at});

  Future<void> unhideWorkout(String workoutId);
}

/// The account entitlement that lets it invite people to be coached. Granted
/// by hand during the beta.
const coachEntitlement = 'coach';

extension CoachEntitlement on User {
  /// Whether this account may invite people to be coached.
  bool get mayCoach => entitlements.contains(coachEntitlement);
}

/// Where the connections stand with the server.
enum CoachingStatus {
  /// Never asked.
  idle,

  loading,

  /// The last read landed.
  loaded,

  /// The last read did not land, and nothing newer has been read since.
  failed,
}

/// The account's coaching connections, both ways, and the workouts it keeps
/// out of every connection's view.
///
/// Server-only, deliberately, like `ApiTokens`: who may read what is the
/// server's to decide, and a copy here would be one more place to go stale.
/// Nothing reads until [load] is called, which the app does only with a
/// coaching feature on, so with both off nothing goes over the wire.
///
/// [Connection.role] is this account's own side: a coach sees `coach` on each
/// client, and a student sees `student` on their coach.
class Coaching with ChangeNotifier implements SignOutStateSentry {
  final CoachingService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  final _connections = <Connection>[];
  final _hidden = <String, DateTime>{};

  CoachingStatus _status = .idle;

  new({
    required this._service,
    RemoteAccess? remote,
    this.onError,
  }) : _remote = remote ?? RemoteAccess();

  static Coaching of(BuildContext context) => Provider.of<Coaching>(context, listen: false);

  static Coaching watch(BuildContext context) => Provider.of<Coaching>(context, listen: true);

  CoachingStatus get status => _status;

  /// Every connection the server returned, ended ones included.
  List<Connection> get all => UnmodifiableListView(_connections);

  /// The people this account coaches, live or paused.
  Iterable<Connection> get clients => _current(.coach);

  /// This account's coaches, live or paused: one per domain at most.
  Iterable<Connection> get coaches => _current(.student);

  bool get hasCoach => coaches.isNotEmpty;

  Iterable<Connection> _current(ConnectionRole role) {
    return _connections.where((connection) {
      return connection.role == role && (connection.status == .active || connection.status == .paused);
    });
  }

  /// The ids of the workouts kept out of every connection's view.
  Set<String> get hiddenWorkouts => UnmodifiableSetView(_hidden.keys.toSet());

  bool isHidden(String workoutId) => _hidden.containsKey(workoutId);

  @override
  void onSignOut() {
    _connections.clear();
    _hidden.clear();
    _status = .idle;
    notifyListeners();
  }

  /// Reads the connections and the hidden workouts. Nothing happens while the
  /// remote leg is closed: coaching needs an account.
  Future<void> load() async {
    if (!_remote.allowed) return;
    _status = .loading;
    notifyListeners();
    try {
      final (connections, hidden) = await (_service.getConnections(), _service.getHiddenWorkouts()).wait;
      _connections
        ..clear()
        ..addAll(connections);
      _hidden
        ..clear()
        ..addEntries(hidden.map((each) => MapEntry(each.id, each.at)));
      _status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// What a student opens to [coach] beyond workouts since accepting.
  /// Throws what the service threw; the list here changes only once the
  /// server has agreed.
  ///
  /// The server replaces the whole list, so a share this build doesn't know,
  /// one a newer app turned on, goes back exactly as it came.
  Future<void> setShares(Connection coach, Set<ConnectionShare> shares) async {
    final known = {for (final share in ConnectionShare.values) share.name};
    final kept = coach.shares.where((share) => !known.contains(share));
    _replace(await _service.setConnectionShares(_idOf(coach), {for (final share in shares) share.name, ...kept}));
  }

  /// Stops [connection]'s coach reading anything logged from now on. Either
  /// side may pause; only the student resumes.
  Future<void> pause(Connection connection) async {
    _replace(await _service.setConnectionStatus(_idOf(connection), .paused));
  }

  Future<void> resume(Connection connection) async {
    _replace(await _service.setConnectionStatus(_idOf(connection), .active));
  }

  /// Ends [connection] for both people. It stays in [all] as ended, and out of
  /// [clients] and [coaches].
  Future<void> end(Connection connection) async {
    await _service.endConnection(_idOf(connection));
    _replace(
      Connection(
        targetId: connection.targetId,
        role: connection.role,
        domain: connection.domain,
        status: .severed,
        createdAt: connection.createdAt,
        connectionId: connection.connectionId,
        acceptedAt: connection.acceptedAt,
        shares: connection.shares,
      ),
    );
  }

  /// Keeps [workoutId] out of every connection's view, peers' too.
  Future<void> hide(String workoutId) async {
    final at = DateTime.timestamp();
    await _service.hideWorkout(workoutId, at: at);
    _hidden[workoutId] = at;
    notifyListeners();
  }

  Future<void> unhide(String workoutId) async {
    await _service.unhideWorkout(workoutId);
    _hidden.remove(workoutId);
    notifyListeners();
  }

  /// What every connection route takes. A connection without one is an old
  /// pending peer request, never a coaching one, and can't be addressed.
  static String _idOf(Connection connection) {
    return switch (connection.connectionId) {
      final String id => id,
      null => throw StateError('a connection without a connectionId cannot be addressed'),
    };
  }

  void _replace(Connection updated) {
    final index = _connections.indexWhere((each) => each.connectionId == updated.connectionId);
    switch (index) {
      case -1:
        _connections.add(updated);
      default:
        _connections[index] = updated;
    }
    notifyListeners();
  }
}
