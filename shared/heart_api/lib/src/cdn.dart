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

  /// Injectable for tests, like [Api.client]; production leaves it null and
  /// [Requests] falls back to the plain top-level http functions.
  @override
  http.Client? client;
}
