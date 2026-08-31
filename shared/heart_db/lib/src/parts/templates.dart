part of '../../heart_db.dart';

mixin _Templates on _LocalDatabase implements TemplateService {
  @override
  Future<void> updateTemplate(Template template) {
    return _db.transaction(
      (txn) {
        txn
          ..update(
            _templates,
            {'name': template.name},
            where: 'id = ?',
            whereArgs: [template.id],
          )
          ..delete(
            _templatesExercises,
            where: 'template_id = ?',
            whereArgs: [template.id],
          );

        final batch = txn.batch();

        for (final (index, exercise) in template.indexed) {
          var desc = exercise.map((set) => set.toMap()).toList();
          final ts = DateTime.timestamp();
          batch.insert(
            _templatesExercises,
            {
              // ids double as display order — getTemplates sorts on them — so
              // they must ascend with the exercise's position
              'id': ts.add(Duration(milliseconds: 2 * index)).toIso8601String(),
              'template_id': template.id,
              'exercise_id': exercise.exercise.id,
              'description': jsonEncode(desc),
            },
          );
        }

        return batch.commit(noResult: true);
      },
    );
  }

  @override
  Future<void> deleteTemplate(String templateId) {
    return _db.delete(_templates, where: 'id = ?', whereArgs: [templateId]);
  }

  @override
  Future<Iterable<Template>> getTemplates(String? userId) async {
    final query = userId == null ? sql.getSampleTemplates : sql.getTemplates;
    final args = userId == null ? null : [userId];
    final rows = (await _db.rawQuery(query, args)).map((row) => row.toCamel());
    return rows.map((row) => Template.fromJson(row.toTemplate()));
  }

  @override
  Future<Template> startTemplate({int? order, String? userId}) async {
    final id = DateTime.timestamp().toIso8601String();
    return _db.transaction(
      (txn) async {
        final newOrder = order ?? (await txn.getMaxValue(_templates, 'order_in_parent') + 1);
        return txn
            .insert(
              _templates,
              {
                'id': id,
                'user_id': userId,
                'order_in_parent': newOrder,
              },
            )
            .then<Template>(
              (_) {
                return Template.empty(id: id, order: newOrder);
              },
            );
      },
    );
  }

  @override
  Future<void> storeTemplates(Iterable<Template> templates, {String? userId}) {
    return _db.transaction(
      (txn) async {
        final batch = txn.batch();

        for (final template in templates) {
          batch.insert(
            _templates,
            {
              ...template.toRow(),
              'user_id': userId,
              'folder_id': template.folderId,
            },
            conflictAlgorithm: .replace,
          );

          // The nested folder rides along on every filed template, so the
          // mirror row it points at can be kept fresh in the same write.
          if (template.folder case final TemplateFolder folder when userId != null) {
            batch.insert(
              _templateFolders,
              folder.toDbRow(userId),
              conflictAlgorithm: .replace,
            );
          }

          final ts = DateTime.timestamp();

          for (final (index, exercise) in template.indexed) {
            var desc = exercise.map((set) => set.toMap()).toList();

            batch.insert(
              _templatesExercises,
              {
                'id': ts.add(Duration(milliseconds: 2 * index)).toIso8601String(),
                'template_id': template.id,
                'exercise_id': exercise.exercise.id,
                'description': jsonEncode(desc),
              },
            );
          }
        }

        batch.commit(noResult: true);
      },
    );
  }
}
