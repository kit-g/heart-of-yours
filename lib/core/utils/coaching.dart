import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [CoachingService] [Coaching] wants (#552, #566), for
/// the reason [RemoteApiTokens] exists: the interface is the state package's
/// view of a few routes, and the app is where `heart_api` and `heart_state`
/// meet.
class RemoteCoaching implements CoachingService {
  final Api _api;

  const new(this._api);

  @override
  Future<List<Connection>> getConnections() => _api.getConnections();

  @override
  Future<Connection> setConnectionShares(String connectionKey, Set<ConnectionShare> shares) {
    return _api.setConnectionShares(connectionKey, shares);
  }

  @override
  Future<Connection> setConnectionStatus(String connectionKey, ConnectionStatus status) {
    return _api.setConnectionStatus(connectionKey, status);
  }

  @override
  Future<void> endConnection(String connectionKey) => _api.endConnection(connectionKey);

  @override
  Future<List<HiddenWorkout>> getHiddenWorkouts() => _api.getHiddenWorkouts();

  @override
  Future<void> hideWorkout(String workoutId, {DateTime? at}) => _api.hideWorkout(workoutId, at: at);

  @override
  Future<void> unhideWorkout(String workoutId) => _api.unhideWorkout(workoutId);

  @override
  Future<Invitation> createInvitation(String name, {String? programId}) {
    return _api.createInvitation(name, programId: programId);
  }

  @override
  Future<({List<Invitation> items, String? cursor})> getInvitations({String? cursor}) {
    return _api.getInvitations(cursor: cursor);
  }

  @override
  Future<Invitation> resendInvitation(String invitationId) => _api.resendInvitation(invitationId);

  @override
  Future<void> cancelInvitation(String invitationId) => _api.cancelInvitation(invitationId);

  @override
  Future<InvitationPreview?> previewInvitation(String token) => _api.previewInvitation(token);

  @override
  Future<AcceptedInvitation> acceptInvitation(String token, Set<ConnectionShare> shares) {
    return _api.acceptInvitation(token, shares);
  }

  @override
  Future<void> declineInvitation(String token) => _api.declineInvitation(token);

  @override
  Future<void> blockInviter(String token) => _api.blockInviter(token);

  @override
  Future<({List<BlockedPerson> items, String? cursor})> getBlocks({String? cursor}) {
    return _api.getBlocks(cursor: cursor);
  }

  @override
  Future<void> liftBlock(String userId) => _api.liftBlock(userId);
}
