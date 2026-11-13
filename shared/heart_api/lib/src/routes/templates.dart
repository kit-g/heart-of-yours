part of '../api.dart';

/// Templates and their folders, and sharing a folder.
mixin _TemplateRoutes on Requests implements ApiTemplateFolderService, RemoteTemplateService {
  @override
  Future<bool> deleteTemplate(String templateId) async {
    final (_, code) = await delete('${Router.templates}/$templateId');
    return code == 204;
  }

  @override
  Future<Iterable<Template>?> getTemplates() async {
    final (json, _) = await get(Router.templates);
    return switch (json) {
      {'templates': List l} => _readable(l, Template.fromJson),
      _ => null,
    };
  }

  /// One of the account's templates: a session of a program a push named
  /// (#567). Thrown whole when the server has none by that id.
  Future<Template> getTemplate(String templateId) async {
    final (json, code) = await get(Router.template(templateId));
    return switch ((code, json)) {
      (200, Map json) => Template.fromJson(json),
      _ => throw json,
    };
  }

  @override
  Future<Template> saveTemplate(Template template) async {
    return (await replayTemplate(template)).row;
  }

  /// See [replayWorkout]. Two templates may share a name — no name match here.
  ///
  /// The folder goes as a top-level `folderId`, the one key a create reads it
  /// from: `toMap()` only nests the folder, which the server passes over, and
  /// a copy made inside a folder (#262) would land unfiled.
  Future<({Template row, bool created})> replayTemplate(Template template) async {
    final body = <String, dynamic>{...template.toMap(), 'folderId': ?template.folderId};
    final (json, created) = _created(await post(Router.templates, body: _withClientId(body)));
    return (row: Template.fromJson(json), created: created);
  }

  /// A session of a coach's copy says which revision the edit started from
  /// ([baseRevision]) and names the edit ([changeId]), as [editProgram] does
  /// (#558): `409 program_changed` when the coach changed it since. Anything
  /// but the template is thrown whole.
  @override
  Future<Template> editTemplate(Template template, {int? baseRevision, String? changeId}) async {
    final (json, code) = await put(
      Router.template(template.id),
      body: {...template.toMap(), 'baseRevision': ?baseRevision, 'changeId': ?changeId},
    );
    return switch ((code, json)) {
      (200, Map json) => Template.fromJson(json),
      _ => throw json,
    };
  }

  /// Files [template] into [folderId], or unfiles it when null.
  ///
  /// A dedicated call rather than [editTemplate] because `template.toMap()`
  /// carries no `folderId` key — the server reads its absence as "leave the
  /// filing alone" — and because the PUT is a full replace, the body must be
  /// the whole template, not the one changed field.
  Future<Template> moveTemplate(Template template, {required String? folderId}) async {
    final (json, code) = await put(
      Router.template(template.id),
      body: {
        ...template.toMap(),
        'folderId': folderId,
      },
    );
    return switch ((code, json)) {
      (200, Map json) => Template.fromJson(json),
      _ => throw json,
    };
  }

  /// The interface is owner-scoped for the server's sake; over HTTP the caller
  /// is whoever the auth header says, so [userId] plays no part in the request.
  @override
  Future<Iterable<TemplateFolder>> getFolders({required String userId}) async {
    final (json, code) = await get(Router.templateFolders);
    return switch ((code, json)) {
      // whole or not at all: the caller replaces its folders with these, so a
      // folder skipped here would delete its local copy (see [_readable])
      (200, {'folders': List l}) => _readable(l, TemplateFolder.fromJson),
      _ => throw json,
    };
  }

  @override
  Future<TemplateFolder> createFolder({required String userId, required TemplateFolder folder}) async {
    return (await replayFolder(folder)).row;
  }

  /// See [replayWorkout]. A `200` here can also be a name match, like
  /// [replayExercise]: the account's folder by that name comes back, under
  /// its own id. A folder made in the app carries no id until the server
  /// mints one, so the key is sent only when there is one to send.
  Future<({TemplateFolder row, bool created})> replayFolder(TemplateFolder folder) async {
    final (json, created) = _created(
      await post(
        Router.templateFolders,
        body: {'id': ?folder.id, 'name': folder.name, 'order': folder.order},
      ),
    );
    return (row: TemplateFolder.fromJson(json), created: created);
  }

  @override
  Future<TemplateFolder> updateFolder({
    required String userId,
    required String folderId,
    required TemplateFolder folder,
  }) async {
    final (json, code) = await put(
      Router.templateFolder(folderId),
      body: {'name': folder.name, 'order': folder.order},
    );
    return switch ((code, json)) {
      (200, Map json) => TemplateFolder.fromJson(json),
      _ => throw json,
    };
  }

  @override
  Future<void> deleteFolder({required String userId, required String folderId}) async {
    final (json, code) = await delete(Router.templateFolder(folderId));
    if (code >= 400) throw json;
  }

  @override
  Future<Iterable<TemplateShare>> shareFolder({
    required String coachId,
    required String targetUserId,
    required String folderId,
  }) async {
    final (json, code) = await post(Router.folderShare(targetUserId, folderId));
    return switch ((code, json)) {
      (200, {'shares': List l}) => _readable(l, _shareFromJson),
      _ => throw json,
    };
  }

  /// [TemplateShare] only knows how to read itself off a database row; this is
  /// its wire shape, which nests the student as `assignedTo`.
  static TemplateShare _shareFromJson(Map json) {
    return TemplateShare(
      id: json['id'].toString(),
      masterTemplateId: json['masterTemplateId'].toString(),
      studentTemplateId: json['studentTemplateId'].toString(),
      templateName: json['templateName'] as String? ?? '',
      assignedTo: switch (json['assignedTo']) {
        final Map m => Profile.fromJson(m),
        _ => throw ArgumentError.value(json, 'assignedTo', 'a share needs its student'),
      },
      assignedAt: switch (json['assignedAt']) {
        final String s => DateTime.parse(s),
        _ => DateTime.timestamp(),
      },
    );
  }
}
