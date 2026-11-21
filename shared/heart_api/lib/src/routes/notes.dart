part of '../api.dart';

/// A coach's notes on their clients (heart-of-yours#556): ciphertext only the
/// coach's own devices open. The server never reads one, and the client never
/// learns they exist.
mixin _NoteRoutes on Requests {
  /// Writes the note [id], the device's own UUIDv7, on [connectionId]: a new
  /// one, or what replaces it. The last write wins.
  Future<CoachNote> saveNote(String id, {required String connectionId, required String content}) async {
    final (json, _) = await put(Router.note(id), body: {'connectionId': connectionId, 'content': content});
    return CoachNote.fromJson(json);
  }

  /// One page of this coach's notes, on [connectionId] or on every client.
  /// `cursor` is there only when more follow.
  Future<({List<CoachNote> notes, String? cursor})> getNotes({String? connectionId, String? cursor}) async {
    final (notes, page) = await _listAt(
      Router.notes,
      'notes',
      query: switch ({'connectionId': ?connectionId, 'cursor': ?cursor}) {
        final Map<String, String> query when query.isNotEmpty => query,
        _ => null,
      },
    );
    return (
      notes: [
        for (final each in notes)
          if (each is Map) CoachNote.fromJson(each),
      ],
      cursor: page['cursor'] as String?,
    );
  }

  /// Deletes the note [id]. One already gone is the [ServerRefusal]
  /// `not_found`.
  Future<void> deleteNote(String id) => delete(Router.note(id));
}
