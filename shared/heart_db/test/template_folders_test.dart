import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// Against a real in-memory SQLite, not a mock.
///
/// What matters here is relational behaviour a stub cannot hold: the template
/// count is a correlated subquery, deleting or dropping a folder must unfile —
/// never delete — the templates inside, and the folder a template nests on
/// read is reassembled from a JOIN.
void main() {
  late Database db;
  late LocalDatabase local;

  const userId = 'user-1';
  const other = 'user-2';

  TemplateFolder folder({String id = 'folder-1', String name = 'Push', int order = 0}) {
    return TemplateFolder(
      id: id,
      name: name,
      order: order,
      createdAt: DateTime.utc(2026, 8, 1),
    );
  }

  Future<void> insertTemplate(String id, {String? folderId, String? owner = userId}) {
    return db.insert('templates', {
      'id': id,
      'name': 'Template $id',
      'user_id': owner,
      'order_in_parent': 0,
      'folder_id': folderId,
    });
  }

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  group('storeTemplateFolders & getTemplateFolders', () {
    test('round-trips the user\'s folders, counting their templates', () async {
      await local.storeTemplateFolders(
        [folder(), folder(id: 'folder-2', name: 'Pull', order: 1)],
        userId: userId,
      );
      await insertTemplate('t1', folderId: 'folder-1');
      await insertTemplate('t2', folderId: 'folder-1');
      await insertTemplate('t3');

      final folders = await local.getTemplateFolders(userId);

      expect(folders, hasLength(2));
      expect(folders.first.name, 'Push');
      expect(folders.first.templateCount, 2);
      // an empty folder is still a folder, and "counted, zero" is its honest count
      expect(folders.last.name, 'Pull');
      expect(folders.last.templateCount, 0);
    });

    test('orders by position, ties by name case-insensitively', () async {
      await local.storeTemplateFolders(
        [
          folder(id: 'f1', name: 'push', order: 1),
          folder(id: 'f2', name: 'Alice', order: 1),
          folder(id: 'f3', name: 'Zed', order: 0),
        ],
        userId: userId,
      );

      final names = (await local.getTemplateFolders(userId)).map((f) => f.name);

      expect(names, ['Zed', 'Alice', 'push']);
    });

    test('replaces the whole set and unfiles templates left pointing nowhere', () async {
      await local.storeTemplateFolders([folder(), folder(id: 'folder-2', name: 'Pull')], userId: userId);
      await insertTemplate('t1', folderId: 'folder-2');

      // the next sync no longer carries folder-2 — deleted on another device
      await local.storeTemplateFolders([folder()], userId: userId);

      final folders = await local.getTemplateFolders(userId);
      expect(folders.map((f) => f.id), ['folder-1']);

      final [row] = await db.query('templates', where: 'id = ?', whereArgs: ['t1']);
      expect(row['folder_id'], isNull);
    });

    test('does not touch another user\'s folders', () async {
      await local.storeTemplateFolders([folder()], userId: userId);
      await local.storeTemplateFolders([folder(id: 'folder-2', name: 'Theirs')], userId: other);

      expect(await local.getTemplateFolders(userId), hasLength(1));
      expect((await local.getTemplateFolders(other)).single.name, 'Theirs');
    });
  });

  group('deleteTemplateFolder', () {
    test('unfiles the templates inside, never deletes them', () async {
      await local.storeTemplateFolders([folder()], userId: userId);
      await insertTemplate('t1', folderId: 'folder-1');

      await local.deleteTemplateFolder('folder-1', userId: userId);

      expect(await local.getTemplateFolders(userId), isEmpty);
      final [row] = await db.query('templates', where: 'id = ?', whereArgs: ['t1']);
      expect(row['folder_id'], isNull);
    });

    test('will not delete somebody else\'s folder', () async {
      await local.storeTemplateFolders([folder()], userId: other);

      await local.deleteTemplateFolder('folder-1', userId: userId);

      expect(await local.getTemplateFolders(other), hasLength(1));
    });
  });

  group('fileTemplate', () {
    test('files and unfiles', () async {
      await local.storeTemplateFolders([folder()], userId: userId);
      await insertTemplate('t1');

      await local.fileTemplate('t1', folderId: 'folder-1');
      var [row] = await db.query('templates', where: 'id = ?', whereArgs: ['t1']);
      expect(row['folder_id'], 'folder-1');

      await local.fileTemplate('t1');
      [row] = await db.query('templates', where: 'id = ?', whereArgs: ['t1']);
      expect(row['folder_id'], isNull);
    });
  });

  group('templates carry their filing', () {
    test('storeTemplates persists the nested folder and getTemplates rebuilds it', () async {
      final filed = Template.fromJson({
        'id': 'remote-1',
        'name': 'Push day',
        'order': 0,
        'exercises': [],
        'folder': folder().toMap(),
      });

      await local.storeTemplates([filed], userId: userId);
      final [template] = (await local.getTemplates(userId)).toList();

      expect(template.folderId, 'folder-1');
      expect(template.folder?.name, 'Push');
      // the count belongs to the folder list alone; the nested copy never lies
      expect(template.folder?.templateCount, isNull);

      // and the folder itself landed in the mirror, count included
      final folders = await local.getTemplateFolders(userId);
      expect(folders.single.templateCount, 1);
    });

    test('an unfiled template reads back with no folder', () async {
      await insertTemplate('t1');

      final [template] = (await local.getTemplates(userId)).toList();

      expect(template.folder, isNull);
    });
  });
}
