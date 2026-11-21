part of '../api.dart';

/// A coach's library (#557): programs kept apart from their own training,
/// saved as versioned documents, and sent to clients as copies of their own.
mixin _LibraryRoutes on Requests {
  /// The library, a page at a time, without bodies.
  Future<({List<CoachProgram> items, String? cursor})> getLibraryPrograms({String? cursor}) async {
    final (json, _) = await get(Router.libraryPrograms, query: _cursor(cursor));
    return (items: _readable(json['programs'] as List, CoachProgram.fromJson), cursor: json['cursor'] as String?);
  }

  /// One library program, with its body.
  Future<CoachProgram> getLibraryProgram(String programId) async {
    final (json, _) = await get(Router.libraryProgram(programId));
    return CoachProgram.fromJson(json);
  }

  /// Saves [body], the shape `POST /programs` takes, under [programId], a
  /// UUIDv7 the device made: the first save makes the program, and each one
  /// after is a new version. The server keeps the ids [body]'s rows carry and
  /// gives one to each row without.
  Future<CoachProgram> saveLibraryProgram(String programId, Map<String, dynamic> body) async {
    final (json, _) = await put(Router.libraryProgram(programId), body: body);
    return CoachProgram.fromJson(json);
  }

  /// Deletes the library program. The copies clients hold stay theirs.
  Future<void> deleteLibraryProgram(String programId) => delete(Router.libraryProgram(programId));

  /// Which clients hold a copy, and of which version.
  Future<List<CoachProgramHolder>> getLibraryHolders(String programId) async {
    final (json, _) = await get(Router.libraryHolders(programId));
    return CoachProgramHolders.fromJson(json).holders;
  }

  /// Copies the program to each of [connectionIds]. Each answers on its own,
  /// delivered or with a reason, and one refusal stops none.
  Future<List<ProgramDelivery>> sendLibraryProgram(String programId, Iterable<String> connectionIds) async {
    final (json, _) = await post(
      Router.librarySend(programId),
      body: {'connectionIds': connectionIds.toList()},
    );
    return ProgramDeliveries.fromJson(json).deliveries;
  }

  /// Brings each of [connectionIds]' copies up to the current version, keeping
  /// the ids of what they trained. It overwrites their own edits to the copy,
  /// as a change that can be put back. Each answers on its own: a copy already
  /// current is left alone, and a connection never sent the program answers
  /// `not_sent`.
  Future<List<ProgramDelivery>> updateLibraryCopies(String programId, Iterable<String> connectionIds) async {
    final (json, _) = await post(
      Router.libraryUpdate(programId),
      body: {'connectionIds': connectionIds.toList()},
    );
    return ProgramDeliveries.fromJson(json).deliveries;
  }
}
