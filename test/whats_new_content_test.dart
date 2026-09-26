// The bundled What's new content, held to the contract the loader and the
// page assume. The page answers a broken file with an empty state rather than
// a crash, but a broken file is a bug in something we ship — this is where it
// is supposed to be caught, before a build carries it.
//
// The contract (release-notes skill, "What's new"):
// - en.json is the list of what exists; every other locale is a subset of it
// - only en carries dates, and only the release being cut may be undated
// - no release is newer than the version in pubspec.yaml
// - bodies are markdown limited to paragraphs, emphasis, lists and links;
//   links are app routes, and a translation keeps its original's links
// - files are formatted the way scripts/whats_new.dart writes them
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/utils/whats_new.dart';
import 'package:markdown/markdown.dart' as md;

const _allowedTags = {'p', 'strong', 'em', 'ul', 'ol', 'li', 'a', 'br'};

final _version = RegExp(r'^\d+\.\d+\.\d+$');
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _html = RegExp(r'<[a-zA-Z/!]');

void main() {
  final directory = Directory(whatsNewDirectory);
  final files = {
    for (final file in directory.listSync().whereType<File>().where((file) => file.path.endsWith('.json')))
      file.uri.pathSegments.last.replaceFirst('.json', ''): file,
  };
  final running = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

  List<Map<String, dynamic>> read(String locale) {
    return (jsonDecode(files[locale]!.readAsStringSync()) as List).cast<Map<String, dynamic>>();
  }

  test('en exists, and every locale the app speaks has a file', () {
    expect(files.keys, containsAll(['en', 'es', 'fr', 'ru']));
  });

  test('every file is formatted the way the stamp script writes it', () {
    for (final MapEntry(key: locale, value: file) in files.entries) {
      final source = file.readAsStringSync();
      final canonical = '${const JsonEncoder.withIndent('  ').convert(jsonDecode(source))}\n';
      expect(source, canonical, reason: '$locale.json');
    }
  });

  group('en', () {
    test('entries have exactly the known fields, and valid versions and dates', () {
      for (final release in read('en')) {
        expect(release.keys.toSet(), {'version', 'date', 'items'}, reason: '$release');
        expect(release['version'], matches(_version));
        if (release['date'] case String date) {
          expect(date, matches(_date));
          expect(DateTime.tryParse(date), isNotNull, reason: date);
        }
      }
    });

    test('only the release being cut is undated', () {
      final undated = read('en').where((release) => release['date'] == null).map((release) => release['version']);
      expect(undated, anyOf(isEmpty, [running]), reason: 'pubspec.yaml is at $running');
    });

    test('no release is newer than pubspec.yaml', () {
      for (final release in read('en')) {
        expect(
          compareVersions(release['version'] as String, running),
          lessThanOrEqualTo(0),
          reason: '${release['version']}',
        );
      }
    });

    test('releases are listed newest first, once each', () {
      final versions = read('en').map((release) => release['version'] as String).toList();
      final sorted = [...versions]..sort((a, b) => compareVersions(b, a));
      expect(versions, sorted);
      expect(versions.toSet(), hasLength(versions.length));
    });
  });

  for (final locale in files.keys) {
    group(locale, () {
      test('parses to the same releases the raw file holds', () {
        final raw = read(locale);
        final parsed = parseReleases(files[locale]!.readAsStringSync());
        expect(parsed.map((release) => release.version), raw.map((release) => release['version']));
        expect(
          parsed.map((release) => release.notes.length),
          raw.map((release) => (release['items'] as List).length),
          reason: 'a note was dropped for missing or mistyped fields',
        );
      });

      test('notes have ids unique within their version, and non-empty text', () {
        for (final release in read(locale)) {
          final items = (release['items'] as List).cast<Map<String, dynamic>>();
          expect(items, isNotEmpty, reason: '${release['version']}');
          final ids = items.map((item) => item['id']).toList();
          expect(ids.toSet(), hasLength(ids.length), reason: '${release['version']}');
          for (final item in items) {
            expect(item.keys.toSet(), {'id', 'title', 'body'}, reason: '$item');
            expect((item['title'] as String).trim(), isNotEmpty);
            expect(item['title'], isNot(contains('\n')));
            expect((item['body'] as String).trim(), isNotEmpty);
          }
        }
      });

      test('bodies use only paragraphs, emphasis, lists and route links', () {
        for (final release in read(locale)) {
          for (final item in (release['items'] as List).cast<Map<String, dynamic>>()) {
            final where = '${release['version']}/${item['id']}';
            final (:tags, :links, :texts) = _walk(item['body'] as String);
            expect(tags.difference(_allowedTags), isEmpty, reason: where);
            expect(texts.where(_html.hasMatch), isEmpty, reason: '$where carries raw HTML');
            for (final link in links) {
              expect(link, startsWith('/'), reason: '$where links outside the app: $link');
              expect(link, isNot(startsWith('//')), reason: where);
            }
          }
        }
      });

      if (locale != 'en') {
        test('is a subset of en that leaves dates to it and keeps its links', () {
          final en = {
            for (final release in read('en'))
              for (final item in (release['items'] as List).cast<Map<String, dynamic>>())
                (release['version'], item['id']): item['body'] as String,
          };
          for (final release in read(locale)) {
            expect(release.keys.toSet(), {'version', 'items'}, reason: '${release['version']}');
            for (final item in (release['items'] as List).cast<Map<String, dynamic>>()) {
              final key = (release['version'], item['id']);
              expect(en.keys, contains(key), reason: 'en has no $key');
              expect(_walk(item['body'] as String).links, _walk(en[key]!).links, reason: '$key');
            }
          }
        });
      }
    });
  }
}

/// Every element tag, link target and text run in [body], parsed the way
/// markdown_widget parses it.
({Set<String> tags, List<String> links, List<String> texts}) _walk(String body) {
  final document = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored, encodeHtml: false);
  final tags = <String>{};
  final links = <String>[];
  final texts = <String>[];

  void visit(md.Node node) {
    switch (node) {
      case md.Element(:final tag, :final attributes, :final children):
        tags.add(tag);
        if (attributes['href'] case String href) links.add(href);
        children?.forEach(visit);
      case md.Text(:final text):
        texts.add(text);
      default:
        texts.add(node.textContent);
    }
  }

  document.parseLines(const LineSplitter().convert(body)).forEach(visit);
  return (tags: tags, links: links, texts: texts);
}
