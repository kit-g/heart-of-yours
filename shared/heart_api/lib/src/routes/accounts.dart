part of '../api.dart';

/// The account: registering it, its summary, deleting it and taking that back,
/// its avatar, feedback, and the developer API's tokens (#271).
mixin _AccountRoutes on Requests implements AccountService, FeedbackService {
  @override
  Future<User> registerAccount(User user) async {
    final (json, code) = await _refused(
      put(Router.accounts, body: user.toMap()),
      (failure) => switch (failure) {
        NetworkException(statusCode: 400, body: {'code': 'ACCOUNT_DELETED'}) => throw AccountDeleted(),
        _ => _upgradeGate(failure),
      },
    );
    return switch ((code, json)) {
      (200, Map json) => User.fromJson(json),
      _ => throw _unreadable(code, 'PUT', Router.accounts),
    };
  }

  /// `426` as [UpgradeRequired], the account routes' name for it. The app's
  /// `onUpgradeRequired` has already shown the upgrade gate by then; the
  /// refusal still arrives, as every refusal does.
  static Never _upgradeGate(NetworkException failure) {
    throw switch (failure.statusCode) {
      426 => UpgradeRequired(),
      _ => failure,
    };
  }

  /// What the account holds, collection by collection — the yardstick the
  /// export's completeness check measures this device's mirror against
  /// (heart-api#75).
  ///
  /// Caller-scoped: there is no `:targetUserId` form, so this is never a read
  /// of somebody else's totals.
  ///
  /// Throws rather than falling back to an empty summary on a refusal. An
  /// empty summary is a *claim* — "the account holds nothing" — and it reads
  /// as "your mirror is complete", which is the one answer a failed call must
  /// never give.
  Future<AccountSummary> getAccountSummary() async {
    final (json, code) = await _refused(get('${Router.accounts}/summary'), _upgradeGate);
    return switch ((code, json)) {
      (200, Map json) => AccountSummary.fromJson(json),
      _ => throw _unreadable(code, 'GET', '${Router.accounts}/summary'),
    };
  }

  @override
  Future<String?> deleteAccount({required String accountId, AppleDeletionGrant? appleGrant}) async {
    await _refused(
      put(
        Router.accounts,
        body: {
          'action': 'scheduleAccountDeletion',
          ...?appleGrant?.toMap(),
        },
      ),
      _upgradeGate,
    );
    return null;
  }

  @override
  Future<PreSignedUrl?> getAvatarUploadLink(String userId, {String? imageMimeType}) async {
    // `Router.accounts` bare, not `accounts/$userId`: the API registers
    // `('/accounts', .put)` and nothing under an id, so the id in the path
    // matched no route and came back `404 not_found` — while the handler was
    // reading the user off the auth token all along, which is why every
    // sibling call here (upsert, delete, undo) posts to the bare path.
    final (json, _) = await _lenient(
      put(
        Router.accounts,
        body: {
          'action': 'uploadAvatar',
          'mimeType': ?imageMimeType,
        },
      ),
    );
    return switch (json) {
      {'url': String url, 'fields': Map fields} => (
        fields: Map.castFrom<dynamic, dynamic, String, String>(fields),
        url: url,
      ),
      _ => null,
    };
  }

  @override
  Future<bool> uploadFile(
    PreSignedUrl cred,
    (String field, List<int> value, {String? filename, String? contentType}) file, {
    void Function(int bytes, int totalBytes)? onProgress,
  }) {
    return uploadToBucket(cred, file, onProgress: onProgress);
  }

  @override
  Future<bool> removeAvatar(String userId) async {
    // See [getAvatarUploadLink] — the same wrong path, and unreported only
    // because removing an avatar needs one to have been uploaded first.
    final (_, code) = await _lenient(put(Router.accounts, body: {'action': 'removeAvatar'}));
    return 200 <= code && code < 300;
  }

  @override
  Future<String?> undoAccountDeletion() {
    return _refused(put(Router.accounts, body: {'action': 'undoAccountDeletion'}), _upgradeGate).then((_) => null);
  }

  @override
  Future<bool> submitFeedback({required String mimeType, String? feedback, Uint8List? screenshot}) async {
    final (json, _) = await _lenient(post(Router.feedback, body: {'message': feedback}));

    final link = switch (json) {
      {'url': String url, 'fields': Map fields} => (
        fields: Map.castFrom<dynamic, dynamic, String, String>(fields),
        url: url,
      ),
      _ => null,
    };

    if (link != null && screenshot != null) {
      uploadToBucket(link, ('file', screenshot, filename: null, contentType: null));
      return true;
    }
    return false;
  }

  /// The account's personal access tokens, newest first, revoked and expired
  /// ones included (heart-api#111). Never carries a secret.
  ///
  /// Read item by item, like the preferences: a purpose this build has never
  /// heard of is dropped from the token rather than the token from the list,
  /// because a token the app cannot show is one the owner cannot revoke.
  Future<Iterable<ApiToken>> listApiTokens() async {
    final (json, _) = await _lenient(get(Router.accountTokens));
    return switch (json) {
      {'tokens': List l} => _readable(l, (each) => ApiToken.fromJson(_withKnownPurpose(each))),
      _ => const <ApiToken>[],
    };
  }

  /// Mints a token. `201` with the secret, the one time it exists in
  /// plaintext; a refusal is the [NetworkException] with the body, so the
  /// caller can tell the cap (`token_limit`) from an outage.
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) async {
    final (json, code) = await post(
      Router.accountTokens,
      body: {'name': name, 'expiry': expiry.name, 'purpose': ?purpose?.name},
    );
    return switch ((code, json)) {
      (201, Map json) => MintedApiToken.fromJson(json),
      _ => throw _unreadable(code, 'POST', Router.accountTokens),
    };
  }

  /// Revokes a token. `204`, also for one already revoked; `404` for one the
  /// account does not own, thrown like every refusal.
  Future<void> revokeApiToken(String tokenId) async {
    final (json, code) = await delete(Router.accountToken(tokenId));
    if (code != 204) throw _unreadable(code, 'DELETE', Router.accountToken(tokenId));
  }

  /// [json] with its `purpose` only when it is one this build can name.
  ///
  /// The server's enum may grow ahead of the app in the stores, and
  /// `ApiToken.fromJson` refuses a value it does not know. The purpose is a
  /// label the owner chose, nothing the app acts on, so losing it costs less
  /// than losing the row.
  static Map _withKnownPurpose(Map json) {
    return switch (json['purpose']) {
      String p when ApiTokenPurpose.values.any((each) => each.name == p) => json,
      _ => {...json}..remove('purpose'),
    };
  }
}
