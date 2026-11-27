import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What a day looked like when it was set aside (#445) holds health values,
/// so it never leaves the phone (docs/2026-09-05.health-data.md): the skip
/// syncs, its snapshot does not. By source, since where a snapshot may go is
/// a matter of which code can name it.
void main() {
  Iterable<File> dartUnder(String path) {
    return Directory(path).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));
  }

  final names = RegExp('skipsnapshot|skip_snapshot|SkipTraining', caseSensitive: false);

  test('nothing that talks to the server names a snapshot', () {
    for (final file in dartUnder('shared/heart_api/lib')) {
      expect(file.readAsStringSync(), isNot(contains(names)), reason: '${file.path} names a skip snapshot');
    }
  });

  test('the export, the import, the sign-in replay, settings sync, analytics and the assistant never read one', () {
    for (final path in [
      'shared/heart_state/lib/src/export.dart',
      'shared/heart_state/lib/src/import.dart',
      'shared/heart_state/lib/src/upsync.dart',
      'shared/heart_state/lib/src/analytics.dart',
      'shared/heart_state/lib/src/settings_sync.dart',
      'shared/heart_state/lib/src/transcript.dart',
      'lib/presentation/questions/answers.dart',
      'lib/core/env/questions.dart',
      'lib/core/env/shortcuts.dart',
      'lib/core/env/home_widgets.dart',
    ]) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path moved: point this guard at where it went');
      expect(file.readAsStringSync(), isNot(contains(names)), reason: '$path reads a skip snapshot');
    }
  });

  test('a skip goes to the server as it always did: no field of the snapshot rides on it', () {
    // the taker is told of a skip and handed nothing back to put on it
    final programs = File('shared/heart_state/lib/src/programs.dart').readAsStringSync();
    expect(programs, isNot(contains(names)));
    expect(programs, contains('Future<void> Function(TrainingSkip skip, String userId)? onSkipped'));
  });

  test('its state has no remote leg', () {
    final source = File('shared/heart_state/lib/src/skip_snapshots.dart').readAsStringSync();
    expect(source, isNot(contains('Remote')));
    expect(source, isNot(contains('heart_api')));
  });

  test('its errors go through the redacting reporter, never the plain one', () {
    final app = File('lib/presentation/navigation/app.dart').readAsStringSync();
    final provider = app.substring(app.indexOf('Provider<SkipSnapshots>('));
    final create = provider.substring(0, provider.indexOf('return snapshots;'));
    expect(create, contains('onError: reportHealthFailure'));
    expect(create, isNot(contains('reportToSentry')));
  });

  test('what the native side is told about Not today is its words and a day, nothing of the day itself', () {
    final contract = File('lib/core/env/shortcuts.dart').readAsStringSync();
    expect(contract, contains('typedef ShortcutNotToday = ({String label, String done, String? day});'));
  });

  test('forgetting the health mirror empties the snapshots with it', () {
    final health = File('shared/heart_db/lib/src/parts/health.dart').readAsStringSync();
    final delete = health.substring(health.indexOf('Future<void> deleteHealthSamples'));
    expect(delete, contains(r"txn.update(_skipSnapshots, {'body': null}"));
  });
}
