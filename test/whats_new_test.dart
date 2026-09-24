// The What's new loader against a bundle it can't trust: the per-note `en`
// fallback, a missing or malformed locale file, a malformed `en`, and the
// ordering and "this version" rules the page relies on.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/whats_new.dart';

class _Bundle extends CachingAssetBundle {
  final Map<String, String> files;

  new(this.files);

  @override
  Future<ByteData> load(String key) async {
    return switch (files[key.replaceFirst('$whatsNewDirectory/', '')]) {
      String source => ByteData.sublistView(utf8.encode(source)),
      null => throw FlutterError('Unable to load asset: $key'),
    };
  }
}

String _file(List<Map<String, Object?>> releases) => jsonEncode(releases);

Map<String, Object?> _release(String version, List<(String, String)> notes, {String? date}) {
  return {
    'version': version,
    'date': ?date,
    'items': [
      for (final (id, title) in notes) {'id': id, 'title': title, 'body': '$title body'},
    ],
  };
}

void main() {
  final en = _file([
    _release('1.8.0', [('notes', 'Exercise notes'), ('calendar', 'Calendar')], date: '2026-09-13'),
    _release('1.10.0', [('next', 'Next')]),
    _release('1.9.0', [('later', 'Later')], date: '2026-10-01'),
  ]);

  List<String> titles(List<Release> releases) => [
    for (final release in releases)
      for (final note in release.notes) note.title,
  ];

  test('a note missing from a locale falls back to en, note by note', () async {
    final bundle = _Bundle({
      'en.json': en,
      // one of 1.8.0's two notes translated, the other left for en
      'es.json': _file([
        _release('1.8.0', [('notes', 'Notas del ejercicio')]),
      ]),
    });

    final releases = await loadReleases(bundle, const Locale('es'));

    expect(titles(releases), ['Next', 'Later', 'Notas del ejercicio', 'Calendar']);
  });

  test('a regional locale uses its language file, and en_CA uses en', () async {
    final bundle = _Bundle({
      'en.json': en,
      'es.json': _file([
        _release('1.9.0', [('later', 'Más tarde')]),
      ]),
    });

    expect(titles(await loadReleases(bundle, const Locale('es', 'MX'))), contains('Más tarde'));
    expect(titles(await loadReleases(bundle, const Locale('en', 'CA'))), [
      'Next',
      'Later',
      'Exercise notes',
      'Calendar',
    ]);
  });

  test('versions sort numerically, newest first, whatever order the file has', () async {
    final releases = await loadReleases(_Bundle({'en.json': en}), const Locale('en'));

    expect(releases.map((release) => release.version), ['1.10.0', '1.9.0', '1.8.0']);
  });

  test('an undated release has no date; a dated one parses', () async {
    final releases = await loadReleases(_Bundle({'en.json': en}), const Locale('en'));

    expect(releases.first.date, isNull);
    expect(releases.last.date, DateTime(2026, 9, 13));
  });

  test('a malformed locale file is reported and answered with en', () async {
    final errors = <Object>[];
    final bundle = _Bundle({'en.json': en, 'fr.json': '{ not json'});

    final releases = await loadReleases(
      bundle,
      const Locale('fr'),
      onError: (error, {stacktrace}) => errors.add(error),
    );

    expect(titles(releases), ['Next', 'Later', 'Exercise notes', 'Calendar']);
    expect(errors, hasLength(1));
  });

  test('a malformed or missing en file is an empty list, not a crash', () async {
    final errors = <Object>[];
    void onError(dynamic error, {dynamic stacktrace}) => errors.add(error as Object);

    expect(
      await loadReleases(_Bundle({'en.json': '{"version": "1.0.0"}'}), const Locale('en'), onError: onError),
      isEmpty,
    );
    expect(await loadReleases(_Bundle({'en.json': ''}), const Locale('en'), onError: onError), isEmpty);
    expect(await loadReleases(_Bundle({}), const Locale('en'), onError: onError), isEmpty);
    expect(errors, hasLength(2));
  });

  test('an entry that does not parse is dropped, not the file', () {
    final releases = parseReleases(
      _file([
        _release('1.8.0', [('notes', 'Exercise notes')]),
        {'version': 'next', 'items': <Object>[]},
        {'version': '1.9.0'},
      ]),
    );

    expect(releases.map((release) => release.version), ['1.8.0']);
  });

  group('currentRelease', () {
    final releases = parseReleases(en);

    Release? current(String running) => currentRelease(releases, running);

    test('is the release itself when the running version has an entry', () {
      expect(current('1.9.0')?.version, '1.9.0');
    });

    test('is the newest release before a fix-only version', () {
      expect(current('1.9.4')?.version, '1.9.0');
      expect(current('1.8.5')?.version, '1.8.0');
    });

    test('is nothing before the first release or for an unknown version', () {
      expect(current('1.7.9'), isNull);
      expect(current(''), isNull);
    });
  });
}
