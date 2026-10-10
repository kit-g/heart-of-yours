import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'remote.dart';

/// What the server does with an account's personal access tokens
/// (heart-api#111): list them, mint one, revoke one.
///
/// Defined here rather than in `heart_models`, like
/// `RemoteAccountSummaryService`: it is the app's view of three routes, not a
/// contract the server implements. The app adapts `Api` onto it.
abstract interface class ApiTokenService {
  /// Every token the account ever minted, newest first, revoked and expired
  /// ones included. Never a secret.
  Future<Iterable<ApiToken>> listApiTokens();

  /// Mints a token. The answer carries the secret, the one time it exists.
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  });

  /// Revokes a token; the server keeps it, as history.
  Future<void> revokeApiToken(String tokenId);
}

/// A token request the server considered and refused.
///
/// Same shape as `GoalRejected`: the server names each refusal with a stable
/// [code], and the one worth branching on is the cap — the only refusal a
/// well-formed create can hit on state this device cannot see, a token minted
/// elsewhere since the list was read.
class ApiTokenRejected implements Exception {
  /// `token_limit`, `bad_request`, `not_found`.
  final String code;

  /// The server's human sentence, when it sent one.
  final String? reason;

  const new(this.code, {this.reason});

  /// The account already holds [ApiToken.maxActive] live tokens.
  bool get isAtCapacity => code == 'token_limit';

  /// The token is not the account's to revoke — gone, or never its own.
  bool get isUnknown => code == 'not_found';

  /// Named, but still transient: the request was fine and the server broke.
  static const _serverError = 'server_error';

  /// Reads a refusal out of whatever the service threw, or null when the
  /// failure could just as well be an outage.
  static ApiTokenRejected? from(Object? error) {
    return switch (error) {
      {'code': _serverError} => null,
      {'code': String code} => ApiTokenRejected(
        code,
        reason: switch (error) {
          {'reason': String reason} => reason,
          {'message': String message} => message,
          _ => null,
        },
      ),
      _ => null,
    };
  }

  @override
  String toString() => reason ?? 'Token rejected: $code';
}

/// Where the list stands with the server.
enum ApiTokensStatus {
  /// Never asked.
  idle,

  loading,

  /// The last read landed; the list is the server's.
  loaded,

  /// The last read did not land, and nothing newer has been read since.
  failed,
}

/// The account's personal access tokens, as the server lists them.
///
/// Server-only, deliberately: a token is a credential for the server, there is
/// nothing to show without one, and a copy on the device would be one more
/// place the list could be stale. The page reads on open and after every
/// write; between reads the list is kept in step by hand, so a mint or a
/// revoke shows at once rather than after a round trip.
class ApiTokens with ChangeNotifier implements SignOutStateSentry {
  final ApiTokenService _service;
  final RemoteAccess _remote;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  final _tokens = <ApiToken>[];

  ApiTokensStatus _status = .idle;

  new({
    required this._service,
    RemoteAccess? remote,
    this.onError,
  }) : _remote = remote ?? RemoteAccess();

  static ApiTokens of(BuildContext context) => Provider.of<ApiTokens>(context, listen: false);

  static ApiTokens watch(BuildContext context) => Provider.of<ApiTokens>(context, listen: true);

  ApiTokensStatus get status => _status;

  /// Every token, newest first.
  List<ApiToken> get all => UnmodifiableListView(_tokens);

  /// The ones a bearer request would still be accepted with.
  Iterable<ApiToken> get active => _tokens.where((token) => token.isActive());

  /// The ones that were revoked or have expired — history, kept so the owner
  /// can see what once had access.
  Iterable<ApiToken> get inactive => _tokens.where((token) => !token.isActive());

  /// Whether the server would refuse another token.
  ///
  /// Counted from the last read, so a token minted on another device since
  /// can make this wrong in the lenient direction; the create still fails
  /// then, and [create] re-reads the list so the page catches up.
  bool get isAtCapacity => active.length >= ApiToken.maxActive;

  @override
  void onSignOut() {
    _tokens.clear();
    _status = .idle;
    notifyListeners();
  }

  /// Reads the list. Nothing happens while the remote leg is closed: an
  /// anonymous session has no account to hold tokens, and the page that
  /// calls this is not reachable from one.
  Future<void> load() async {
    if (!_remote.allowed) return;
    _status = .loading;
    notifyListeners();
    try {
      final tokens = await _service.listApiTokens();
      _tokens
        ..clear()
        ..addAll(tokens);
      _status = .loaded;
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      _status = .failed;
    }
    notifyListeners();
  }

  /// Mints a token and lists it at the top. The secret rides back on the
  /// answer and is kept nowhere here: showing it once is the caller's job.
  ///
  /// Throws [ApiTokenRejected] for a refusal the caller can word — the cap,
  /// a name the server would not take — and whatever else the service threw
  /// for an outage. A refusal at the cap re-reads the list, since it means
  /// the list here is behind the server's.
  Future<MintedApiToken> create({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) async {
    try {
      final minted = await _service.createApiToken(name: name, expiry: expiry, purpose: purpose);
      _tokens.insert(0, minted.token);
      notifyListeners();
      return minted;
    } catch (error) {
      switch (ApiTokenRejected.from(error)) {
        case ApiTokenRejected rejected:
          if (rejected.isAtCapacity) await load();
          throw rejected;
        case null:
          rethrow;
      }
    }
  }

  /// Revokes [token]. The row stays, marked revoked as of now, and the list
  /// is then re-read so the server's own stamps land: its `revokedAt`, and a
  /// `lastUsedAt` a request may have bumped since the list was read.
  ///
  /// A token the server no longer knows is not an error worth stopping on:
  /// the re-read is what drops it from here too.
  Future<void> revoke(ApiToken token) async {
    try {
      await _service.revokeApiToken(token.id);
    } catch (error) {
      switch (ApiTokenRejected.from(error)) {
        case ApiTokenRejected(isUnknown: true):
          await load();
          return;
        case ApiTokenRejected rejected:
          throw rejected;
        case null:
          rethrow;
      }
    }
    final index = _tokens.indexOf(token);
    if (index >= 0) {
      _tokens[index] = ApiToken(
        id: token.id,
        name: token.name,
        purpose: token.purpose,
        hint: token.hint,
        scopes: token.scopes,
        createdAt: token.createdAt,
        lastUsedAt: token.lastUsedAt,
        expiresAt: token.expiresAt,
        revokedAt: token.revokedAt ?? DateTime.now().toUtc(),
      );
    }
    notifyListeners();
    await load();
  }
}
