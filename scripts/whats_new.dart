// Dates a release in What's new (assets/whats_new/en.json).
//
//   dart scripts/whats_new.dart stamp [--version=1.9.0] [--date=2026-10-01]
//
// A release's entry is committed before its tag, and the date it shows is the
// day its prod build ran, so the entry goes in undated. The prod workflows run
// this before building, with no arguments: it dates the entry for the version
// in pubspec.yaml with today's UTC date, inside that build only. At the next
// release the release-notes skill runs it with both arguments to write the
// same date into the committed file.
//
// Only `en.json` carries dates; the other locales take them from it. An
// entry that is already dated, or a version with no entry (a fix-only
// release), is left alone — both are ordinary, so neither fails the build.
//
// Plain Dart, no packages, so it needs nothing but the SDK. It writes the
// same formatting test/whats_new_content_test.dart holds the committed files
// to, so dating an entry is a one-line diff.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.firstOrNull != 'stamp') {
    stderr.writeln('usage: dart scripts/whats_new.dart stamp [--version=x.y.z] [--date=yyyy-mm-dd]');
    exit(64);
  }
  final options = {
    for (final arg in args.skip(1))
      if (RegExp(r'^--(\w+)=(.+)$').firstMatch(arg) case RegExpMatch match) match.group(1)!: match.group(2)!,
  };

  final root = options['root'] ?? '.';
  final version = options['version'] ?? _pubspecVersion(File('$root/pubspec.yaml'));
  final date = options['date'] ?? DateTime.timestamp().toIso8601String().substring(0, 10);
  if (DateTime.tryParse(date) == null || date.length != 10) {
    stderr.writeln('not a yyyy-mm-dd date: $date');
    exit(64);
  }

  final file = File('$root/assets/whats_new/en.json');
  final releases = jsonDecode(file.readAsStringSync()) as List;
  final entry = releases.cast<Map<String, dynamic>>().where((release) => release['version'] == version).firstOrNull;

  switch (entry) {
    case null:
      stdout.writeln('no What\'s new entry for $version; nothing to date');
    case {'date': String existing}:
      stdout.writeln('$version is already dated $existing');
    case Map<String, dynamic> entry:
      entry['date'] = date;
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(releases)}\n');
      stdout.writeln('dated $version $date');
  }
}

String _pubspecVersion(File pubspec) {
  final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    stderr.writeln('no version in ${pubspec.path}');
    exit(65);
  }
  return match.group(1)!;
}
