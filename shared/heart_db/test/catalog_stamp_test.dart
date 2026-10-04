import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_models/heart_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';
import 'utils.dart';

/// The catalog stamp — manifest version, locale file, that file's ETag — sits
/// on the `syncs` row beside the rows it describes. It is what the next
/// launch shows the CDN, so it must move with catalog writes and only with
/// them: a write that stores one user-created exercise says nothing about
/// the library.
void main() {
  late Database db;
  late LocalDatabase local;

  const stamp = (version: 'run-1', locale: 'es_ES', etag: 'W/"abc"');

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  Future<void> storeCatalog(Iterable<Exercise> exercises, ({String version, String locale, String? etag}) stamp) {
    return local.storeExercises(exercises, locale: stamp.locale, version: stamp.version, etag: stamp.etag);
  }

  test('nothing stored, no stamp', () async {
    expect(await local.getCatalogStamp(), isNull);
  });

  test('a catalog write records the stamp beside the rows', () async {
    await storeCatalog([exercise(name: 'Push Up')], stamp);

    expect(await local.getCatalogStamp(), stamp);
    final (_, stored) = await local.getExercises();
    expect(stored.single.name, 'Push Up');
  });

  test('a stamp-less write bumps the sync and leaves the stamp alone', () async {
    await storeCatalog([exercise(name: 'Push Up')], stamp);

    await local.storeExercises([exercise(name: 'My Curl')], userId: 'u1');

    expect(await local.getCatalogStamp(), stamp);
  });

  test('a catalog write replaces the ETag, even with none', () async {
    await storeCatalog([exercise(name: 'Push Up')], stamp);

    await storeCatalog([exercise(name: 'Push Up')], (version: 'run-2', locale: 'es_ES', etag: null));

    // a stale ETag would vouch for rows it never described
    expect(await local.getCatalogStamp(), (version: 'run-2', locale: 'es_ES', etag: null));
  });

  test('an empty catalog write is enough to move the stamp', () async {
    await storeCatalog([exercise(name: 'Push Up')], stamp);
    const moved = (version: 'run-2', locale: 'es_ES', etag: 'W/"abc"');

    await storeCatalog(const [], moved);

    expect(await local.getCatalogStamp(), moved);
    final (_, stored) = await local.getExercises();
    expect(stored, hasLength(1));
  });

  test('a locale recorded without a version is not a stamp', () async {
    // what a v11 cache looks like after the upgrade: the tag it was fetched
    // under, and nothing the CDN could be shown
    await local.storeExercises([exercise(name: 'Push Up')], locale: 'ru');

    expect(await local.getCatalogStamp(), isNull);
  });

  group('search vocabulary (#135)', () {
    const glossary = {
      'db': {
        'words': ['dumbbell'],
      },
      'lats': {
        'muscles': ['latissimus_dorsi'],
      },
    };

    test('aliases round-trip, and an empty list clears the old ones', () async {
      await storeCatalog([
        exercise(name: 'Overhead Press', aliases: ['ohp', 'military press']),
      ], stamp);
      var (_, stored) = await local.getExercises();
      expect(stored.single.aliases, ['ohp', 'military press']);

      await storeCatalog([exercise(name: 'Overhead Press', aliases: [])], stamp);
      (_, stored) = await local.getExercises();
      expect(stored.single.aliases, isEmpty);
    });

    test('the glossary is stored with its catalog and outlives writes that carry none', () async {
      expect(await local.getSearchGlossary(), isNull);

      await local.storeExercises(
        [exercise(name: 'Push Up')],
        locale: stamp.locale,
        version: stamp.version,
        etag: stamp.etag,
        glossary: glossary,
      );
      expect(await local.getSearchGlossary(), glossary);

      // a stamp-only write (the locale file was byte-identical) and one
      // user-created exercise both leave it alone
      await storeCatalog(const [], (version: 'run-2', locale: 'es_ES', etag: null));
      await local.storeExercises([exercise(name: 'My Curl')], userId: 'u1');
      expect(await local.getSearchGlossary(), glossary);
    });
  });
}
