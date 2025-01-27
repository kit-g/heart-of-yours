import 'package:heart_models/heart_models.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const _exercises = 'exercises';
const _syncs = 'syncs';

const _exerciseTable = """
CREATE TABLE IF NOT EXISTS exercises
(
    exercise     TEXT NOT NULL PRIMARY KEY,
    joint        TEXT NOT NULL,
    level        TEXT NOT NULL,
    modality     TEXT NOT NULL,
    muscle_group TEXT NOT NULL,
    direction    TEXT NOT NULL,
    ulc          TEXT NOT NULL
);
""";

const _syncsTable = """
CREATE TABLE IF NOT EXISTS syncs
(
    "table_name"   TEXT NOT NULL PRIMARY KEY,
    synced_at TEXT DEFAULT current_timestamp
);
""";

final class LocalDatabase implements ExerciseService {
  static late final Database _db;

  static Future<void> init() async {
    var path = await getDatabasesPath();
    // await deleteDatabase(path);

    await openDatabase(
      join(path, 'heart.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(_exerciseTable);
        await db.execute(_syncsTable);
      },
      onConfigure: (db) {
        _db = db;
      },
    );
  }

  @override
  Future<(DateTime?, Iterable<Exercise>)> getExercises() async {
    return _db.transaction<(DateTime?, Iterable<Exercise>)>(
      (txn) async {
        final rows = await txn.query('exercises');
        print(rows);
        final exercises = rows.map(
          (row) {
            final formatted = {
              for (var MapEntry(:key, :value) in row.entries) _toCamel(key): value,
            };
            return Exercise.fromJson(formatted);
          },
        );

        final syncRows = await txn.query(_syncs, where: 'table_name = ?', whereArgs: [_exercises]);

        if (syncRows case [Map row]) {
          return (DateTime.tryParse(row['synced_at'] ?? ''), exercises);
        }
        return (null, exercises);
      },
    );
  }

  @override
  Future<void> storeExercises(Iterable<Exercise> exercises) async {
    return _db.transaction(
      (txn) {
        final batch = txn.batch();
        for (var each in exercises) {
          var row = {
            for (var MapEntry(:key, :value) in each.toMap().entries) _toSnake(key): value,
          };
          batch.insert(_exercises, row, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        txn.insert(_syncs, {'table_name': _exercises});

        return batch.commit(noResult: true);
      },
    );
  }
}

String _toSnake(String s) {
  return s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]}_${match[2]}').toLowerCase();
}

String _toCamel(String s) {
  final words = s.split('_');
  return words.first + words.skip(1).map((word) => word[0].toUpperCase() + word.substring(1)).join();
}
