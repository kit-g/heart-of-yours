import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RosterService] [Roster] wants (#559), as
/// `RemoteCoaching` does for connections.
class RemoteRoster implements RosterService {
  final Api _api;

  const new(this._api);

  @override
  Future<({List<ClientSummary> items, String? cursor})> getClients({bool former = false, String? cursor}) {
    return _api.getClients(former: former, cursor: cursor);
  }

  @override
  Future<void> markReviewed(String connectionId, {DateTime? at}) => _api.markReviewed(connectionId, at: at);

  @override
  Future<({List<CoachFeedItem> items, String? cursor})> getCoachFeed({String? cursor}) {
    return _api.getCoachFeed(cursor: cursor);
  }
}
