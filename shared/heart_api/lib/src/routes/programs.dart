part of '../api.dart';

/// Programs (heart-api#86): programs, their actions and bases, sessions filed
/// under them, and skips (#312).
mixin _ProgramRoutes on Requests {
  /// The account's programs, archived ones included, each naming its session
  /// templates in order. Read whole or not at all: the caller replaces its
  /// programs with these, and one skipped would delete its local copy.
  Future<List<Program>> getPrograms() async {
    final (json, code) = await get(Router.programs);
    return switch ((code, json)) {
      (200, {'programs': List l}) => [for (final each in l) Program.fromJson(each as Map)],
      _ => throw _programError(json),
    };
  }

  /// One of the account's programs: what a push names when a coach sent it,
  /// or the other person changed it (#567).
  Future<Program> getProgram(String programId) async {
    final (json, code) = await get(Router.program(programId));
    return switch ((code, json)) {
      (200, Map json) => Program.fromJson(json),
      _ => throw _programError(json),
    };
  }

  /// What changed in a coach's copy, oldest first, after the change whose
  /// cursor is [since] (#558): a page of them, and the cursor of the next.
  Future<({List<ProgramChange> items, String? cursor})> getProgramChanges(String programId, {String? since}) async {
    final (json, code) = await get(Router.programChanges(programId), query: {'since': ?since});
    return switch ((code, json)) {
      (200, Map json) => (items: ProgramChanges.fromJson(json).changes, cursor: json['cursor'] as String?),
      _ => throw _programError(json),
    };
  }

  /// Creates [program] with [sessions] as its templates, in one call (heart-api
  /// #214). Safe to repeat on the program's id, like every replayed create:
  /// `created` says whether this call made it. Starting a library program is
  /// this call too, with `source` set; the server never reads the library.
  Future<({Program row, bool created})> replayProgram(Program program, {required Iterable<Template> sessions}) async {
    final body = {
      ...program.toMap()..removeWhere((key, _) => const {'sessions', 'archived', 'createdAt'}.contains(key)),
      'sessions': [
        for (final session in sessions) _withClientId({...session.toMap(), 'folderId': ?session.folderId}),
      ],
    };
    final response = await post(Router.programs, body: body);
    final (json, created) = switch (response) {
      (Map json, 201) => (json, true),
      (Map json, 200) => (json, false),
      (final json, _) => throw _programError(json),
    };
    return (row: Program.fromJson(json), created: created);
  }

  /// A full replace of [program]'s own fields and rules. Sessions change
  /// through their templates; `source` never changes.
  ///
  /// A coach's copy says which revision the edit started from
  /// ([baseRevision]) and names the edit ([changeId]), so a retry writes once
  /// (#558). `409 program_changed`, with the current `revision`, when the coach
  /// changed the same fields since, thrown whole.
  Future<Program> editProgram(Program program, {int? baseRevision, String? changeId}) async {
    final (json, code) = await put(
      Router.program(program.id!),
      body: {...program.toMap(), 'baseRevision': ?baseRevision, 'changeId': ?changeId},
    );
    return switch ((code, json)) {
      (200, Map json) => Program.fromJson(json),
      _ => throw _programError(json),
    };
  }

  /// Deletes the program and its history. Its sessions go with it, or with
  /// [keepTemplates] stay as plain templates.
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) async {
    final (json, code) = await delete(
      Router.program(programId),
      query: {if (keepTemplates) 'keepTemplates': 'true'},
    );
    if (code >= 400) throw _programError(json);
  }

  /// Files [template] under [programId] as a session, or takes it out of its
  /// program when null. A template `PUT` with the key spelled out: without
  /// it the server keeps the template where it is, the way a 1.13 save does.
  Future<Template> setTemplateProgram(Template template, {required String? programId}) async {
    final (json, code) = await put(
      Router.template(template.id),
      body: {...template.toMap(), 'programId': programId},
    );
    return switch ((code, json)) {
      (200, Map json) => Template.fromJson(json),
      _ => throw _programError(json),
    };
  }

  Future<List<ProgramAction>> getProgramActions(String programId) async {
    final (json, code) = await get(Router.programActions(programId));
    return switch ((code, json)) {
      (200, {'actions': List l}) => _readable(l, ProgramAction.fromJson),
      _ => throw _programError(json),
    };
  }

  /// Records [action]; safe to repeat on its id.
  Future<({ProgramAction row, bool created})> replayProgramAction(ProgramAction action) async {
    final (json, code) = await post(Router.programActions(action.programId!), body: action.toMap());
    return switch ((code, json)) {
      (201, Map json) => (row: ProgramAction.fromJson(json), created: true),
      (200, Map json) => (row: ProgramAction.fromJson(json), created: false),
      _ => throw _programError(json),
    };
  }

  /// Undoes an action, and the bases it moved with it.
  Future<void> deleteProgramAction(String programId, String actionId) async {
    final (json, code) = await delete(Router.programAction(programId, actionId));
    if (code >= 400) throw _programError(json);
  }

  Future<List<ProgramBase>> getProgramBases(String programId) async {
    final (json, code) = await get(Router.programBases(programId));
    return switch ((code, json)) {
      (200, {'bases': List l}) => _readable(l, ProgramBase.fromJson),
      _ => throw _programError(json),
    };
  }

  /// Records [base]; safe to repeat on its id, and on its exercise and
  /// workout: a second device writing the same bump gets the first one back.
  Future<({ProgramBase row, bool created})> replayProgramBase(ProgramBase base) async {
    final (json, code) = await post(Router.programBases(base.programId!), body: base.toMap());
    return switch ((code, json)) {
      (201, Map json) => (row: ProgramBase.fromJson(json), created: true),
      (200, Map json) => (row: ProgramBase.fromJson(json), created: false),
      _ => throw _programError(json),
    };
  }

  Future<void> deleteProgramBase(String programId, String baseId) async {
    final (json, code) = await delete(Router.programBase(programId, baseId));
    if (code >= 400) throw _programError(json);
  }

  /// Every skip the account holds ("Not today", #312), newest first: every
  /// page of them, since a program's position reads them whole. Read whole or
  /// not at all, as [getPrograms] is.
  Future<List<TrainingSkip>> getSkips() async {
    final skips = <TrainingSkip>[];
    String? cursor;
    do {
      final (json, code) = await get(Router.skips, query: {'limit': '100', 'cursor': ?cursor});
      switch ((code, json)) {
        case (200, {'skips': final List l}):
          skips.addAll(_readable(l, TrainingSkip.fromJson));
          cursor = json['cursor'] as String?;
        case _:
          throw _programError(json);
      }
    } while (cursor != null);
    return skips;
  }

  /// Records [skip]; safe to repeat on its id. A session or program it names
  /// that the account doesn't hold reads as none, so a skip always lands.
  Future<({TrainingSkip row, bool created})> replaySkip(TrainingSkip skip) async {
    final (json, code) = await post(Router.skips, body: skip.toMap());
    return switch ((code, json)) {
      (201, Map json) => (row: TrainingSkip.fromJson(json), created: true),
      (200, Map json) => (row: TrainingSkip.fromJson(json), created: false),
      _ => throw _programError(json),
    };
  }

  /// Takes a skip back. One that isn't there is not an error.
  Future<void> deleteSkip(String skipId) async {
    final (json, code) = await delete(Router.skip(skipId));
    if (code >= 400) throw _programError(json);
  }

  /// Starts a coach's copy that has waited while the student was on something
  /// else (#557). Starting is all it does: the program it replaces is the
  /// caller's to stop following.
  Future<void> startProgram(String programId) async {
    final (json, code) = await post(Router.programStart(programId));
    if (code != 204) throw _programError(json);
  }

  /// A refusal the program routes name, typed; anything else as it came, the
  /// way the rest of this class throws.
  static Object _programError(Object? body) {
    return switch (ProgramRefusal.of(body)) {
      final ProgramRefusal reason => ProgramRefused(reason),
      null => body ?? const FormatException('empty response'),
    };
  }
}
