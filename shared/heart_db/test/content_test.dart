import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

void main() {
  late Database db;
  late LocalDatabase local;

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  test('nothing is kept until something is stored', () async {
    expect(await local.getContent('static/programs'), isNull);
  });

  test('a stored file comes back with its ETag, and a newer one replaces it', () async {
    await local.storeContent('static/programs', body: '{"version": 1}', etag: '"a"');
    expect(await local.getContent('static/programs'), (body: '{"version": 1}', etag: '"a"'));

    await local.storeContent('static/programs', body: '{"version": 2}');
    expect(await local.getContent('static/programs'), (body: '{"version": 2}', etag: null));
    expect(await db.query('content'), hasLength(1));
  });

  test('files are kept apart by key', () async {
    await local.storeContent('static/programs', body: 'p');
    await local.storeContent('static/go-easy', body: 'g');
    expect((await local.getContent('static/programs'))?.body, 'p');
    expect((await local.getContent('static/go-easy'))?.body, 'g');
  });
}
