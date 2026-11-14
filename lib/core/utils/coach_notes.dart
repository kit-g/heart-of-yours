import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

/// Presents [Api] as the [RemoteNoteService] [CoachNotes] wants (#556): the
/// state package's view of a few routes, met here, where `heart_api` and
/// `heart_state` meet.
class RemoteNotes implements RemoteNoteService {
  final Api _api;

  const new(this._api);

  @override
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content}) {
    return _api.saveNote(id, connectionId: connectionId, content: content);
  }

  @override
  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor}) {
    return _api.getNotes(connectionId: connectionId, cursor: cursor);
  }

  @override
  Future<void> deleteNote(String id) => _api.deleteNote(id);
}

/// Presents [LocalDatabase] as the [LocalNoteService] [CoachNotes] wants
/// (#556): ciphertext only, as the server keeps it.
class LocalNotes implements LocalNoteService {
  final LocalDatabase _db;

  const new(this._db);

  @override
  Future<List<StoredNote>> getCoachNotes(String userId) => _db.getCoachNotes(userId);

  @override
  Future<void> storeCoachNotes(String userId, Iterable<StoredNote> notes) => _db.storeCoachNotes(userId, notes);

  @override
  Future<void> replaceCoachNotes(String userId, Iterable<CoachNote> notes, {Set<String> keep = const {}}) {
    return _db.replaceCoachNotes(userId, notes, keep: keep);
  }

  @override
  Future<void> deleteCoachNote(String userId, String id) => _db.deleteCoachNote(userId, id);
}
