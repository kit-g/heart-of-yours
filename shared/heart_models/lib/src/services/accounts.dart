abstract interface class AccountService {
  Future<String?> undoAccountDeletion(String accountId);

  Future<String?> deleteAccount({required String accountId});
}
