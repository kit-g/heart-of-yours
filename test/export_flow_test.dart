// "Export my data" (#95) through the real app, minus the native piece: the
// share sheet is faked at the platform-interface seam, the way the import
// flow fakes the file picker. The test drives the real settings row and the
// real page over a mocked store, and reads the file that reaches the sheet.
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
// hide Page: heart_models' pagination Page collides with Flutter's navigator Page
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

class _FakeShare extends SharePlatform with MockPlatformInterfaceMixin {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return ShareResult.unavailable;
  }
}

/// One finished workout in the mirror: a bench session of two sets.
Workout _workout() {
  return Workout.fromJson({
    'id': 'w1',
    'name': 'Push day',
    'start': '2026-03-01T10:00:00.000Z',
    'end': '2026-03-01T11:00:00.000Z',
    'exercises': [
      {
        'id': 'we-1',
        'order': 0,
        'exercise': {'id': 'ex-bench', 'name': 'Bench Press (Barbell)', 'category': 'Barbell', 'target': 'Chest'},
        'sets': [
          {'id': 's1', 'weight': 60, 'reps': 8, 'completed': 1},
          {'id': 's2', 'weight': 62.5, 'reps': 6, 'completed': 1},
        ],
      },
    ],
    'synced': 1,
  });
}

/// An [AccountSummary] over the collections a test cares about.
AccountSummary _summary(Map<ExportableCollection, ({int count, String? head})> rows) {
  return AccountSummary(
    collections: {
      for (final MapEntry(:key, value: (:count, :head)) in rows.entries)
        key: CollectionSummary(count: count, latestId: head),
    },
  );
}

