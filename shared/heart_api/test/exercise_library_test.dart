import 'dart:convert';

import 'package:heart_api/heart_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:network_utils/network_utils.dart' show NetworkException;
import 'package:test/test.dart';

/// The exercise library is static content behind a manifest — see
/// `Cdn.getExerciseLibrary`. The client picks the locale file on-device,
/// downloads it only when the manifest says the cached copy is not current,
/// and then conditionally on the cached ETag.
void main() {
  const version = '5c8ead3a079d0c793d7dabc8f70c65306a2ded7a';
  const allLocales = ['en', 'en_CA', 'ru', 'es', 'es_ES', 'fr', 'fr_CA'];
  const manifestPath = '/static/exercises/index.json';

  /// One library entry in the CDN's shape — the API's anonymous list body —
  /// named after the file it came from, in a script Latin-1 cannot spell.
  Map<String, dynamic> bench(String locale) {
    return {
      'id': '019e8b5d-c52d-729e-be9c-a5403b04fd1b',
      'key': 'bench-press-barbell',
      'own': false,
      'name': 'Жим лёжа ($locale)',
      'category': 'Barbell',
      'target': 'Chest',
      'archived': false,
      'validated': false,
      'unit_system': null,
      'rest_timer': null,
    };
  }

  late List<http.Request> requests;

  /// A CDN publishing [locales] under [version]: every locale file holds one
  /// [bench] and carries [etag], and a matching `If-None-Match` gets the 304.
  /// Objects come back as bare `application/json`, the way S3 serves them.
  Cdn cdnServing({
    String version = version,
    List<String> locales = allLocales,
    String? etag = 'W/"abc"',
    String? tag,
  }) {
    requests = [];
    final cdn = Cdn(gateway: 'cdn.test');
    if (tag != null) cdn.languageTag = () => tag;
    cdn.client = MockClient(
      (request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == manifestPath) {
          return http.Response(
            jsonEncode({'version': version, 'generated_at': '2026-09-06T00:03:13Z', 'locales': locales}),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        final locale = RegExp(r'^/static/exercises/(.+)\.json$').firstMatch(path)?.group(1);
        if (locale == null || !locales.contains(locale)) return http.Response('', 404, request: request);
        if (etag != null && request.headers['If-None-Match'] == etag) {
          return http.Response('', 304, headers: {'etag': etag}, request: request);
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'exercises': [bench(locale)],
            }),
          ),
          200,
          headers: {'content-type': 'application/json', 'etag': ?etag},
          request: request,
        );
      },
    );
    return cdn;
  }

  Iterable<String> paths() => requests.map((each) => each.url.path);

  tearDown(() {
    Cdn.instance
      ..client = null
      ..resolveExercise = null
      ..languageTag = null;
  });

  test('a cold cache fetches the manifest, then the one resolved file', () async {
    final cdn = cdnServing(tag: 'es-ES');

    final (library, stamp) = await cdn.getExerciseLibrary();

    expect(library?.single.name, 'Жим лёжа (es_ES)');
    expect(library?.single.isMine, isFalse);
    expect(library?.single.key, 'bench-press-barbell');
    expect(stamp, (version: version, locale: 'es_ES', etag: 'W/"abc"'));
    expect(paths(), [manifestPath, '/static/exercises/es_ES.json']);
    expect(requests.last.headers.containsKey('If-None-Match'), isFalse);
  });

  test('a current copy costs the manifest alone', () async {
    final cdn = cdnServing(tag: 'es-ES');
    const cached = (version: version, locale: 'es_ES', etag: 'W/"abc"');

    final (library, stamp) = await cdn.getExerciseLibrary(cached: cached);

    expect(library, isNull);
    expect(stamp, cached);
    expect(paths(), [manifestPath]);
  });

  test('a moved version asks for the file conditionally, and a 304 keeps the copy', () async {
    final cdn = cdnServing(tag: 'es-ES');
    const cached = (version: 'an-older-run', locale: 'es_ES', etag: 'W/"abc"');

    final (library, stamp) = await cdn.getExerciseLibrary(cached: cached);

    expect(library, isNull);
    // the version moves on so the next launch skips this round trip
    expect(stamp, (version: version, locale: 'es_ES', etag: 'W/"abc"'));
    expect(paths(), [manifestPath, '/static/exercises/es_ES.json']);
    expect(requests.last.headers['If-None-Match'], 'W/"abc"');
  });

  test('a moved version with changed content downloads the file under its new ETag', () async {
    final cdn = cdnServing(tag: 'es-ES', etag: 'W/"def"');
    const cached = (version: 'an-older-run', locale: 'es_ES', etag: 'W/"abc"');

    final (library, stamp) = await cdn.getExerciseLibrary(cached: cached);

    expect(library, isNotNull);
    expect(stamp, (version: version, locale: 'es_ES', etag: 'W/"def"'));
  });

  test('a locale change downloads the new file, never vouching for it with the old ETag', () async {
    // same version, same ETag on every file: a stale If-None-Match would 304
    final cdn = cdnServing(tag: 'ru');
    const cached = (version: version, locale: 'es_ES', etag: 'W/"abc"');

    final (library, stamp) = await cdn.getExerciseLibrary(cached: cached);

    expect(library?.single.name, 'Жим лёжа (ru)');
    expect(stamp.locale, 'ru');
    expect(requests.last.headers.containsKey('If-None-Match'), isFalse);
  });

  test('a file served without an ETag leaves the stamp without one', () async {
    final cdn = cdnServing(tag: 'en', etag: null);

    final (library, stamp) = await cdn.getExerciseLibrary();

    expect(library, isNotNull);
    expect(stamp.etag, isNull);
  });

  group('locale resolution', () {
    // the API's own resolver vectors (heart-api: api/test/core/request_test.dart)
    Future<String> fileFor(String? tag, {List<String> locales = allLocales}) async {
      final cdn = cdnServing(tag: tag, locales: locales);
      final (_, stamp) = await cdn.getExerciseLibrary();
      return stamp.locale;
    }

    test('an exact tag wins', () async {
      expect(await fileFor('en-CA'), 'en_CA');
      expect(await fileFor('ru'), 'ru');
    });

    test('a regional tag falls back to its bare language', () async {
      expect(await fileFor('es-MX'), 'es');
    });

    test('a bare language falls back to any variant the manifest names', () async {
      expect(await fileFor('en', locales: ['en_CA', 'ru']), 'en_CA');
    });

    test('a language content does not cover falls back to en', () async {
      expect(await fileFor('de-DE'), 'en');
    });

    test('an unwired tag is en', () async {
      expect(await fileFor(null), 'en');
    });
  });

  test('a manifest that is not one is an error, not an empty library', () async {
    final cdn = Cdn(gateway: 'cdn.test');
    cdn.client = MockClient(
      (request) async => http.Response(
        jsonEncode({'templates': []}),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );

    expect(cdn.getExerciseLibrary(), throwsA(isA<FormatException>()));
  });

  test('a file the CDN fails to serve is an error, not an empty library', () async {
    final cdn = Cdn(gateway: 'cdn.test');
    cdn.client = MockClient(
      (request) async => switch (request.url.path) {
        manifestPath => http.Response(
          jsonEncode({'version': version, 'locales': allLocales}),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
        _ => http.Response('', 503, request: request),
      },
    );

    expect(cdn.getExerciseLibrary(), throwsA(isA<NetworkException>()));
  });
}
