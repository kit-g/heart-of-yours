abstract interface class AccountService {
  Future<String?> undoAccountDeletion(String accountId);

  Future<String?> deleteAccount({required String accountId});

  Future<({String url, Map<String, String> fields})?> getAvatarUploadLink(String userId, {String? imageMimeType});

  Future<bool> uploadAvatar(
    ({String url, Map<String, String> fields}) cred,
    (String field, List<int> value, {String? filename, String? contentType}) avatar, {
    final void Function(int bytes, int totalBytes)? onProgress,
  });
}
