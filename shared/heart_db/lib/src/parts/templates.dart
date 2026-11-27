part of '../../heart_db.dart';

mixin _Templates on _LocalDatabase implements TemplateService {
  @override
  Future<void> updateTemplate(Template template) {
    return _db.transaction(
      (txn) {
        txn
          ..update(
            _templates,
            {'name': template.name, 'unread': _Workouts._encodeUnread(template.unread)},
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
          // sets this build could not read stay among the rest, where
          // `fromJson` sets them aside again on the way out (#277)
          final desc = [...exercise.map((set) => set.toMap()), ...exercise.unread];
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
              'plan': _Workouts._encodePlan(exercise),
            },
          );
        }

        return batch.commit(noResult: true);
      },
    );
  }

  /// A workout started from the template keeps no link to it, as on the
  /// server (heart-api#215).
  @override
  Future<void> deleteTemplate(String templateId) {
    return _db.transaction(
      (txn) async {
        await txn.update(_workouts, {'template_id': null}, where: 'template_id = ?', whereArgs: [templateId]);
        await txn.update(_skips, {'template_id': null}, where: 'template_id = ?', whereArgs: [templateId]);
        await txn.delete(_templates, where: 'id = ?', whereArgs: [templateId]);
      },
    );
  }

  @override
  Future<Iterable<Template>> getTemplates(String? userId) async {
    final query = userId == null ? sql.getSampleTemplates : sql.getTemplates;
    final args = userId == null ? null : [userId];
    final rows = (await _db.rawQuery(query, args)).map((row) => row.toCamel());
    return _readable(rows, (row) => Template.fromJson(row.toTemplate()), what: 'template');
  }

  /// A new template gets a platform id here rather than the server's mint,
  /// so that a save — now, or in the replay of an anonymous session's store —
  /// lands on the same row when it is repeated. The server validates the
  /// shape (heart-api#66), so it has to be a v7 uuid, not the timestamp this
  /// used to hand out; `Template.createdAt` reads the instant out of either.
  @override
  Future<Template> startTemplate({int? order, String? userId}) async {
    final id = uuidV7();
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

  /// Marks [templateId] as changed here and not yet on the server (#448),
  /// keeping [base], the server's copy the change started from. A template
  /// already marked keeps the base it has: the server never saw what came
  /// between. The mark outlives every store of the row, until
  /// [clearTemplateUnsent].
  Future<void> markTemplateUnsent(String templateId, Template base) {
    return _db.rawUpdate(
      'UPDATE $_templates SET unsent_base = coalesce(unsent_base, ?) WHERE id = ?',
      [jsonEncode(base.toMap()), templateId],
    );
  }

  /// The templates of [userId] that owe the server a change, each with the
  /// copy the change started from, or null where that copy cannot be read.
  Future<Map<String, Template?>> getUnsentTemplates(String userId) async {
    final rows = await _db.query(
      _templates,
      columns: ['id', 'unsent_base'],
      where: 'user_id = ? AND unsent_base IS NOT NULL',
      whereArgs: [userId],
    );
    Template? read(Object? json) {
      try {
        return Template.fromJson(jsonDecode(json as String) as Map);
      } catch (_) {
        return null;
      }
    }

    return {for (final row in rows) row['id'] as String: read(row['unsent_base'])};
  }

  /// The change reached the server, or was let go.
  Future<void> clearTemplateUnsent(String templateId) {
    return _db.update(_templates, {'unsent_base': null}, where: 'id = ?', whereArgs: [templateId]);
  }

  @override
  Future<void> storeTemplates(Iterable<Template> templates, {String? userId}) {
    return _db.transaction(
      (txn) async {
        // The insert below replaces the row, and with it what the row owes
        // the server (#448). Not every caller stores the server's copy (a
        // program files its sessions through here), so the mark is carried
        // over, and letting go of it is [clearTemplateUnsent]'s alone.
        final owed = {
          for (final row in await txn.query(
            _templates,
            columns: ['id', 'unsent_base'],
            where: 'unsent_base IS NOT NULL',
          ))
            row['id']: row['unsent_base'],
        };
        final batch = txn.batch();

        for (final template in templates) {
          batch.insert(
            _templates,
            {
              ...template.toRow(),
              'user_id': userId,
              'folder_id': template.folderId,
              // a session names its program (#346); `toRow` predates both
              'program_id': template.programId,
              'note': template.note,
              'joined': template.joined?.toUtc().toIso8601String(),
              // an assigned template stays one when read back (#448)
              'assigned_by': switch (template.assignedBy) {
                // by `Profile.fromJson`'s keys: its own `toMap` writes the name
                // under one `fromJson` does not read
                final Profile profile => jsonEncode({
                  'id': profile.id,
                  'username': profile.name,
                  'avatar': profile.avatar,
                }),
                null => null,
              },
              'source_template_id': template.sourceTemplateId,
              'sync_enabled': switch (template.syncEnabled) {
                final bool enabled => enabled ? 1 : 0,
                null => null,
              },
              // exercises this build could not read (#277)
              'unread': _Workouts._encodeUnread(template.unread),
              'unsent_base': owed[template.id],
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
            // sets this build could not read stay among the rest, where
            // `fromJson` sets them aside again on the way out (#277)
            final desc = [...exercise.map((set) => set.toMap()), ...exercise.unread];

            batch.insert(
              _templatesExercises,
              {
                'id': ts.add(Duration(milliseconds: 2 * index)).toIso8601String(),
                'template_id': template.id,
                'exercise_id': exercise.exercise.id,
                'description': jsonEncode(desc),
                'plan': _Workouts._encodePlan(exercise),
              },
            );
          }
        }

        batch.commit(noResult: true);
      },
    );
  }
}
