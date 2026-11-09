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

  // ---- invitations (#553) ----

  /// A one-person link for someone the coach calls [name]. The answer carries
  /// its token, readable only now and on a resend.
  Future<Invitation> createInvitation(String name, {String? programId});

  Future<({List<Invitation> items, String? cursor})> getInvitations({String? cursor});

  Future<Invitation> resendInvitation(String invitationId);

  Future<void> cancelInvitation(String invitationId);

  /// Null for a token the server never made.
  Future<InvitationPreview?> previewInvitation(String token);

  Future<AcceptedInvitation> acceptInvitation(String token, Set<ConnectionShare> shares);

  Future<void> declineInvitation(String token);

  Future<void> blockInviter(String token);

  Future<({List<BlockedPerson> items, String? cursor})> getBlocks({String? cursor});

  Future<void> liftBlock(String userId);
}

/// What became of an invitation, by the `status` the server names.
enum InvitationStatus {
  pending,
  accepted,
  declined,
  canceled,
  expired;

  /// A status this build doesn't know reads as [expired]: no longer good,
  /// which is all a coach can do anything with.
  static InvitationStatus of(Invitation invitation) {
    return values.firstWhere((each) => each.name == invitation.status, orElse: () => expired);
  }
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
  final _invitations = <Invitation>[];
  final _blocks = <BlockedPerson>[];

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

  /// The coach's invitations, newest first, however they ended: only after
  /// [loadInvitations].
  List<Invitation> get invitations => UnmodifiableListView(_invitations);

  /// The ones still waiting for an answer.
  Iterable<Invitation> get pendingInvitations {
    return _invitations.where((each) => InvitationStatus.of(each) == .pending);
  }

  /// Who this account has blocked: only after [loadBlocks].
  List<BlockedPerson> get blocks => UnmodifiableListView(_blocks);

  @override
  void onSignOut() {
    _connections.clear();
    _hidden.clear();
    _invitations.clear();
    _blocks.clear();
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

  // ---- a coach's invitations (#553) ----

  /// Reads the coach's invitations, every page of them: a coach has a handful.
  Future<void> loadInvitations() async {
    if (!_remote.allowed) return;
    final all = <Invitation>[];
    String? cursor;
    do {
      final page = await _service.getInvitations(cursor: cursor);
      all.addAll(page.items);
      cursor = page.cursor;
    } while (cursor != null);
    _invitations
      ..clear()
      ..addAll(all);
    notifyListeners();
  }

  /// A link for someone the coach calls [name], listed at the top. The token
  /// rides back on the answer and is kept nowhere here: sharing it is the
  /// caller's job.
  Future<Invitation> invite(String name, {String? programId}) async {
    final invitation = await _service.createInvitation(name, programId: programId);
    _invitations.insert(0, invitation);
    notifyListeners();
    return invitation;
  }

  /// A fresh link, and a fresh week, for [invitation]. The old link stops
  /// working.
  Future<Invitation> resend(Invitation invitation) async {
    final renewed = await _service.resendInvitation(invitation.id);
    _replaceInvitation(renewed);
    return renewed;
  }

  Future<void> cancel(Invitation invitation) async {
    await _service.cancelInvitation(invitation.id);
    _replaceInvitation(
      Invitation(
        id: invitation.id,
        name: invitation.name,
        status: InvitationStatus.canceled.name,
        role: invitation.role,
        domain: invitation.domain,
        expiresAt: invitation.expiresAt,
        createdAt: invitation.createdAt,
      ),
    );
  }

  void _replaceInvitation(Invitation updated) {
    final index = _invitations.indexWhere((each) => each.id == updated.id);
    switch (index) {
      case -1:
        _invitations.insert(0, updated);
      default:
        _invitations[index] = updated;
    }
    notifyListeners();
  }

  // ---- answering one (#553) ----

  /// What a link says: whether it is good and, while it is, who sent it. Null
  /// for a link the server never made.
  Future<InvitationPreview?> preview(String token) => _service.previewInvitation(token);

  /// Accepts a link, sharing [shares] beyond the workouts logged from now on.
  /// The coach joins [coaches] at once.
  Future<AcceptedInvitation> accept(String token, Set<ConnectionShare> shares) async {
    final accepted = await _service.acceptInvitation(token, shares);
    _replace(accepted.connection);
    return accepted;
  }

  Future<void> decline(String token) => _service.declineInvitation(token);

  /// Blocks whoever sent the link, though nobody is connected yet.
  Future<void> blockInviter(String token) => _service.blockInviter(token);

  // ---- blocks (#553) ----

  Future<void> loadBlocks() async {
    if (!_remote.allowed) return;
    final all = <BlockedPerson>[];
    String? cursor;
    do {
      final page = await _service.getBlocks(cursor: cursor);
      all.addAll(page.items);
      cursor = page.cursor;
    } while (cursor != null);
    _blocks
      ..clear()
      ..addAll(all);
    notifyListeners();
  }

  /// Lifts a block. It restores nothing: what it ended stays ended.
  Future<void> lift(BlockedPerson person) async {
    await _service.liftBlock(person.id);
    _blocks.removeWhere((each) => each.id == person.id);
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
