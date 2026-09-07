import 'dart:convert';

import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:network_utils/network_utils.dart';

class Cdn with Requests implements RemoteConfigService, HeaderAuthenticatedService {
  @override
  late String gateway;

  static final Cdn instance = Cdn._();

  @override
  Map<String, String>? defaultHeaders;

  /// Resolves a sample template's exercise reference — the env-stable content
  /// slug ([Exercise.key]) — to the live catalog exercise. Wired by the app;
  /// only invoked after the catalog loads, because the samples fetch is
  /// chained behind it. Unwired, every sample is skipped rather than guessed.
  Exercise? Function(String key)? resolveExercise;

  /// What language the user speaks, as a BCP-47 tag — same source the API
  /// client states in `Accept-Language`. Static content gets no per-request
  /// resolution, so the sample templates' localized names are picked here,
  /// on-device. Unwired, names stay in the file's own (English) copy.
  String Function()? languageTag;

  new _();

  factory({required String gateway}) {
    instance.gateway = gateway;
    return instance;
  }

  @override
  void authenticate(Map<String, String> headers) {
    instance.defaultHeaders = headers;
  }

  @override
  void reauthenticate(String sessionToken) {
    // not needed
  }

  @override
  Future<Map> getRemoteConfig() async {
    return {};
  }

  @override
  bool get isAuthenticated => false; // not needed

  @override
  Future<Iterable<Template>> getSampleTemplates() async {
    final (json, _) = await get('/static/templates');
    return switch (json) {
      {'templates': List l} => l.map(_tryParse).nonNulls.toList(),
      _ => [],
    };
  }

  /// Sample templates reference exercises by content slug alone —
  /// `"exercise": {"key": "bench-press-barbell"}` — because static content
  /// cannot know per-database uuids. Each reference is swapped for the
  /// resolved catalog exercise's own payload before parsing, so the model
  /// never sees a stub (and the sample shows localized names for free). An
  /// entry whose slug the catalog does not know is dropped — an older catalog
  /// against newer samples — and a template left with no exercises is not
  /// offered. One malformed sample must not cost the batch, or the caller.
  Template? _tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final exercises = [
        for (final each in (raw['exercises'] as List? ?? const []).cast<Map>())
          if (each['exercise'] case {'key': String key})
            if (resolveExercise?.call(key) case Exercise resolved) {...each, 'exercise': resolved.toMap()},
      ];
      if (exercises.isEmpty) return null;
      return Template.fromJson({...raw, 'exercises': exercises, 'name': _localizedName(raw)});
    } catch (_) {
      return null;
    }
  }

  /// The template's display name in the user's language, resolved with the
  /// same chain the server applies to library copy: exact tag, then bare
  /// language, then the file's own `name` (the `en` copy — which is also how
  /// `en_CA` lands, since content omits it wherever spelling doesn't differ).
  Object? _localizedName(Map raw) {
    final i18n = raw['i18n'];
    final tag = languageTag?.call();
    if (i18n is! Map || tag == null) return raw['name'];

    // device tags come hyphenated (es-MX), content keys may use either
    final canonical = tag.replaceAll('-', '_');
    final language = canonical.split('_').first;
    return i18n[tag] ?? i18n[canonical] ?? i18n[language] ?? raw['name'];
  }

  /// The exercise library as static content: a manifest naming the publishing
  /// run and the locales it wrote, and one file per locale carrying exactly
  /// the API's list body for an anonymous caller (`own: false`, no unit
  /// preferences, archived rows present). Both modes read it here; heart-api
  /// keeps only the user's own exercises.
  ///
  /// Two requests. The manifest is the freshness gate and is always fetched —
  /// two hundred bytes, edge-cached for five minutes; a 304 on it would leave
  /// the client without the locale list it needs to pick a file. The file is
  /// fetched only when the manifest's `version` or the resolved locale differs
  /// from [cached], and then conditionally on the cached ETag: a publish that
  /// touched another language still bumps the version, and the 304 is what
  /// keeps that from costing this one a megabyte. Compression is left to the
  /// transport, which asks for what it can decode.
  ///
  /// Returns the parsed library, or `null` when [cached] is still the current
  /// copy — and in both cases the stamp the cache should carry from now on.
  /// The stamp is what heart_state calls `CatalogStamp`, structurally: the
  /// manifest `version`, the locale file, and that file's ETag.
  Future<(Iterable<Exercise>?, ({String version, String locale, String? etag}))> getExerciseLibrary({
    ({String version, String locale, String? etag})? cached,
  }) async {
    final (manifest, _) = await get('$_library/index.json');
    final (version, locales) = switch (manifest) {
      {'version': String version, 'locales': List locales} => (version, locales.cast<String>()),
      _ => throw FormatException('not an exercise library manifest', manifest),
    };
    final locale = _libraryLocale(languageTag?.call(), locales);

    if (cached != null && cached.version == version && cached.locale == locale) return (null, cached);

    // an ETag only vouches for the file it came with
    final etag = switch (cached) {
      (locale: final same, :final etag, version: _) when same == locale => etag,
      _ => null,
    };
    final response = await (client?.get ?? http.get)(
      Uri.https(gateway, '$_library/$locale.json'),
      headers: {...?defaultHeaders, 'If-None-Match': ?etag},
    );

    return switch (response.statusCode) {
      304 => (null, (version: version, locale: locale, etag: etag)),
      // JSON is UTF-8 by definition, and the object carries no charset for
      // `response.body` to pick it from — it would decode Cyrillic as Latin-1
      200 => switch (jsonDecode(utf8.decode(response.bodyBytes))) {
        {'exercises': List l} => (
          l.map((e) => Exercise.fromJson(e)).toList(),
          (version: version, locale: locale, etag: response.headers['etag']),
        ),
        final body => throw FormatException('not an exercise library', body),
      },
      final code => throw NetworkException(statusCode: code),
    };
  }

  /// The API's own resolution rule, applied on-device over the manifest's
  /// list: the exact tag, then its bare language, then any variant of that
  /// language the manifest names, then `en`. The device tag comes hyphenated
  /// (`es-MX`); files are named the way the server tags locales (`es_MX`).
  /// The list is never hardcoded — adding a locale is a server-only change.
  static String _libraryLocale(String? tag, List<String> locales) {
    if (tag == null) return 'en';
    final canonical = tag.replaceAll('-', '_');
    if (locales.contains(canonical)) return canonical;
    final language = canonical.split('_').first;
    if (locales.contains(language)) return language;
    return locales.firstWhere((each) => each.startsWith('${language}_'), orElse: () => 'en');
  }

  /// Injectable for tests, like [Api.client]; production leaves it null and
  /// [Requests] falls back to the plain top-level http functions.
  @override
  http.Client? client;
}

const _library = '/static/exercises';
