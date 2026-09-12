import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../scripts/ios_localizations.dart';

Directory _root() {
  for (final root in [Directory.current, Directory('${Directory.current.path}/shared/heart_language')]) {
    if (File('${root.path}/lib/l10n/intl_en.arb').existsSync()) return root;
  }
  throw StateError('Cannot find heart_language');
}

Map<String, String> _strings(File file) => {
  for (final match in RegExp(r'^"(\w+)" = (".*");$', multiLine: true).allMatches(file.readAsStringSync()))
    match[1]!: jsonDecode(match[2]!) as String,
};

void main() {
  late Directory runner;
  late Map<String, Map<String, dynamic>> translations;
  late Directory root;
  late String originalPlist;

  setUp(() {
    root = _root();
    runner = Directory.systemTemp.createTempSync('heart-ios-localizations-');
    originalPlist = File('${root.path}/../../ios/Runner/Info.plist').readAsStringSync();
    File('${runner.path}/Info.plist').writeAsStringSync(originalPlist);
    translations = {
      for (final file in Directory('${root.path}/lib/l10n').listSync().whereType<File>())
        if (RegExp(r'intl_[a-z]{2}(?:_[A-Z]{2})?\.arb$').hasMatch(file.path))
          file.uri.pathSegments.last.replaceFirst('intl_', '').replaceFirst('.arb', ''): {
            ...jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
            ...jsonDecode(
              File('${root.path}/native/l10n/${file.uri.pathSegments.last}').readAsStringSync(),
            ) as Map<String, dynamic>,
          },
    };
  });

  tearDown(() => runner.deleteSync(recursive: true));

  test('all base languages ship both native descriptions from the translation source', () {
    writeIosLocalizations(translations, runner);
    final languages = translations.keys.where((locale) => !locale.contains('_')).toSet();
    final declared = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(originalPlist)![1]!;
    expect(RegExp(r'<string>(.*?)</string>').allMatches(declared).map((m) => m[1]).toSet(), languages);
    for (final language in languages) {
      final generated = File('${runner.path}/$language.lproj/InfoPlist.strings');
      final shipped = File('${root.path}/../../ios/Runner/$language.lproj/InfoPlist.strings');
      expect(shipped.readAsStringSync(), generated.readAsStringSync(), reason: '$language native copy is stale');
      expect(_strings(shipped), {
        'NSHealthShareUsageDescription': translations[language]!['iosHealthShareUsageDescription'],
        'NSHealthUpdateUsageDescription': translations[language]!['iosHealthUpdateUsageDescription'],
      });
    }
    expect(File('${runner.path}/Info.plist').readAsStringSync(), originalPlist, reason: 'English fallback is stale');
    expect(Directory('${runner.path}/en_CA.lproj').existsSync(), isFalse);
  });

  test('native permission messages stay out of Flutter ARBs and generated Dart', () {
    for (final file in Directory('${root.path}/lib/l10n').listSync().whereType<File>()) {
      if (file.path.endsWith('.arb') || file.path.endsWith('.dart')) {
        expect(file.readAsStringSync(), isNot(contains('iosHealth')), reason: file.path);
      }
    }
  });

  test('native strings escape quotes, slashes and line breaks without losing Unicode', () {
    const value = '«Здоровье» "Santé" \\ Salud\nline\r\n\t& < >';
    translations['en']!['iosHealthShareUsageDescription'] = value;
    writeIosLocalizations(translations, runner);
    expect(_strings(File('${runner.path}/en.lproj/InfoPlist.strings'))['NSHealthShareUsageDescription'], value);
    expect(File('${runner.path}/Info.plist').readAsStringSync(), contains('&amp; &lt; &gt;'));
    writeIosLocalizations(translations, runner);
    expect(File('${runner.path}/Info.plist').readAsStringSync(), isNot(contains('&amp;amp;')));
  });

  test('missing base-language copy fails before any native resource is written', () {
    translations['fr']!.remove('iosHealthUpdateUsageDescription');
    expect(() => writeIosLocalizations(translations, runner), throwsStateError);
    expect(runner.listSync().length, 1);
    expect(File('${runner.path}/Info.plist').readAsStringSync(), originalPlist);
  });

  test('missing English fallback key fails rather than silently leaving stale copy', () {
    File('${runner.path}/Info.plist').writeAsStringSync(
      originalPlist.replaceFirst('NSHealthUpdateUsageDescription', 'MissingKey'),
    );
    expect(() => writeIosLocalizations(translations, runner), throwsStateError);
    expect(runner.listSync().length, 1);
  });
}
