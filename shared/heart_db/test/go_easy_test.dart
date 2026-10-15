import 'package:flutter_test/flutter_test.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'real_database.dart';

/// What a user goes easy on (#396): device-only, by uid.
void main() {
  late Database db;
  late LocalDatabase local;

  setUp(() async {
    db = await openTestDatabase();
    local = await LocalDatabase.init(other: db);
  });

  tearDown(() => db.close());

  test('nothing listed until something is stored', () async {
    expect(await local.getGoEasy('u1'), isEmpty);
  });

  test('a store is the whole list, replacing the one before', () async {
    await local.storeGoEasy('u1', {'knee', 'jumping'});
    expect(await local.getGoEasy('u1'), {'knee', 'jumping'});

    await local.storeGoEasy('u1', {'shoulder'});
    expect(await local.getGoEasy('u1'), {'shoulder'});

    await local.storeGoEasy('u1', {});
    expect(await local.getGoEasy('u1'), isEmpty);
  });

  test('another account on this phone sees nothing of it', () async {
    await local.storeGoEasy('u1', {'knee'});
    expect(await local.getGoEasy('u2'), isEmpty);
  });

  test('an anonymous session signing in takes its list along', () async {
    await local.storeGoEasy('anon', {'lower_back'});
    await local.rekeyUser('anon', 'u1');
    expect(await local.getGoEasy('u1'), {'lower_back'});
    expect(await local.getGoEasy('anon'), isEmpty);
  });

  test('erasing a user erases their list', () async {
    await local.storeGoEasy('u1', {'knee'});
    await local.storeGoEasy('u2', {'wrist'});
    await local.eraseUser('u1');
    expect(await local.getGoEasy('u1'), isEmpty);
    expect(await local.getGoEasy('u2'), {'wrist'});
  });
}
