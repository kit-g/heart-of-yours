part of '../api.dart';

/// Programs (heart-api#86): programs, their actions and bases, sessions filed
/// under them, and skips (#312).
///
/// A refusal is a [ServerRefusal] naming its `code` (`program_limit`,
/// `program_not_found`, `program_changed`…), as on every other route.
mixin _ProgramRoutes on Requests, _ExerciseNaming {
  /// The account's programs, archived ones included, each naming its session
  /// templates in order. Read whole or not at all: the caller replaces its
  /// programs with these, and one skipped would delete its local copy.
  Future<List<Program>> getPrograms() async {
    final (programs, _) = _listIn(await get(Router.programs), 'programs', from: Router.programs);
    return [for (final each in programs) Program.fromJson(each as Map)];
  }

  /// One of the account's programs: what a push names when a coach sent it,
  /// or the other person changed it (#567).
  Future<Program> getProgram(String programId) async {
    final (json, _) = await get(Router.program(programId));
    return Program.fromJson(json);
  }

  /// What changed in a coach's copy, oldest first, after the change whose
  /// cursor is [since] (#558): a page of them, and the cursor of the next.
  Future<({List<ProgramChange> items, String? cursor})> getProgramChanges(String programId, {String? since}) async {
    final (json, _) = await get(Router.programChanges(programId), query: {'since': ?since});
    return (items: ProgramChanges.fromJson(json).changes, cursor: json['cursor'] as String?);
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
    final (json, created) = _created(await post(Router.programs, body: body));
    return (row: Program.fromJson(json), created: created);
  }

  /// A full replace of [program]'s own fields and rules. Sessions change
  /// through their templates; `source` never changes.
  ///
  /// A coach's copy says which revision the edit started from
  /// ([baseRevision]) and names the edit ([changeId]), so a retry writes once
  /// (#558). `409 program_changed`, with the current `revision`, when the coach
  /// changed the same fields since.
  Future<Program> editProgram(Program program, {int? baseRevision, String? changeId}) async {
    final (json, _) = await put(
      Router.program(program.id!),
      body: {...program.toMap(), 'baseRevision': ?baseRevision, 'changeId': ?changeId},
    );
    return Program.fromJson(json);
  }

  /// Deletes the program and its history. Its sessions go with it, or with
  /// [keepTemplates] stay as plain templates.
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) {
    return delete(
      Router.program(programId),
      query: {if (keepTemplates) 'keepTemplates': 'true'},
    );
  }

  /// Files [template] under [programId] as a session, or takes it out of its
  /// program when null. A template `PUT` with the key spelled out: without
  /// it the server keeps the template where it is, the way a 1.13 save does.
  Future<Template> setTemplateProgram(Template template, {required String? programId}) async {
    final (json, _) = await put(
      Router.template(template.id),
      body: {...template.toMap(), 'programId': programId},
    );
    return Template.fromJson(_named(json));
  }

  /// A page of the account's programs with their history, each whole: every
  /// program without [since], or only the ones whose steps or bases changed
  /// after that cursor (heart-api#458). What this build cannot read comes set
  /// aside in the answer, never dropped: the server sends a program again
  /// only when its history changes.
  ///
  /// A [since] the server no longer knows is the `ServerRefusal`
  /// `stale_cursor`; reading again without one starts over.
  Future<ProgramHistoryChanges> getProgramHistory({String? since}) async {
    final (json, status) = await get(
      Router.programHistory,
      query: switch (since) {
        final String since => {'since': since},
        // no map at all: an empty one would still put a bare `?` on the URL
        null => null,
      },
    );
    try {
      return ProgramHistoryChanges.fromJson(json);
    } catch (_) {
      // a page without its list, say: reported by route, never as a cast
      throw UnreadableAnswer(statusCode: status, method: 'GET', path: '/${Router.programHistory}');
    }
  }

  Future<List<ProgramAction>> getProgramActions(String programId) async {
    final path = Router.programActions(programId);
    final (actions, _) = _listIn(await get(path), 'actions', from: path);
    return _readable(actions, ProgramAction.fromJson);
  }

  /// Records [action]; safe to repeat on its id.
  Future<({ProgramAction row, bool created})> replayProgramAction(ProgramAction action) async {
    final (json, created) = _created(await post(Router.programActions(action.programId!), body: action.toMap()));
    return (row: ProgramAction.fromJson(json), created: created);
  }

  /// Undoes an action, and the bases it moved with it.
  Future<void> deleteProgramAction(String programId, String actionId) {
    return delete(Router.programAction(programId, actionId));
  }

  Future<List<ProgramBase>> getProgramBases(String programId) async {
    final path = Router.programBases(programId);
    final (bases, _) = _listIn(await get(path), 'bases', from: path);
    return _readable(bases, ProgramBase.fromJson);
  }

  /// Records [base]; safe to repeat on its id, and on its exercise and
  /// workout: a second device writing the same bump gets the first one back.
  Future<({ProgramBase row, bool created})> replayProgramBase(ProgramBase base) async {
    final (json, created) = _created(await post(Router.programBases(base.programId!), body: base.toMap()));
    return (row: ProgramBase.fromJson(json), created: created);
  }

  Future<void> deleteProgramBase(String programId, String baseId) {
    return delete(Router.programBase(programId, baseId));
  }

  /// Every skip the account holds ("Not today", #312), newest first: every
  /// page of them, since a program's position reads them whole. Read whole or
  /// not at all, as [getPrograms] is.
  Future<List<TrainingSkip>> getSkips() async {
    final skips = <TrainingSkip>[];
    String? cursor;
    do {
      final (page, json) = _listIn(
        await get(Router.skips, query: {'limit': '100', 'cursor': ?cursor}),
        'skips',
        from: Router.skips,
      );
      skips.addAll(_readable(page, TrainingSkip.fromJson));
      cursor = json['cursor'] as String?;
    } while (cursor != null);
    return skips;
  }

  /// Records [skip]; safe to repeat on its id. A session or program it names
  /// that the account doesn't hold reads as none, so a skip always lands.
  Future<({TrainingSkip row, bool created})> replaySkip(TrainingSkip skip) async {
    final (json, created) = _created(await post(Router.skips, body: skip.toMap()));
    return (row: TrainingSkip.fromJson(json), created: created);
  }

  /// Takes a skip back. One that isn't there is not an error.
  Future<void> deleteSkip(String skipId) => delete(Router.skip(skipId));

  /// Starts a coach's copy that has waited while the student was on something
  /// else (#557). Starting is all it does: the program it replaces is the
  /// caller's to stop following.
  Future<void> startProgram(String programId) => post(Router.programStart(programId));
}
