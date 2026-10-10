import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [ApiTokenService] [ApiTokens] wants (#271). Exists
/// for the reason [RemoteAccountSummary] does: the interface is the state
/// package's view of three routes, and the app is where `heart_api` and
/// `heart_state` meet.
class RemoteApiTokens implements ApiTokenService {
  final Api _api;

  const new(this._api);

  @override
  Future<Iterable<ApiToken>> listApiTokens() => _api.listApiTokens();

  @override
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) {
    return _api.createApiToken(name: name, expiry: expiry, purpose: purpose);
  }

  @override
  Future<void> revokeApiToken(String tokenId) => _api.revokeApiToken(tokenId);
}
