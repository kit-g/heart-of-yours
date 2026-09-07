import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RemoteAccountSummaryService] [Backfill] wants — the
/// account CRUD travels as `AccountService`, which [Api] implements itself,
/// and this carries the one read that server-shared interface cannot grow:
/// the server counts, and the app has no counting to implement.
class RemoteAccountSummary implements RemoteAccountSummaryService {
  final Api _api;

  const new(this._api);

  @override
  Future<AccountSummary> getAccountSummary() => _api.getAccountSummary();
}

/// Presents [LocalDatabase] as the [LocalMirrorService] [Backfill] wants —
/// the mirror's own side of the same count, and the mark that says it is
/// whole. Exists for the same reason [LocalGoals] does: the app is the one
/// place that sees `heart_db` and `heart_state` at once.
class LocalMirror implements LocalMirrorService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<AccountSummary> mirrorSummary(String userId) => _db.mirrorSummary(userId);

  @override
  Future<bool> isHistoryBackfilled(String userId) => _db.isHistoryBackfilled(userId);

  @override
  Future<void> markHistoryBackfilled(String userId) => _db.markHistoryBackfilled(userId);
}
