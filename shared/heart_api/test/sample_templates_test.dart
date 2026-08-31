import 'dart:convert';

import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// Sample templates from the CDN reference exercises by content slug alone
/// (`"exercise": {"key": …}`) — static content cannot know per-database
/// uuids. The client resolves each slug through the live catalog and drops
/// what it cannot resolve; nothing here may crash the caller.
void main() {
  final bench = Exercise.fromJson({
    'id': '019e8b5d-c52d-729e-be9c-a5403b04fd1b',
    'key': 'bench-press-barbell',
    'name': 'Press de banca (barra)',
    'category': 'Barbell',
    'target': 'Chest',
  });

  Map<String, dynamic> entry({required String key, String id = 'we-1'}) {
    return {
      'id': id,
      'exercise': {'key': key},
      'exercise_order': 0,
      'sets': [
        {'id': 'set-1', 'completed': false, 'reps': 5, 'weight': 135},
      ],
    };
  }

  Map<String, dynamic> template(String id, List<Map<String, dynamic>> exercises) {
    return {'id': id, 'name': 'Strength A', 'order': 0, 'exercises': exercises};
  }

  Cdn cdnServing(List<Map<String, dynamic>> templates) {
    final cdn = Cdn(gateway: 'cdn.test');
    cdn.client = MockClient(
      // the transport reads the request back off the response for logging
      (request) async => http.Response(
        jsonEncode({'templates': templates}),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    return cdn;
  }

  tearDown(() {
    Cdn.instance
      ..client = null
      ..resolveExercise = null
      ..languageTag = null;
  });

  test('a resolvable slug becomes the catalog exercise, sets intact', () async {
    final cdn = cdnServing([
      template('t1', [entry(key: 'bench-press-barbell')]),
    ]);
    cdn.resolveExercise = (key) => key == bench.key ? bench : null;

    final samples = (await cdn.getSampleTemplates()).toList();

    expect(samples, hasLength(1));
    final exercise = samples.single.first;
    expect(exercise.exercise.id, bench.id);
    expect(exercise.exercise.name, 'Press de banca (barra)');
    expect(exercise.single.reps, 5);
  });

  test('an unknown slug drops the entry; a template left empty is not offered', () async {
    final cdn = cdnServing([
      template('t1', [entry(key: 'bench-press-barbell'), entry(key: 'newer-than-this-catalog', id: 'we-2')]),
      template('t2', [entry(key: 'newer-than-this-catalog')]),
    ]);
    cdn.resolveExercise = (key) => key == bench.key ? bench : null;

    final samples = (await cdn.getSampleTemplates()).toList();

    expect(samples, hasLength(1));
    expect(samples.single.id, 't1');
    expect(samples.single, hasLength(1));
  });

  group('localized names', () {
    Map<String, dynamic> pushDay() {
      return {
        ...template('t1', [entry(key: 'bench-press-barbell')]),
        'name': 'Push Day',
        'i18n': {'es': 'Día de empuje', 'fr': 'Séance push', 'ru': 'Жимовой день'},
      };
    }

    Future<String?> nameUnder(String? tag) async {
      final cdn = cdnServing([pushDay()]);
      cdn.resolveExercise = (key) => key == bench.key ? bench : null;
      if (tag != null) cdn.languageTag = () => tag;
      final samples = await cdn.getSampleTemplates();
      return samples.singleOrNull?.name;
    }

    test('a regional device tag falls back to its bare language', () async {
      expect(await nameUnder('es-MX'), 'Día de empuje');
    });

    test('an exact match wins', () async {
      expect(await nameUnder('ru'), 'Жимовой день');
    });

    test('a language content does not cover falls back to the en copy', () async {
      // en_CA is omitted from content wherever spelling does not differ
      expect(await nameUnder('en-CA'), 'Push Day');
      expect(await nameUnder('de-DE'), 'Push Day');
    });

    test('unwired tag — or a template without i18n — keeps the en copy', () async {
      expect(await nameUnder(null), 'Push Day');

      final cdn = cdnServing([
        template('t1', [entry(key: 'bench-press-barbell')]),
      ]);
      cdn.resolveExercise = (key) => key == bench.key ? bench : null;
      cdn.languageTag = () => 'es-MX';
      final samples = await cdn.getSampleTemplates();
      expect(samples.single.name, 'Strength A');
    });
  });

  test('unwired resolver offers nothing rather than guessing — and does not throw', () async {
    final cdn = cdnServing([
      template('t1', [entry(key: 'bench-press-barbell')]),
    ]);

    expect(await cdn.getSampleTemplates(), isEmpty);
  });
}
