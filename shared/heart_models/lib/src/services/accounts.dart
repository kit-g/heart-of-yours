abstract interface class AccountService {
  Future<void> deleteAccount({required String accountId, required String password});
}
