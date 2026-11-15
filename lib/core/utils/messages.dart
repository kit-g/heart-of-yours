import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RemoteThreadService] [Messages] wants (#556), for
/// the reason [RemoteDeviceKeys] exists: the interface is the state package's
/// view of a few routes, and the app is where `heart_api` and `heart_state`
/// meet.
class RemoteThreads implements RemoteThreadService {
  final Api _api;

  const new(this._api);

  @override
  Future<Thread> openThread(String connectionId) => _api.openThread(connectionId);

  @override
  Future<List<Thread>> getThreads() => _api.getThreads();

  @override
  Future<ThreadItem> postThreadItem(
    String threadId, {
    required String id,
    required String content,
    required String commitment,
    required DateTime at,
    String? subjectType,
    String? subjectId,
  }) {
    return _api.postThreadItem(
      threadId,
      id: id,
      content: content,
      commitment: commitment,
      at: at,
      subjectType: subjectType,
      subjectId: subjectId,
    );
  }

  @override
  Future<({List<ThreadItem> items, String? cursor})> getThreadItems(
    String threadId, {
    String? since,
    String? before,
    int? limit,
  }) {
    return _api.getThreadItems(threadId, since: since, before: before, limit: limit);
  }

  @override
  Future<void> markThreadRead(String threadId, String cursor) => _api.markThreadRead(threadId, cursor);

  @override
  Future<void> clearThread(String threadId) => _api.clearThread(threadId);

  @override
  Future<void> fileReport({
    required String reportedId,
    String? connectionId,
    required String reason,
    List<ReportedMessage> messages = const [],
  }) {
    return _api.fileReport(reportedId: reportedId, connectionId: connectionId, reason: reason, messages: messages);
  }
}

/// Presents [LocalDatabase] as the [LocalThreadService] [Messages] wants
/// (#556): ciphertext only, as the server keeps it.
class LocalThreads implements LocalThreadService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<List<Thread>> getThreads(String userId) => _db.getThreads(userId);

  @override
  Future<void> storeThreads(String userId, Iterable<Thread> threads) => _db.storeThreads(userId, threads);

  @override
  Future<void> storeThread(String userId, Thread thread) => _db.storeThread(userId, thread);

  @override
  Future<List<StoredItem>> getThreadItems(String userId, String threadId) => _db.getThreadItems(userId, threadId);

  @override
  Future<void> storeThreadItems(String userId, Iterable<StoredItem> items) => _db.storeThreadItems(userId, items);

  @override
  Future<void> deleteThreadItems(String userId, Iterable<String> itemIds) => _db.deleteThreadItems(userId, itemIds);
}
