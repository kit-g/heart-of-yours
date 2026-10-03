// The What's new loader against a bundle it can't trust: the per-note `en`
// fallback, a missing or malformed locale file, a malformed `en`, and the
// ordering and "this version" rules the page relies on.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/whats_new.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

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

    final releases = await loadReleases(bundle, const Locale('es'), platform: .iOS);

    expect(titles(releases), ['Next', 'Later', 'Notas del ejercicio', 'Calendar']);
  });

  test('a regional locale uses its language file, and en_CA uses en', () async {
    final bundle = _Bundle({
      'en.json': en,
      'es.json': _file([
        _release('1.9.0', [('later', 'Más tarde')]),
      ]),
    });

    expect(titles(await loadReleases(bundle, const Locale('es', 'MX'), platform: .iOS)), contains('Más tarde'));
    expect(titles(await loadReleases(bundle, const Locale('en', 'CA'), platform: .iOS)), [
      'Next',
      'Later',
      'Exercise notes',
      'Calendar',
    ]);
  });

  test('versions sort numerically, newest first, whatever order the file has', () async {
    final releases = await loadReleases(_Bundle({'en.json': en}), const Locale('en'), platform: .iOS);

    expect(releases.map((release) => release.version), ['1.10.0', '1.9.0', '1.8.0']);
  });

  test('an undated release has no date; a dated one parses', () async {
    final releases = await loadReleases(_Bundle({'en.json': en}), const Locale('en'), platform: .iOS);

    expect(releases.first.date, isNull);
    expect(releases.last.date, DateTime(2026, 9, 13));
  });

  test('a malformed locale file is reported and answered with en', () async {
    final errors = <Object>[];
    final bundle = _Bundle({'en.json': en, 'fr.json': '{ not json'});

    final releases = await loadReleases(
      bundle,
      const Locale('fr'),
      platform: .iOS,
      onError: (error, {stacktrace}) => errors.add(error),
    );

    expect(titles(releases), ['Next', 'Later', 'Exercise notes', 'Calendar']);
    expect(errors, hasLength(1));
  });

  test('a malformed or missing en file is an empty list, not a crash', () async {
    final errors = <Object>[];
    void onError(dynamic error, {dynamic stacktrace}) => errors.add(error as Object);

    expect(
      await loadReleases(
        _Bundle({'en.json': '{"version": "1.0.0"}'}),
        const Locale('en'),
        platform: .iOS,
        onError: onError,
      ),
      isEmpty,
    );
    expect(await loadReleases(_Bundle({'en.json': ''}), const Locale('en'), platform: .iOS, onError: onError), isEmpty);
    expect(await loadReleases(_Bundle({}), const Locale('en'), platform: .iOS, onError: onError), isEmpty);
    expect(errors, hasLength(2));
  });

  test('a note for one platform shows only there, translated, and an emptied release goes', () async {
    final bundle = _Bundle({
      'en.json': _file([
        {
          'version': '1.10.0',
          'items': [
            {
              'id': 'watch',
              'title': 'Apple Watch',
              'body': 'On the wrist.',
              'platforms': ['ios'],
            },
            {'id': 'both', 'title': 'Both', 'body': 'Everywhere.'},
          ],
        },
        {
          'version': '1.9.5',
          'items': [
            {
              'id': 'watch-fix',
              'title': 'Watch fix',
              'body': 'Fixed.',
              'platforms': ['ios'],
            },
          ],
        },
      ]),
      'es.json': _file([
        {
          'version': '1.10.0',
          'items': [
            {'id': 'watch', 'title': 'Apple Watch (es)', 'body': 'En la muñeca.'},
          ],
        },
      ]),
    });

    expect(titles(await loadReleases(bundle, const Locale('es'), platform: .iOS)), [
      'Apple Watch (es)',
      'Both',
      'Watch fix',
    ]);
    final android = await loadReleases(bundle, const Locale('es'), platform: .android);
    expect(titles(android), ['Both'], reason: 'the translation carries no platforms; en decides');
    expect(android.map((release) => release.version), ['1.10.0']);
  });

  test('a note names its feature in en, a translation keeps it, and an unknown one reads as none', () async {
    final bundle = _Bundle({
      'en.json': _file([
        {
          'version': '1.10.0',
          'items': [
            {'id': 'map', 'title': 'Muscle map', 'body': 'On the profile.', 'feature': 'muscleMap'},
            {'id': 'future', 'title': 'Later', 'body': 'Not yet.', 'feature': 'notBuiltYet'},
          ],
        },
      ]),
      'es.json': _file([
        {
          'version': '1.10.0',
          'items': [
            {'id': 'map', 'title': 'Mapa muscular', 'body': 'En el perfil.'},
          ],
        },
      ]),
    });

    final notes = (await loadReleases(bundle, const Locale('es'), platform: .iOS)).single.notes;
    expect(notes.map((note) => (note.title, note.feature)), [
      ('Mapa muscular', Feature.muscleMap),
      ('Later', null),
    ]);
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

  group('WhatsNewBadge (#216)', () {
    late Preferences preferences;
    late AppInfo info;

    Future<WhatsNewBadge> badge({required String running, Map<String, Object> stored = const {}}) async {
      SharedPreferences.setMockInitialValues(stored);
      preferences = Preferences();
      await preferences.init();
      info = AppInfo();
      await info.init(() async => (appName: 'Heart', packageName: 'me.heart-of.ios', version: running, build: '1'));
      final badge = WhatsNewBadge(preferences: preferences, info: info, releases: Future.value(parseReleases(en)));
      addTearDown(badge.dispose);
      await Future<void>.delayed(Duration.zero);
      return badge;
    }

    test('a fresh install starts caught up, and records it', () async {
      final sut = await badge(running: '1.9.0');

      expect(sut.unread, isFalse);
      expect(preferences.whatsNewRead, {'1.8.0/notes', '1.8.0/calendar', '1.9.0/later'});
    });

    test('an update that brings notes shows the dot; opening What\'s new clears it', () async {
      final sut = await badge(
        running: '1.10.0',
        stored: {
          'whatsNewRead': ['1.8.0/notes', '1.8.0/calendar', '1.9.0/later'],
        },
      );
      expect(sut.unread, isTrue);

      sut.markRead();
      expect(sut.unread, isFalse);
      expect(preferences.whatsNewRead, contains('1.10.0/next'));
    });

    test('notes for a version not yet running do not count', () async {
      final sut = await badge(
        running: '1.9.0',
        stored: {
          'whatsNewRead': ['1.8.0/notes', '1.8.0/calendar', '1.9.0/later'],
        },
      );
      expect(sut.unread, isFalse, reason: '1.10.0 is in the file but not in this build');
    });

    test('a note added to a version already read still counts', () async {
      final sut = await badge(
        running: '1.9.0',
        stored: {
          'whatsNewRead': ['1.8.0/notes', '1.9.0/later'],
        },
      );
      expect(sut.unread, isTrue, reason: '1.8.0/calendar was never shown');
    });

    test('says nothing until the version is known', () async {
      SharedPreferences.setMockInitialValues({});
      preferences = Preferences();
      await preferences.init();
      final sut = WhatsNewBadge(preferences: preferences, info: AppInfo(), releases: Future.value(parseReleases(en)));
      addTearDown(sut.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(sut.unread, isFalse);
      expect(preferences.whatsNewRead, isNull, reason: 'not recorded as caught up on a guess');
    });
  });
}
