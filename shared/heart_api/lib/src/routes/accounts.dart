part of '../api.dart';

/// The account: registering it, its summary, deleting it and taking that back,
/// its avatar, feedback, and the developer API's tokens (#271).
mixin _AccountRoutes on Requests implements AccountService, FeedbackService {
  /// A deleted account and a forced upgrade are thrown by [Api.failure], as
  /// [AccountDeleted] and [UpgradeRequired], before anything reads the answer.
  @override
  Future<User> registerAccount(User user) async {
    final (json, _) = await put(Router.accounts, body: user.toMap());
    return User.fromJson(json);
  }

  /// What the account holds, collection by collection — the yardstick the
  /// export's completeness check measures this device's mirror against
  /// (heart-api#75).
  ///
  /// Caller-scoped: there is no `:targetUserId` form, so this is never a read
  /// of somebody else's totals.
  ///
  /// Throws rather than falling back to an empty summary on a failure. An
  /// empty summary is a *claim* — "the account holds nothing" — and it reads
  /// as "your mirror is complete", which is the one answer a failed call must
  /// never give.
  Future<AccountSummary> getAccountSummary() async {
    final (json, _) = await get(Router.accountSummary);
    return AccountSummary.fromJson(json);
  }

  @override
  Future<String?> deleteAccount({required String accountId, AppleDeletionGrant? appleGrant}) async {
    await put(
      Router.accounts,
      body: {
        'action': 'scheduleAccountDeletion',
        ...?appleGrant?.toMap(),
      },
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
    final (json, _) = await put(
      Router.accounts,
      body: {
        'action': 'uploadAvatar',
        'mimeType': ?imageMimeType,
      },
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

  /// True once removed; a failure is thrown.
  @override
  Future<bool> removeAvatar(String userId) async {
    // See [getAvatarUploadLink] — the same wrong path, and unreported only
    // because removing an avatar needs one to have been uploaded first.
    await put(
      Router.accounts,
      body: {'action': 'removeAvatar'},
    );
    return true;
  }

  @override
  Future<String?> undoAccountDeletion() async {
    await put(
      Router.accounts,
      body: {'action': 'undoAccountDeletion'},
    );
    return null;
  }

  @override
  Future<bool> submitFeedback({required String mimeType, String? feedback, Uint8List? screenshot}) async {
    final (json, _) = await post(Router.feedback, body: {'message': feedback});

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
  ///
  /// A failure is thrown, never answered as no tokens: an empty list says the
  /// account holds none.
  Future<Iterable<ApiToken>> listApiTokens() async {
    final (tokens, _) = await _listAt(Router.accountTokens, 'tokens');
    return _readable(tokens, (each) => ApiToken.fromJson(_withKnownPurpose(each)));
  }

  /// Mints a token: `201` with the secret, the one time it exists in
  /// plaintext. The cap is the [ServerRefusal] `token_limit`.
  Future<MintedApiToken> createApiToken({
    required String name,
    required ApiTokenExpiry expiry,
    ApiTokenPurpose? purpose,
  }) async {
    final (json, _) = await post(
      Router.accountTokens,
      body: {'name': name, 'expiry': expiry.name, 'purpose': ?purpose?.name},
    );
    return MintedApiToken.fromJson(json);
  }

  /// Revokes a token. `204`, also for one already revoked; a token the account
  /// does not own is the [ServerRefusal] `not_found`.
  Future<void> revokeApiToken(String tokenId) => delete(Router.accountToken(tokenId));

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
