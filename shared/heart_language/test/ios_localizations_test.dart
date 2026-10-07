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
  for (final match in RegExp(r'^"(.+?)" = (".*");$', multiLine: true).allMatches(file.readAsStringSync()))
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

  group('App Shortcuts string catalogs (#285)', () {
    test('the shipped titles catalog and phrase tables are what the translation source generates', () {
      writeIosStringCatalogs(translations, runner);
      final ios = '${root.path}/../../ios/Runner';
      expect(
        File('$ios/Localizable.xcstrings').readAsStringSync(),
        File('${runner.path}/Localizable.xcstrings').readAsStringSync(),
        reason: 'Localizable.xcstrings is stale',
      );
      final languages = translations.keys.where((locale) => !locale.contains('_')).toSet();
      for (final language in languages) {
        final generated = File('${runner.path}/$language.lproj/AppShortcuts.strings');
        final shipped = File('$ios/$language.lproj/AppShortcuts.strings');
        expect(shipped.readAsStringSync(), generated.readAsStringSync(), reason: '$language phrases are stale');
        expect(_strings(shipped), {
          for (final key in runnerShortcutPhraseKeys) translations['en']![key]: translations[language]![key],
        });
      }
      expect(Directory('${runner.path}/en_CA.lproj').existsSync(), isFalse);
    });

    test('every base language localizes every title, and English is the key', () {
      final catalog = jsonDecode(stringCatalog(translations, runnerShortcutTitleKeys)) as Map<String, dynamic>;
      final strings = catalog['strings'] as Map<String, dynamic>;
      final languages = translations.keys.where((locale) => !locale.contains('_') && locale != 'en').toSet();
      for (final key in runnerShortcutTitleKeys) {
        final english = translations['en']![key] as String;
        final localizations = (strings[english] as Map<String, dynamic>)['localizations'] as Map<String, dynamic>;
        expect(localizations.keys.toSet(), languages, reason: key);
        for (final language in languages) {
          expect(localizations[language], {
            'stringUnit': {'state': 'translated', 'value': translations[language]![key]},
          });
        }
      }
    });

    test('the Swift source says the phrases word for word', () {
      // the build reads the phrases out of the source as literals, and the
      // catalog is keyed by them: a word changed on one side only loses the
      // localization silently
      final swift = File('${root.path}/../../ios/Runner/Shortcuts.swift').readAsStringSync();
      for (final key in [...runnerShortcutPhraseKeys, ...runnerShortcutTitleKeys]) {
        final english = (translations['en']![key] as String)
            .replaceAll(r'${applicationName}', r'\(.applicationName)')
            .replaceAll(r'${template}', r'\(\.$template)');
        expect(swift, contains('"$english"'), reason: key);
      }
    });

    test('Siri phrases name the app', () {
      for (final key in runnerShortcutPhraseKeys) {
        for (final locale in translations.keys) {
          final value = translations[locale]![key];
          if (value is String) expect(value, contains(r'${applicationName}'), reason: '$locale/$key');
        }
      }
    });
  });
}
