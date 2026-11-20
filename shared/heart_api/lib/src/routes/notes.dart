part of '../api.dart';

/// A coach's notes on their clients (heart-of-yours#556): ciphertext only the
/// coach's own devices open. The server never reads one, and the client never
/// learns they exist.
mixin _NoteRoutes on Requests {
  /// Writes the note [id], the device's own UUIDv7, on [connectionId]: a new
  /// one, or what replaces it. The last write wins.
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content}) async {
    final (json, code) = await put(Router.note(id), body: {'connectionId': connectionId, 'content': content});
    return switch ((code, json)) {
      (200 || 201, Map json) => CoachNote.fromJson(json),
      _ => throw _unexpected(json, code),
    };
  }

  /// One page of this coach's notes, on [connectionId] or on every client.
  /// `cursor` is there only when more follow.
  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor}) async {
    final (json, code) = await get(
      Router.notes,
      query: switch ({'connectionId': ?connectionId, 'cursor': ?cursor}) {
        final Map<String, String> query when query.isNotEmpty => query,
        _ => null,
      },
    );
    return switch ((code, json)) {
      (200, {'notes': final List notes}) => (
        notes: [
          for (final each in notes)
            if (each is Map) CoachNote.fromJson(each),
        ],
        cursor: json['cursor'] as String?,
      ),
      _ => throw _unexpected(json, code),
    };
  }

  /// Deletes the note [id]. One already gone is refused (`not_found`).
  Future<void> deleteNote(String id) async {
    final (json, code) = await delete(Router.note(id));
    if (code != 204) throw _unexpected(json, code);
  }
}
