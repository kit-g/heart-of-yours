part of '../heart_db.dart';

/// True only in debug builds. Mirrors Flutter's `kDebugMode`: a build is "debug" when it is
/// neither a release (`dart.vm.product`) nor a profile (`dart.vm.profile`) run.
const bool _kDebug = !bool.fromEnvironment('dart.vm.product') && !bool.fromEnvironment('dart.vm.profile');
const _clearDatabase = bool.fromEnvironment('CLEAR_DATABASE');

abstract class _LocalDatabase {
  Database get _db;
}

class LocalDatabase extends _LocalDatabase
    with _Charts, _Exercises, _Stats, _Templates, _Timers, _Workouts
    implements
        ChartPreferenceService,
        ExerciseService,
        ExerciseHistoryService,
        ExercisesMetricsService,
        PreviousExerciseService,
        GalleryService,
        StatsService,
        TemplateService,
        TimersService,
        WorkoutService {
  @override
  final Database _db;

  LocalDatabase._(this._db);

  static Future<LocalDatabase> init({int version = 5, Database? other, bool isWeb = false}) async {
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
