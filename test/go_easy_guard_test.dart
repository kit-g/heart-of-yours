import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What a user goes easy on (#396) is health-shaped and never leaves the
/// phone (docs/2026-09-05.health-data.md): heart-api refuses any body with a
/// key like `goEasy`, and this holds the app to never sending one. By source,
/// since where the list may go is a matter of which code can name it.
void main() {
  Iterable<File> dartUnder(String path) {
    return Directory(path).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));
  }

  final names = RegExp('goeasy|go_easy|go-easy', caseSensitive: false);

  test('nothing that talks to the server names the list', () {
    // the map's read is the one exception: content, the same for everyone
    for (final file in dartUnder('shared/heart_api/lib')) {
      final source = file.readAsStringSync().replaceAll(RegExp(r'getGoEasy|_goEasy|/static/go-easy'), '');
      expect(source, isNot(contains(names)), reason: '${file.path} names the go-easy list');
    }
  });

  test('the export, the sign-in replay, settings sync and analytics never read it', () {
    for (final path in [
      'shared/heart_state/lib/src/export.dart',
      'shared/heart_state/lib/src/import.dart',
      'shared/heart_state/lib/src/upsync.dart',
      'shared/heart_state/lib/src/analytics.dart',
      'shared/heart_state/lib/src/feature_sync.dart',
      'lib/presentation/questions/answers.dart',
    ]) {
      final file = File(path);
      if (!file.existsSync()) continue;
      expect(file.readAsStringSync(), isNot(contains(names)), reason: '$path reads the go-easy list');
    }
  });

  test('its errors go through the redacting reporter, never the plain one', () {
    final app = File('lib/presentation/navigation/app.dart').readAsStringSync();
    final provider = app.substring(app.indexOf('ChangeNotifierProvider<GoEasy>'));
    final create = provider.substring(0, provider.indexOf('),\n        ),'));
    expect(create, contains('onError: reportHealthFailure'));
  });

  test('its state has no remote leg', () {
    final source = File('shared/heart_state/lib/src/go_easy.dart').readAsStringSync();
    expect(source, isNot(contains('Remote')));
    expect(source, isNot(contains('heart_api')));
  });
}
