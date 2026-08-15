// Guards the CSV -> ARB -> gen-l10n translations pipeline.
//
// intl_en.arb is the source of truth. Russian is expected to track it
// exactly; en_CA is allowed to lag behind (import runs on another branch)
// but must never carry keys that English no longer has.
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

/// Resolves the heart_language package root regardless of whether the suite
/// runs from the workspace root (`flutter test shared/heart_language`) or
/// from the package directory itself.
Directory _packageRoot() {
  final candidates = [
    Directory.current,
    Directory('${Directory.current.path}/shared/heart_language'),
  ];
  for (final dir in candidates) {
    if (File('${dir.path}/lib/l10n/intl_en.arb').existsSync()) return dir;
  }
  throw StateError(
    'Could not locate the heart_language package root from '
    '${Directory.current.path}',
  );
}

Map<String, dynamic> _readArb(Directory root, String name) {
  final file = File('${root.path}/lib/l10n/$name');
  if (!file.existsSync()) throw StateError('${file.path} is missing');
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Message keys: everything that is not `@@locale`-style file metadata or a
/// `@key` resource-metadata entry.
Set<String> _messageKeys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@')).toSet();

/// Placeholder names referenced by an ICU message: simple `{name}`
/// substitutions and the arguments of `{name,plural,...}` / `{name,select,...}`.
Set<String> _placeholders(String message) =>
    RegExp(r'\{\s*([a-zA-Z0-9_]+)\s*[,}]').allMatches(message).map((m) => m.group(1)!).toSet();

void main() {
  late Directory root;
  late Map<String, dynamic> en, ru, enCa;
  late Set<String> enKeys, ruKeys, enCaKeys;

  setUpAll(() {
    root = _packageRoot();
    en = _readArb(root, 'intl_en.arb');
    ru = _readArb(root, 'intl_ru.arb');
    enCa = _readArb(root, 'intl_en_CA.arb');
    enKeys = _messageKeys(en);
    ruKeys = _messageKeys(ru);
    enCaKeys = _messageKeys(enCa);
  });

  test('en is non-trivial and declares metadata for every key', () {
    expect(enKeys, isNotEmpty);
    for (final key in enKeys) {
      expect(en.containsKey('@$key'), isTrue, reason: 'missing @$key metadata');
    }
    // No orphan metadata pointing at deleted messages.
    final metaKeys = en.keys.where((k) => k.startsWith('@') && !k.startsWith('@@')).map((k) => k.substring(1));
    expect(
      metaKeys.toSet().difference(enKeys),
      isEmpty,
      reason: 'metadata without a message',
    );
  });

  test('en declared placeholders match the ones used in each message', () {
    for (final key in enKeys) {
      final meta = en['@$key'] as Map<String, dynamic>? ?? const {};
      final declared = ((meta['placeholders'] as Map<String, dynamic>?) ?? const {}).keys.toSet();
      expect(
        declared,
        _placeholders(en[key] as String),
        reason: '@$key placeholders out of sync with the message',
      );
    }
  });

  test('ru has strict two-way key parity with en', () {
    expect(
      enKeys.difference(ruKeys),
      isEmpty,
      reason: 'keys missing from intl_ru.arb',
    );
    expect(
      ruKeys.difference(enKeys),
      isEmpty,
      reason: 'orphan keys in intl_ru.arb',
    );
  });

  test('en_CA is a subset of en (lagging is allowed, orphans are not)', () {
    expect(
      enCaKeys.difference(enKeys),
      isEmpty,
      reason:
          'orphan keys in intl_en_CA.arb — remove keys that '
          'no longer exist in intl_en.arb',
    );
  });

  test('every translated message uses exactly the en placeholders', () {
    for (final (locale, arb, keys) in [
      ('ru', ru, ruKeys),
      ('en_CA', enCa, enCaKeys),
    ]) {
      for (final key in keys.intersection(enKeys)) {
        expect(
          _placeholders(arb[key] as String),
          _placeholders(en[key] as String),
          reason: '$locale/$key placeholders diverge from en',
        );
      }
    }
  });

  test('translation metadata stays paired with its messages', () {
    for (final (locale, arb, keys) in [
      ('ru', ru, ruKeys),
      ('en_CA', enCa, enCaKeys),
    ]) {
      for (final key in keys) {
        expect(
          arb.containsKey('@$key'),
          isTrue,
          reason: '$locale: missing @$key metadata',
        );
      }
    }
  });

  test('translations.csv is well-formed', () {
    final file = File('${root.path}/scripts/translations.csv');
    expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
    // csv 8: fields stay strings unless dynamicTyping is on, delimiter and
    // line endings are auto-detected
    final rows = Csv().decode(file.readAsStringSync());
    expect(rows, isNotEmpty, reason: 'CSV has no header row');

    final header = rows.first.cast<String>();
    expect(
      header.take(2),
      ['id', 'description'],
      reason: 'unexpected CSV header shape',
    );
    for (final locale in ['en', 'en_CA', 'ru']) {
      expect(
        header,
        contains(locale),
        reason: 'CSV lost the $locale column',
      );
    }

    final enColumn = header.indexOf('en');
    final ids = <String>{};
    for (final (i, row) in rows.skip(1).indexed) {
      expect(
        row.length,
        header.length,
        reason:
            'row ${i + 2} has ${row.length} columns, '
            'expected ${header.length}',
      );
      final id = row.first as String;
      expect(id, isNotEmpty, reason: 'row ${i + 2} has an empty id');
      expect(ids.add(id), isTrue, reason: 'duplicate id "$id"');
      expect(
        row[enColumn] as String,
        isNotEmpty,
        reason: 'row ${i + 2} ("$id") has an empty en value',
      );
    }
  });
}
