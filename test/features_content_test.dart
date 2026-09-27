// docs/features.json, held to the contract the heart-of.me feature page assumes.
// Every mobile deploy uploads it, and the page renders it
// without judgement, so anything malformed here is published as-is.
//
// The contract (release-notes skill, "Feature list"):
// - every feature has exactly the known fields, and a stable kebab-case id
// - every feature sits in a declared category, and every category is used
// - `since` is the first release a user could use it in, or null while it is
//   unreleased; never newer than pubspec.yaml
// - titles and pitches are plain text: the generator does not parse markup
// - the file is formatted the way JsonEncoder.withIndent('  ') writes it
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/whats_new.dart';

const _path = 'docs/features.json';
const _featureFields = {'id', 'category', 'title', 'pitch', 'since', 'tier', 'platforms', 'highlight'};
const _tiers = {'free', 'premium', 'coach'};
const _platforms = {'ios', 'android'};
const _pitchLimit = 200;

final _id = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
final _version = RegExp(r'^\d+\.\d+\.\d+$');
final _markup = RegExp(r'[*_`<>\[\]#]');

void main() {
  final source = File(_path).readAsStringSync();
  final json = jsonDecode(source) as Map<String, dynamic>;
  final categories = (json['categories'] as List).cast<Map<String, dynamic>>();
  final features = (json['features'] as List).cast<Map<String, dynamic>>();
  final running = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

  test('is formatted the way JsonEncoder writes it', () {
    expect(source, '${const JsonEncoder.withIndent('  ').convert(json)}\n');
  });

  test('has exactly categories and features at the top', () {
    expect(json.keys.toSet(), {'categories', 'features'});
  });

  test('categories have an id and a title, once each', () {
    for (final category in categories) {
      expect(category.keys.toSet(), {'id', 'title'}, reason: '$category');
      expect(category['id'], matches(_id));
      expect(category['title'], isA<String>().having((title) => title.trim(), 'trimmed', isNotEmpty));
    }
    final ids = categories.map((category) => category['id']);
    expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate category id');
  });

  test('every category is used', () {
    final used = features.map((feature) => feature['category']).toSet();
    for (final category in categories) {
      expect(used, contains(category['id']), reason: 'empty category ${category['id']}');
    }
  });

  group('features', () {
    test('have exactly the known fields, and ids are unique kebab-case', () {
      for (final feature in features) {
        expect(feature.keys.toSet(), _featureFields, reason: '${feature['id']}');
        expect(feature['id'], matches(_id));
      }
      final ids = features.map((feature) => feature['id']);
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate feature id');
    });

    test('sit in a declared category', () {
      final declared = categories.map((category) => category['id']).toSet();
      for (final feature in features) {
        expect(declared, contains(feature['category']), reason: '${feature['id']}');
      }
    });

    test('ship in a released version no newer than pubspec.yaml, or are unreleased', () {
      for (final feature in features) {
        if (feature['since'] case String since) {
          expect(since, matches(_version), reason: '${feature['id']}');
          expect(compareVersions(since, running), lessThanOrEqualTo(0), reason: '${feature['id']} since $since');
        } else {
          expect(feature['since'], isNull, reason: '${feature['id']}');
        }
      }
    });

    test('name a known tier and known platforms', () {
      for (final feature in features) {
        expect(_tiers, contains(feature['tier']), reason: '${feature['id']}');
        final platforms = (feature['platforms'] as List).cast<String>();
        expect(platforms, isNotEmpty, reason: '${feature['id']}');
        expect(_platforms, containsAll(platforms), reason: '${feature['id']}');
        expect(feature['highlight'], isA<bool>(), reason: '${feature['id']}');
      }
    });

    test('have plain-text copy that fits a card', () {
      for (final feature in features) {
        for (final field in ['title', 'pitch']) {
          final text = feature[field] as String;
          expect(text.trim(), isNotEmpty, reason: '${feature['id']}.$field');
          expect(text, isNot(contains(_markup)), reason: '${feature['id']}.$field is not plain text');
        }
        expect((feature['pitch'] as String).length, lessThanOrEqualTo(_pitchLimit), reason: '${feature['id']}');
      }
    });
  });
}
