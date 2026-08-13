part of '../../heart_db.dart';

/// The local mirror of the user's template folders.
///
/// Folders are remote-first — the server mints their ids and settles name
/// conflicts — so this mirror only ever stores what the server has confirmed:
/// [storeTemplateFolders] replaces the whole set on sync, [storeTemplateFolder]
/// upserts a single confirmed write.
mixin _TemplateFolders on _LocalDatabase {
  Future<Iterable<TemplateFolder>> getTemplateFolders(String userId) async {
    final rows = await _db.rawQuery(sql.getTemplateFolders, [userId]);
    return rows.map(TemplateFolder.fromRow);
  }

  Future<void> storeTemplateFolders(Iterable<TemplateFolder> folders, {required String userId}) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_templateFolders, where: 'user_id = ?', whereArgs: [userId]);

        final batch = txn.batch();
        for (final folder in folders) {
          batch.insert(_templateFolders, folder.toDbRow(userId));
        }
        await batch.commit(noResult: true);

        // A folder deleted on another device leaves its templates pointing at a
        // row that no longer exists; the server would have come back with them
        // unfiled, so the mirror follows.
        await txn.rawUpdate(
          'UPDATE $_templates SET folder_id = NULL '
          'WHERE user_id = ? AND folder_id IS NOT NULL '
          'AND folder_id NOT IN (SELECT id FROM $_templateFolders)',
          [userId],
        );
      },
    );
  }

  Future<void> storeTemplateFolder(TemplateFolder folder, {required String userId}) {
    return _db.insert(_templateFolders, folder.toDbRow(userId), conflictAlgorithm: .replace);
  }

  /// Unfiles — never deletes — the templates inside, matching the server's
  /// `ON DELETE SET NULL`.
  Future<void> deleteTemplateFolder(String folderId, {required String userId}) {
    return _db.transaction(
      (txn) async {
        await txn.update(
          _templates,
          {'folder_id': null},
          where: 'folder_id = ?',
          whereArgs: [folderId],
        );
        await txn.delete(
          _templateFolders,
          where: 'id = ? AND user_id = ?',
          whereArgs: [folderId, userId],
        );
      },
    );
  }

  Future<void> fileTemplate(String templateId, {String? folderId}) {
    return _db.update(
      _templates,
      {'folder_id': folderId},
      where: 'id = ?',
      whereArgs: [templateId],
    );
  }
}

extension on TemplateFolder {
  Map<String, dynamic> toDbRow(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'order_index': order,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }
}
