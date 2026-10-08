import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../scripts/android_localizations.dart';

Directory _root() {
  for (final root in [Directory.current, Directory('${Directory.current.path}/shared/heart_language')]) {
    if (File('${root.path}/lib/l10n/intl_en.arb').existsSync()) return root;
  }
  throw StateError('Cannot find heart_language');
}

void main() {
  late Directory res;
  late Map<String, Map<String, dynamic>> translations;
  late Directory root;

  setUp(() {
    root = _root();
    res = Directory.systemTemp.createTempSync('heart-android-localizations-');
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

  tearDown(() => res.deleteSync(recursive: true));

  test('the shipped launcher labels are what the translation source generates, per base language', () {
    writeAndroidLocalizations(translations, res);
    final shippedRes = '${root.path}/../../android/app/src/main/res';
    final languages = translations.keys.where((locale) => !locale.contains('_')).toSet();
    for (final language in languages) {
      final folder = language == 'en' ? 'values' : 'values-$language';
      final generated = File('${res.path}/$folder/strings_shortcuts.xml');
      final shipped = File('$shippedRes/$folder/strings_shortcuts.xml');
      expect(shipped.readAsStringSync(), generated.readAsStringSync(), reason: '$language launcher labels are stale');
      expect(
        generated.readAsStringSync(),
        contains('<string name="shortcut_start_workout">${translations[language]!['androidShortcutStart']}</string>'),
      );
    }
    expect(Directory('${res.path}/values-en_CA').existsSync(), isFalse);
  });

  test('labels escape what the resource compiler reads as markup', () {
    translations['en']!['androidShortcutStart'] = 'Let\'s "go" & <lift>';
    expect(
      androidStrings(translations, 'en'),
      contains('<string name="shortcut_start_workout">Let\\\'s \\"go\\" &amp; &lt;lift&gt;</string>'),
    );
  });
}
