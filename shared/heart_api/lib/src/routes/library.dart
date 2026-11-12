part of '../api.dart';

/// A coach's library (#557): programs kept apart from their own training,
/// saved as versioned documents, and sent to clients as copies of their own.
mixin _LibraryRoutes on Requests {
  /// The library, a page at a time, without bodies.
  Future<({List<CoachProgram> items, String? cursor})> getLibraryPrograms({String? cursor}) async {
    final (json, code) = await get(Router.libraryPrograms, query: _cursor(cursor));
    return switch ((code, json)) {
      (200, {'programs': List l}) => (items: _readable(l, CoachProgram.fromJson), cursor: json['cursor'] as String?),
      _ => throw json,
    };
  }

  /// One library program, with its body.
  Future<CoachProgram> getLibraryProgram(String programId) async {
    final (json, code) = await get(Router.libraryProgram(programId));
    return switch ((code, json)) {
      (200, Map json) => CoachProgram.fromJson(json),
      _ => throw json,
    };
  }

  /// Saves [body], the shape `POST /programs` takes, under [programId], a
  /// UUIDv7 the device made: the first save makes the program, and each one
  /// after is a new version. The server keeps the ids [body]'s rows carry and
  /// gives one to each row without.
  Future<CoachProgram> saveLibraryProgram(String programId, Map<String, dynamic> body) async {
    final (json, code) = await put(Router.libraryProgram(programId), body: body);
    return switch ((code, json)) {
      (200, Map json) => CoachProgram.fromJson(json),
      _ => throw json,
    };
  }

  /// Deletes the library program. The copies clients hold stay theirs.
  Future<void> deleteLibraryProgram(String programId) async {
    final (json, code) = await delete(Router.libraryProgram(programId));
    if (code != 204) throw json;
  }

  /// Which clients hold a copy, and of which version.
  Future<List<CoachProgramHolder>> getLibraryHolders(String programId) async {
    final (json, code) = await get(Router.libraryHolders(programId));
    return switch ((code, json)) {
      (200, Map json) => CoachProgramHolders.fromJson(json).holders,
      _ => throw json,
    };
  }

  /// Copies the program to each of [connectionIds]. Each answers on its own,
  /// delivered or with a reason, and one refusal stops none.
  Future<List<ProgramDelivery>> sendLibraryProgram(String programId, Iterable<String> connectionIds) async {
    final (json, code) = await post(
      Router.librarySend(programId),
      body: {'connectionIds': connectionIds.toList()},
    );
    return switch ((code, json)) {
      (200, Map json) => ProgramDeliveries.fromJson(json).deliveries,
      _ => throw json,
    };
  }

  /// Brings each of [connectionIds]' copies up to the current version, keeping
  /// the ids of what they trained. It overwrites their own edits to the copy,
  /// as a change that can be put back. Each answers on its own: a copy already
  /// current is left alone, and a connection never sent the program answers
  /// `not_sent`.
  Future<List<ProgramDelivery>> updateLibraryCopies(String programId, Iterable<String> connectionIds) async {
    final (json, code) = await post(
      Router.libraryUpdate(programId),
      body: {'connectionIds': connectionIds.toList()},
    );
    return switch ((code, json)) {
      (200, Map json) => ProgramDeliveries.fromJson(json).deliveries,
      _ => throw json,
    };
  }
}