void main() {
  // `SharePlus.instance` captures the platform once, on first use, so one
  // fake serves the whole file and is emptied between tests
  final share = _FakeShare();

  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUpAll(() => SharePlatform.instance = share);

  setUp(() {
    share.shared.clear();
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    stubStartup(db, api);

    when(db.getWorkoutHistory(any)).thenAnswer((_) async => [_workout()]);
    when(db.getTemplates(any)).thenAnswer((_) async => <Template>[]);
    when(db.getTemplateFolders(any)).thenAnswer((_) async => <TemplateFolder>[]);
    when(db.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(
      db.getTargetUserGoals(
        requesterId: anyNamed('requesterId'),
        targetUserId: anyNamed('targetUserId'),
        archived: anyNamed('archived'),
      ),
    ).thenAnswer((_) async => <Goal>[]);
  });

  Future<void> pumpToSettings(WidgetTester tester, {required MockFirebaseAuth firebase}) async {
    // the default 800x600 surface overflows LogoStripe under the test
    // environment's fallback font (see a11y_test.dart)
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    expect(find.byType(SettingsPage), findsOneWidget);
  }

  Future<void> pumpToExport(WidgetTester tester, {required MockFirebaseAuth firebase}) async {
    await pumpToSettings(tester, firebase: firebase);
    await tester.tapByKey(AppKeys.exportData);
    await tester.pumpTimes();
    expect(find.byType(ExportDataPage), findsOneWidget);
  }

  MockFirebaseAuth signedIn() => MockFirebaseAuth(
    mockUser: MockUser(uid: 'u1', email: 'u1@test'),
    signedIn: true,
  );

  L l(WidgetTester tester) => L.of(tester.element(find.byType(ExportDataPage)));

  Future<String> sharedText() async {
    final params = share.shared.single;
    return utf8.decode(await params.files!.single.readAsBytes());
  }

  group('the settings row', () {
    testWidgets('sits beside import for a session with an account', (tester) async {
      await pumpToSettings(tester, firebase: signedIn());

      expect(find.byKey(AppKeys.exportData), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsOneWidget);
      expect(find.byKey(AppKeys.eraseData), findsNothing);
    });

    testWidgets('stays for an anonymous session, where import is absent', (tester) async {
      await pumpToSettings(tester, firebase: MockFirebaseAuth(signedIn: false));

      expect(find.byKey(AppKeys.exportData), findsOneWidget);
      expect(find.byIcon(Icons.upload_file_rounded), findsNothing);
      expect(find.byKey(AppKeys.eraseData), findsOneWidget);
    });
  });

  group('the page', () {
    testWidgets('offers both formats and says the health data stays', (tester) async {
      await pumpToExport(tester, firebase: signedIn());

      final strings = l(tester);
      expect(find.byKey(AppKeys.exportJson), findsOneWidget);
      expect(find.byKey(AppKeys.exportCsv), findsOneWidget);
      expect(find.text(strings.exportNoHealthData), findsOneWidget);
      expect(strings.exportNoHealthData.toLowerCase(), contains('health'));
      // an account has a backup; the warning is the anonymous session's
      expect(find.text(strings.noAccountBodyLose), findsNothing);
      // the mirror is the whole history: nothing to say about what is missing
      expect(find.textContaining('Older workouts'), findsNothing);
    });

    testWidgets('repeats the lose-the-phone line, once, while anonymous', (tester) async {
      await pumpToExport(tester, firebase: MockFirebaseAuth(signedIn: false));

      expect(find.text(l(tester).noAccountBodyLose), findsOneWidget);
      expect(find.byKey(AppKeys.exportJson), findsOneWidget);
      expect(find.byKey(AppKeys.exportCsv), findsOneWidget);
    });

    testWidgets('says how many of the account\'s workouts the file will hold', (tester) async {
      when(db.mirrorSummary(any)).thenAnswer((_) async => _summary({.workouts: (count: 118, head: '0198a0')}));
      when(api.getAccountSummary()).thenAnswer((_) async => _summary({.workouts: (count: 412, head: '0198d4')}));

      await pumpToExport(tester, firebase: signedIn());

      expect(find.text(l(tester).exportPartialHistoryOf(118, 412)), findsOneWidget);
    });

    testWidgets('one line for a shortfall anywhere else, whatever mix of it', (tester) async {
      when(db.mirrorSummary(any)).thenAnswer(
        (_) async => _summary({
          .workouts: (count: 412, head: '0198d4'),
          .templates: (count: 1, head: '0198c0'),
          .goals: (count: 0, head: null),
        }),
      );
      when(api.getAccountSummary()).thenAnswer(
        (_) async => _summary({
          .workouts: (count: 412, head: '0198d4'),
          .templates: (count: 12, head: '0198c9'),
          .goals: (count: 3, head: '0198b2'),
        }),
      );

      await pumpToExport(tester, firebase: signedIn());

      final strings = l(tester);
      expect(find.text(strings.exportPartialAccount), findsOneWidget);
      // "3 of your 5 folders" is noise: only the workouts count is spelled out
      expect(find.textContaining('12'), findsNothing);
    });

    testWidgets('the account\'s own totals outrank the paging flag', (tester) async {
      // the list has not paged to the end, but the store holds every row the
      // account does — the old proxy would have cried wolf here
      when(
        api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')),
      ).thenAnswer((_) async => Page(items: [_workout()], hasMore: true));

      await pumpToExport(tester, firebase: signedIn());
      await Workouts.of(tester.element(find.byType(ExportDataPage))).initHistory();
      await tester.pumpTimes();

      expect(find.textContaining('Older workouts'), findsNothing);
      expect(find.text(l(tester).exportPartialAccount), findsNothing);
    });

    testWidgets('falls back to the paging flag when the account cannot be asked', (tester) async {
      when(api.getAccountSummary()).thenThrow(Exception('offline'));
      when(
        api.getWorkouts(any, pageSize: anyNamed('pageSize'), since: anyNamed('since')),
      ).thenAnswer((_) async => Page(items: [_workout()], hasMore: true));

      await pumpToExport(tester, firebase: signedIn());
      // what visiting History does: the pull that tells the list whether the
      // server holds more than the mirror
      await Workouts.of(tester.element(find.byType(ExportDataPage))).initHistory();
      await tester.pumpTimes();

      // a refused summary must never read as "your file will be whole"
      expect(find.text(l(tester).exportPartialHistory(1)), findsOneWidget);
    });
  });

  group('exporting', () {
    testWidgets('JSON: the mirror is read and a .json envelope reaches the share sheet', (tester) async {
      await pumpToExport(tester, firebase: signedIn());

      await tester.tapByKey(AppKeys.exportJson);
      await tester.pumpTimes();

      final params = share.shared.single;
      // an in-memory XFile keeps its name on the web only; the override is
      // what the sheet shows everywhere else
      expect(params.fileNameOverrides!.single, endsWith('.json'));
      expect(params.files!.single.mimeType, 'application/json');
      final envelope = jsonDecode(await sharedText()) as Map;
      expect(envelope['schemaVersion'], exportSchemaVersion);
      expect((envelope['workouts'] as List).cast<Map>().map((each) => each['id']), ['w1']);
      // nothing went to the server, and the page is back to its two buttons
      verifyNever(api.saveWorkout(any));
      expect(find.byKey(AppKeys.exportJson), findsOneWidget);
    });

    testWidgets('CSV: one row per set reaches the share sheet', (tester) async {
      await pumpToExport(tester, firebase: signedIn());

      await tester.tapByKey(AppKeys.exportCsv);
      await tester.pumpTimes();

      final params = share.shared.single;
      expect(params.fileNameOverrides!.single, endsWith('.csv'));
      expect(params.files!.single.mimeType, 'text/csv');
      final lines = const LineSplitter().convert(await sharedText());
      expect(lines.first, startsWith('workout_id,start,end,exercise_id,exercise_name,set_index,'));
      expect(lines, hasLength(3), reason: 'the header and the bench session\'s two sets');
      expect(lines[1], startsWith('w1,2026-03-01T10:00:00.000Z,'));
    });

    testWidgets('a store that fails: nothing is shared, the failure is shown, the buttons return', (tester) async {
      await pumpToExport(tester, firebase: signedIn());
      // re-stubbed after startup, so only the export sees the failure
      when(db.getTemplates(any)).thenThrow(StateError('database is locked'));

      await tester.tapByKey(AppKeys.exportCsv);
      await tester.pumpTimes();

      expect(share.shared, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('database is locked'), findsOneWidget);
      expect(find.byKey(AppKeys.exportJson), findsOneWidget);
      expect(find.byKey(AppKeys.exportCsv), findsOneWidget);
    });
  });
}
