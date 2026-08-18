part of '../heart_db.dart';

/// True only in debug builds. Mirrors Flutter's `kDebugMode`: a build is "debug" when it is
/// neither a release (`dart.vm.product`) nor a profile (`dart.vm.profile`) run.
const bool _kDebug = !bool.fromEnvironment('dart.vm.product') && !bool.fromEnvironment('dart.vm.profile');
const _clearDatabase = bool.fromEnvironment('CLEAR_DATABASE');

abstract class _LocalDatabase {
  Database get _db;

  /// What each table's columns actually are.
  ///
  /// Cached for the life of the connection: every migration runs inside [init],
  /// so the schema cannot change under a query afterwards.
  final _tableColumns = <String, Set<String>>{};

  Future<Set<String>> _columnsOf(DatabaseExecutor db, String table) async {
    if (_tableColumns[table] case Set<String> cached) return cached;

    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return _tableColumns[table] = {for (final row in rows) row['name'] as String};
  }

  /// [row], minus anything [table] has no column for.
  ///
  /// Rows written here are built from model code — `toRow()`, `toMap()` — and
  /// those models live in a different repository, arriving by git dependency. A
  /// field added there shows up as a key with no column behind it, and SQLite
  /// rejects **the whole statement** with `no such column`.
  ///
  /// That failure is far worse than it looks. It took down the catalogue write,
  /// which took down `Exercises.init`, which leaves the app on its loading
  /// spinner forever — the exercises are sitting in memory, and the flag that
  /// says so is never set. A missing migration bricked start-up.
  ///
  /// Dropping the key degrades to exactly how the app behaved before the field
  /// existed: the value is not mirrored, and the reader falls back the way it
  /// already does for a null column. The log is [Level.SEVERE] because it always
  /// means a migration is missing, and it names the column to add.
  Future<Map<String, Object?>> _fitToSchema(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
  ) async {
    final columns = await _columnsOf(db, table);

    // No columns means the schema could not be read, never that the table has
    // none. Narrowing against it would drop every key and write an empty row —
    // silently losing the data this method exists to protect. Pass the row
    // through and let SQLite answer for it, which is the behaviour we had.
    if (columns.isEmpty) return row;

    final unknown = row.keys.where((key) => !columns.contains(key));
    if (unknown.isEmpty) return row;

    _logger.severe(
      'No column on `$table` for ${unknown.join(', ')} — not persisting it. '
      'A model field was added without a migration; add one so the value survives a restart.',
    );

    return {
      for (final MapEntry(:key, :value) in row.entries)
        if (columns.contains(key)) key: value,
    };
  }
}

class LocalDatabase extends _LocalDatabase
    with _Charts, _Exercises, _Goals, _Health, _Stats, _TemplateFolders, _Templates, _Timers, _Workouts
    implements
        ChartPreferenceService,
        ExerciseService,
        ExerciseHistoryService,
        ExercisesMetricsService,
        PreviousExerciseService,
        GalleryService,
        GoalService,
        HealthSampleStore,
        StatsService,
        TemplateService,
        TimersService,
        WorkoutService {
  @override
  final Database _db;

  new _(this._db);

  static Future<LocalDatabase> init({int version = 10, Database? other, bool isWeb = false}) async {
    if (other != null) return LocalDatabase._(other);

    const name = 'heart.db';

    final dir = switch (isWeb) {
      true => 'heart',
      false => await getDatabasesPath(),
    };
    final path = join(dir, name);

    // dev convenience: wipe the DB each launch to iterate on schema/migrations.
    // debug builds ONLY — release and profile persist, so production data
    // survives and offline-stranded workouts can be healed on next launch.
    if (_kDebug && _clearDatabase) {
      await deleteDatabase(path);
    }

    // `getDatabasesPath()` above resolves through the active factory, so it must
    // be called before we override it below to keep returning the native db dir.
    if (isWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else {
      // bundle a modern SQLite (JSON1 always enabled) instead of the OS one,
      // whose JSON functions are missing on Android < 13.
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _logger.info('Local database at $path');
    final db = await openDatabase(
      path,
      version: version,
      onUpgrade: _migrate,
      onCreate: (db, version) => _migrate(db, 0, version),
      onConfigure: (db) async {
        // Neither sqflite_common_ffi nor sqflite_common ever sets a busy
        // handler, and SQLite's default is none — so the first moment two
        // statements contend, the loser fails instantly with SQLITE_BUSY
        // ("database is locked") instead of waiting. The native plugin we
        // replaced above got a timeout for free from Android's SQLiteDatabase;
        // with the ffi factory it has to be asked for on every connection.
        await db.rawQuery('PRAGMA busy_timeout = 5000');

        // Rollback journalling — the default — has a writer block every reader
        // for the length of its transaction, which is how a plain SELECT ends
        // up "locked" behind startup's catalog write. WAL lets them overlap.
        // The setting is persisted in the file header, so re-issuing it on
        // each open is a no-op; the web VFS has no WAL, hence the guard.
        if (!isWeb) await db.rawQuery('PRAGMA journal_mode = WAL');

        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    return LocalDatabase._(db);
  }

  static FutureOr<void> _migrate(Database db, int oldVersion, int newVersion) async {
    _logger.info('Migrating local database from version $oldVersion to $newVersion');

    bool unmigrated(MapEntry<int, List<String>> e) {
      return e.key > oldVersion && e.key <= newVersion;
    }

    final migrations = _migrations.entries.where(unmigrated).expand((e) => e.value);

    return db.transaction(
      (txn) async {
        try {
          for (final sql in migrations) {
            await txn.execute(sql);
          }
        } catch (error, stacktrace) {
          _logger.severe('Error migrating local db from version $oldVersion to $newVersion: $error, $stacktrace');
          rethrow;
        }
      },
    );
  }
}
