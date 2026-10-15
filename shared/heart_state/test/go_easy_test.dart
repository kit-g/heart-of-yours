import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

File _fixture() {
  // `make test-heart_state` runs from the repo root, an IDE from the package
  for (final root in [Directory.current.path, '${Directory.current.path}/shared/heart_state']) {
    if (File('$root/test/fixtures/go_easy.json') case File file when file.existsSync()) return file;
  }
  throw StateError('Cannot find the go-easy fixture');
}

/// Things to go easy on (#396). The fixture is the whole map, rendered by
/// heart-api's `scripts/go_easy_content.py` and trimmed to `en` and `es`.
void main() {
  final fixture = _fixture().readAsStringSync();

  Exercise exercise(
    String id, {
    String category = 'Barbell',
    String target = 'Legs',
    List<String>? groups,
    String impact = 'none',
    String stability = 'free',
    String axialLoad = 'none',
  }) {
    return Exercise.fromJson({
      'id': id,
      'own': groups == null,
      'name': id,
      'category': category,
      'target': target,
      'archived': false,
      'validated': false,
      if (groups != null)
        'movement': {
          'groups': groups,
          'axialLoad': axialLoad,
          'stability': stability,
          'unilateral': false,
          'impact': impact,
          'skill': 'low',
        },
    });
  }

  final lunge = exercise('lunge', groups: ['lunge_split', 'squat']);
  final jumpSquat = exercise('jump-squat', groups: ['plyometric_lower', 'squat'], impact: 'high');
  final legPress = exercise('leg-press', category: 'Machine', groups: ['squat'], stability: 'machine');
  final gobletSquat = exercise('goblet-squat', category: 'Dumbbell', groups: ['squat']);
  final bridge = exercise('bridge', category: 'Reps Only', groups: ['hip_extension_bridge']);
  final curl = exercise('curl', category: 'Dumbbell', target: 'Arms', groups: ['elbow_flexion']);
  final custom = exercise('my-push-up', category: 'Reps Only', target: 'Chest');

  ({GoEasy easy, Map<String, Set<String>> stored}) make({bool published = true, Set<String> listed = const {}}) {
    final stored = <String, Set<String>>{'u1': listed};
    final easy = GoEasy(
      fetch: ({etag}) async => switch (published) {
        true => (body: fixture, etag: '"g1"'),
        false => throw Exception('403'),
      },
      readContent: (_) async => null,
      storeContent: (_, {required body, etag}) async {},
      read: (userId) async => stored[userId] ?? {},
      store: (userId, keys) async => stored[userId] = keys,
    );
    return (easy: easy, stored: stored);
  }

  Future<GoEasy> ready({Set<String> listed = const {}}) async {
    final (:easy, stored: _) = make(listed: listed);
    easy.userId = 'u1';
    await easy.ensure();
    await pumpEventQueue();
    return easy;
  }

  test('the map reads whole: eight areas and three movements, with its copy', () {
    final content = GoEasyContent.read(jsonDecode(fixture))!;
    expect(content.areas.map((each) => each.key), [
      'lower_back', 'knee', 'shoulder', 'wrist', 'neck', 'hip', 'ankle', 'elbow', //
    ]);
    expect(content.movements.map((each) => each.key), ['jumping', 'spine_load', 'overhead']);
    expect(content.explainer?.of('es'), contains('teléfono'));
    final knee = content.areas.firstWhere((each) => each.key == 'knee');
    expect(knee.easierOn.of('en'), 'Easier on your knee');
    expect(knee.easierOn.of('fr_CA'), 'Easier on your knee');
  });

  test('an unknown key or entry costs nothing; a predicate with no known key is dropped', () {
    final content = GoEasyContent.read({
      'version': 2,
      'areas': {
        'knee': {
          'name': {'en': 'Knee'},
          'easierOn': {'en': 'Easier on your knee'},
          'easier': [
            {
              'impact': ['high'],
              'someday': ['x'],
            },
            {
              'someday': ['x'],
            },
          ],
          'prefer': [],
          'more': true,
        },
        'broken': {'name': 3},
      },
    })!;
    final [knee] = content.areas;
    expect(knee.harder, hasLength(1));
    expect(knee.isHarderOn(jumpSquat), isTrue);
    expect(knee.isHarderOn(legPress), isFalse);
  });

  test('a custom exercise matches by category alone', () {
    final content = GoEasyContent.read(jsonDecode(fixture))!;
    final wrist = content.areas.firstWhere((each) => each.key == 'wrist');
    // its push-up groups are unknown without movement data: no match
    expect(wrist.isHarderOn(custom), isFalse);
    expect(wrist.isKinderTo(exercise('mine', category: 'Machine')), isTrue);
  });

  test('nothing listed marks nothing', () async {
    final easy = await ready();
    expect(easy.available, isTrue);
    expect(easy.harderOn(jumpSquat), isEmpty);
    expect(easy.kinderSwaps(lunge, [legPress]), isEmpty);
  });

  test('a listed area marks what is harder on it, and only that', () async {
    final easy = await ready(listed: {'knee'});
    expect(easy.harderOn(lunge).map((each) => each.key), ['knee']);
    expect(easy.harderOn(jumpSquat).map((each) => each.key), ['knee']);
    expect(easy.harderOn(curl), isEmpty);
  });

  test('kinder swaps: the same pattern first, the kinder first, never one harder on the list', () async {
    final easy = await ready(listed: {'knee'});
    final swaps = easy.kinderSwaps(lunge, [lunge, jumpSquat, gobletSquat, legPress, bridge, curl]);
    // the leg press is a squat the map calls kinder (a machine); the goblet
    // squat is a squat; the bridge is no squat, but kinder and for the legs
    expect(swaps, [legPress, gobletSquat, bridge]);
  });

  test('the list is kept by uid on this phone, and another uid reads its own', () async {
    final (:easy, :stored) = make(listed: {'knee'});
    easy.userId = 'u1';
    await pumpEventQueue();
    expect(easy.keys, {'knee'});

    await easy.set({'knee', 'jumping'});
    expect(stored['u1'], {'knee', 'jumping'});

    easy.userId = 'u2';
    await pumpEventQueue();
    expect(easy.keys, isEmpty);
    easy.userId = null;
    expect(easy.keys, isEmpty);
  });

  test('a list that fails to store comes back as it was', () async {
    final errors = [];
    final easy = GoEasy(
      fetch: ({etag}) async => null,
      readContent: (_) async => null,
      storeContent: (_, {required body, etag}) async {},
      read: (_) async => {'knee'},
      store: (_, _) async => throw Exception('disk'),
      onError: (error, {stacktrace}) => errors.add(error),
    )..userId = 'u1';
    await pumpEventQueue();
    await easy.set({'wrist'});
    expect(easy.keys, {'knee'});
    expect(errors, hasLength(1));
  });

  test('a map not published yet: nothing to ask, mark or suggest', () async {
    final (:easy, stored: _) = make(published: false, listed: {'knee'});
    easy.userId = 'u1';
    await easy.ensure();
    await pumpEventQueue();
    expect(easy.available, isFalse);
    expect(easy.listed, isEmpty);
    expect(easy.harderOn(jumpSquat), isEmpty);
  });
}
