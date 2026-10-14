part of '../../heart_db.dart';

/// Programs (heart-of-yours#346): the entity, the user's steps in it, and the
/// bases its growth rules give each exercise.
///
/// Position is never stored. It is folded on read from the program's finished
/// workouts ([getProgramMarks]) and its actions, by `ProgramPosition.of` in
/// heart_models, the same way the server folds it.
mixin _Programs on _LocalDatabase {
  /// [userId]'s programs, archived ones included, each with its sessions in
  /// order: the order last stored, minus templates that no longer name the
  /// program, plus any that do and are not in it yet (a session filed into the
  /// program on another device), by their own order.
  Future<List<Program>> getPrograms(String userId) async {
    final rows = await _db.query(_programs, where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at, id');
    final sessions = await _db.query(
      _templates,
      columns: ['id', 'program_id'],
      where: 'user_id = ? AND program_id IS NOT NULL',
      whereArgs: [userId],
      orderBy: 'order_in_parent, id',
    );

    final byProgram = <String, List<String>>{};
    for (final row in sessions) {
      byProgram.putIfAbsent(row['program_id'] as String, () => []).add(row['id'] as String);
    }

    return _readable(
      rows,
      (row) {
        final id = row['id'] as String;
        final held = byProgram[id] ?? const <String>[];
        final stored = switch (row['sessions']) {
          final String json => (jsonDecode(json) as List).cast<String>(),
          _ => const <String>[],
        };
        return Program.fromJson({
          'id': id,
          'name': row['name'],
          'note': row['note'],
          'source': row['source'],
          'perWeek': row['per_week'],
          'days': switch (row['days']) {
            final String json => jsonDecode(json),
            _ => null,
          },
          'weeks': row['weeks'],
          'rules': row['rules'],
          'constraint': row['constraint_key'],
          'archived': row['archived'] == 1,
          'sessions': [
            ...stored.where(held.contains),
            ...held.where((each) => !stored.contains(each)),
          ],
          'createdAt': row['created_at'],
        });
      },
      what: 'program',
    );
  }

  /// Replaces [userId]'s programs with [programs]: the write of a full read
  /// from the server. One the server no longer has goes, with its history;
  /// its session templates are the template list's to settle.
  Future<void> storePrograms(Iterable<Program> programs, String userId) {
    return _db.transaction(
      (txn) async {
        final keep = {for (final program in programs) program.id};
        final held = await txn.query(_programs, columns: ['id'], where: 'user_id = ?', whereArgs: [userId]);
        for (final row in held) {
          final id = row['id'] as String;
          if (!keep.contains(id)) await _deleteProgramRow(txn, id);
        }
        for (final program in programs) {
          await _storeProgram(txn, program, userId);
        }
      },
    );
  }

  /// Upserts one program.
  Future<void> storeProgram(Program program, String userId) => _storeProgram(_db, program, userId);

  Future<void> _storeProgram(DatabaseExecutor db, Program program, String userId) async {
    final days = program.days.toList()..sort();
    // `toMap` writes back the rules this build could not read, beside its own
    final Program(:id, :name, :note, :source, :perWeek, :weeks, :constraint, :archived, :sessions, :createdAt) =
        program;
    await db.insert(
      _programs,
      {
        'id': id,
        'user_id': userId,
        'name': name,
        'note': note,
        'source': source,
        'per_week': perWeek,
        'days': days.isEmpty ? null : jsonEncode(days),
        'weeks': weeks,
        'rules': jsonEncode(program.toMap()['rules']),
        'constraint_key': constraint,
        'archived': archived ? 1 : 0,
        'sessions': jsonEncode(sessions),
        'created_at': createdAt?.toUtc().toIso8601String(),
      },
      conflictAlgorithm: .replace,
    );
  }

  /// Deletes a program and its history, as the server does (heart-api#86).
  /// Its sessions go with it, or with [keepTemplates] stay as plain templates.
  /// Its workouts stay, no longer counting toward it.
  Future<void> deleteProgram(String programId, {required bool keepTemplates}) {
    return _db.transaction(
      (txn) async {
        if (keepTemplates) {
          await txn.update(_templates, {'program_id': null}, where: 'program_id = ?', whereArgs: [programId]);
        } else {
          // spelled out rather than left to the cascade, as in `eraseUser`;
          // a workout started from a session keeps no link to it
          await txn.rawUpdate(
            'UPDATE $_workouts SET template_id = NULL WHERE template_id IN (SELECT id FROM $_templates WHERE program_id = ?)',
            [programId],
          );
          await txn.rawDelete(
            'DELETE FROM $_templatesExercises WHERE template_id IN (SELECT id FROM $_templates WHERE program_id = ?)',
            [programId],
          );
          await txn.delete(_templates, where: 'program_id = ?', whereArgs: [programId]);
        }
        await _deleteProgramRow(txn, programId);
      },
    );
  }

  Future<void> _deleteProgramRow(DatabaseExecutor txn, String programId) async {
    await txn.update(_workouts, {'program_id': null}, where: 'program_id = ?', whereArgs: [programId]);
    await txn.delete(_programBases, where: 'program_id = ?', whereArgs: [programId]);
    await txn.delete(_programActions, where: 'program_id = ?', whereArgs: [programId]);
    await txn.delete(_programs, where: 'id = ?', whereArgs: [programId]);
  }

  /// Files [templateId] under [programId] as a session, or takes it out of its
  /// program when null.
  Future<void> setTemplateProgram(String templateId, String? programId) {
    return _db.update(_templates, {'program_id': programId}, where: 'id = ?', whereArgs: [templateId]);
  }

  /// [userId]'s finished workouts of [programId], as the marks its position is
  /// folded from. A workout still under way marks nothing yet.
  Future<List<ProgramMark>> getProgramMarks(String userId, String programId) async {
    final rows = await _db.query(
      _workouts,
      columns: ['template_id', 'start'],
      where: 'user_id = ? AND program_id = ? AND "end" IS NOT NULL',
      whereArgs: [userId, programId],
      orderBy: 'start',
    );
    return [
      for (final row in rows)
        if (DateTime.tryParse(row['start'] as String? ?? '') case final DateTime at)
          ProgramMark(templateId: row['template_id'] as String?, at: at, isWorkout: true),
    ];
  }

  /// [userId]'s program actions, of [programId] or of every program, in the
  /// order they were taken.
  Future<List<ProgramAction>> getProgramActions(String userId, {String? programId}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT a.* FROM $_programActions a
      JOIN $_programs p ON p.id = a.program_id
      WHERE p.user_id = ? ${_ofProgram('a', programId)}
      ORDER BY a.at, a.id
      ''',
      [userId, ?programId],
    );
    return _readable(rows, ProgramAction.fromRow, what: 'program action');
  }

  /// Replaces [programId]'s actions with [actions]: a full read from the
  /// server.
  Future<void> storeProgramActions(String programId, Iterable<ProgramAction> actions) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_programActions, where: 'program_id = ?', whereArgs: [programId]);
        for (final action in actions) {
          await _storeProgramAction(txn, action, programId);
        }
      },
    );
  }

  Future<void> storeProgramAction(ProgramAction action) => _storeProgramAction(_db, action, action.programId!);

  Future<void> _storeProgramAction(DatabaseExecutor db, ProgramAction action, String programId) {
    return db.insert(
      _programActions,
      {
        'id': action.id,
        'program_id': programId,
        'kind': action.kind.value,
        'week': action.week,
        'at': action.at.toUtc().toIso8601String(),
      },
      conflictAlgorithm: .replace,
    );
  }

  /// Undoes an action: the action goes, and the bases it moved with it.
  Future<void> deleteProgramAction(String actionId) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_programBases, where: 'action_id = ?', whereArgs: [actionId]);
        await txn.delete(_programActions, where: 'id = ?', whereArgs: [actionId]);
      },
    );
  }

  /// [userId]'s program bases, of [programId] or of every program, oldest
  /// first: `currentBases` reads the latest per exercise.
  Future<List<ProgramBase>> getProgramBases(String userId, {String? programId}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT b.* FROM $_programBases b
      JOIN $_programs p ON p.id = b.program_id
      WHERE p.user_id = ? ${_ofProgram('b', programId)}
      ORDER BY b.at, b.id
      ''',
      [userId, ?programId],
    );
    return _readable(rows, ProgramBase.fromRow, what: 'program base');
  }

  /// Replaces [programId]'s bases with [bases]: a full read from the server.
  Future<void> storeProgramBases(String programId, Iterable<ProgramBase> bases) {
    return _db.transaction(
      (txn) async {
        await txn.delete(_programBases, where: 'program_id = ?', whereArgs: [programId]);
        for (final base in bases) {
          await _storeProgramBase(txn, base, programId);
        }
      },
    );
  }

  Future<void> storeProgramBase(ProgramBase base) => _storeProgramBase(_db, base, base.programId!);

  Future<void> _storeProgramBase(DatabaseExecutor db, ProgramBase base, String programId) {
    return db.insert(
      _programBases,
      {
        'id': base.id,
        'program_id': programId,
        'exercise_id': base.exerciseId,
        'value': base.value,
        'workout_id': base.workoutId,
        'action_id': base.actionId,
        'at': base.at.toUtc().toIso8601String(),
      },
      conflictAlgorithm: .replace,
    );
  }

  Future<void> deleteProgramBase(String baseId) {
    return _db.delete(_programBases, where: 'id = ?', whereArgs: [baseId]);
  }

  /// The clause narrowing a history read to one program, or none for all.
  static String _ofProgram(String alias, String? programId) {
    return switch (programId) {
      null => '',
      String _ => 'AND $alias.program_id = ?',
    };
  }

  /// Every program reference to the exercise [from] becomes one to [to]: the
  /// bases, and the rule keyed by it, where the target has none of its own.
  /// For a history move and a replay's name-merge.
  static void _rekeyExercise(Batch batch, String userId, {required String from, required String to}) {
    batch
      ..rawUpdate(
        'UPDATE $_programBases SET exercise_id = ? '
        'WHERE exercise_id = ? AND program_id IN (SELECT id FROM $_programs WHERE user_id = ?)',
        [to, from, userId],
      )
      // rules are a JSON object keyed by exercise id; the target's own rule
      // wins, as its preference row does in a move
      ..rawUpdate(
        '''
        UPDATE $_programs
        SET rules = CASE
            WHEN json_type(rules, '\$."' || ? || '"') IS NULL
                THEN json_remove(json_set(rules, '\$."' || ? || '"', json(json_extract(rules, '\$."' || ? || '"'))), '\$."' || ? || '"')
            ELSE json_remove(rules, '\$."' || ? || '"')
        END
        WHERE user_id = ? AND json_type(rules, '\$."' || ? || '"') IS NOT NULL
        ''',
        [to, to, from, from, from, userId, from],
      );
  }
}
