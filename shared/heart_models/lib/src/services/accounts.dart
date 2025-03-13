abstract interface class AccountService {
  Future<void> undoAccountDeletion(String accountId);

  Future<String?> deleteAccount({required String accountId});
}
