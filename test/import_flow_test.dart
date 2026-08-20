// The import page end to end minus the native pieces: the platform file
// picker is faked at the platform-interface seam and the HTTP layer is a
// canned handler, so the test drives the real page through the real
// Api.importWorkouts — pick a file, watch the report render, or the
// rejection, or nothing at all when the picker is dismissed.
import 'dart:convert';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

const _csv =
    'Date,Workout Name,Exercise Name,Set Order,Weight,Reps\n'
    '2024-01-01 10:00:00,Push Day,Bench Press (Barbell),1,60,8';

class _FakePicker extends FileSelectorPlatform with MockPlatformInterfaceMixin {
  final XFile? file;

  new(this.file);

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    return file;
  }
}

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;
  late List<http.Request> requests;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();
    requests = [];

    // same baseline stubs as a11y_test.dart
    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);
    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);
    when(db.getWorkoutHistory(any)).thenAnswer((_) async => <Workout>[]);
    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));
    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer((_) async => ProgressGalleryResponse.fromJson({}));
  });

  /// The page calls the [Api] singleton; point its HTTP layer at canned
  /// bodies — [preview] answers the dry run, [report] the commit.
  void serveImport({
    int statusCode = 200,
    Map<String, dynamic> preview = const {},
    Map<String, dynamic> report = const {},
  }) {
    Api(
      gateway: 'api.example.com',
      client: MockClient(
        (request) async {
          requests.add(request);
          final dryRun = request.url.queryParameters['dryRun'] == 'true';
          return http.Response(
            jsonEncode(dryRun ? preview : report),
            statusCode,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        },
      ),
    );
  }

  Future<void> pumpImportPage(WidgetTester tester) async {
    // wide enough for the logo stripe under the test environment's fallback
    // font — see a11y_test.dart
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'u1@test'),
        signedIn: true,
      ),
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    await tester.tap(find.byIcon(Icons.upload_file_rounded));
    await tester.pumpTimes();
  }

  testWidgets('nothing unmatched: the preview flows straight into the commit and the report', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode(_csv), name: 'strong.csv'),
    );
    serveImport(
      preview: {
        'source': 'strong',
        'workoutsFound': 5,
        'workoutsAlreadyImported': 2,
        'setsFound': 41,
        'exercisesMatched': 4,
        'exercisesUnmatched': [],
        'rowsSkipped': 1,
      },
      report: {
        'source': 'strong',
        'workoutsFound': 5,
        'workoutsCreated': 3,
        'workoutsSkipped': 2,
        'setsCreated': 40,
        'exercisesMatched': 4,
        'exercisesCreated': [],
        'rowsSkipped': 1,
      },
    );

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    // two trips: the dry run, then the commit — both carrying the raw CSV,
    // not a JSON-quoted copy of it
    expect(requests, hasLength(2));
    final [preview, commit] = requests;
    expect(preview.method, 'POST');
    expect(preview.url.path, '/v1/workouts/imports');
    expect(preview.url.queryParameters['source'], 'strong');
    expect(preview.url.queryParameters['dryRun'], 'true');
    expect(preview.body, _csv);
    expect(commit.url.queryParameters, isNot(contains('dryRun')));
    expect(commit.body, _csv);

    // no consent step — there was nothing to decide
    expect(find.text('New exercises found'), findsNothing);

    // the report, in words
    expect(find.text('Imported!'), findsOneWidget);
    expect(find.text('3 workouts imported'), findsOneWidget);
    expect(find.text('40 sets in all'), findsOneWidget);
    expect(find.text('2 workouts were already here — skipped'), findsOneWidget);
    expect(find.text("1 row couldn't be read"), findsOneWidget);
    expect(find.text('New custom exercises'), findsNothing);
  });

  testWidgets('unmatched exercises are each their own checkbox; unchecked ones stay behind', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode(_csv), name: 'strong.csv'),
    );
    serveImport(
      preview: {
        'source': 'strong',
        'workoutsFound': 5,
        'workoutsAlreadyImported': 2,
        'setsFound': 43,
        'exercisesMatched': 4,
        'exercisesUnmatched': [
          {'name': 'Zercher Squat', 'sets': 12},
          {'name': 'Building Climbing', 'sets': 3},
        ],
        'rowsSkipped': 0,
      },
      report: {
        'source': 'strong',
        'workoutsFound': 5,
        'workoutsCreated': 3,
        'workoutsSkipped': 2,
        'setsCreated': 40,
        'setsSkipped': 3,
        'exercisesMatched': 4,
        'exercisesCreated': ['Zercher Squat'],
        'exercisesSkipped': ['Building Climbing'],
        'rowsSkipped': 0,
      },
    );

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    // the consent step: nothing written yet, the stock side of the story told,
    // each unmatched name its own decision with the cost of declining spelled
    // out — and no second file until this one is settled
    expect(requests, hasLength(1));
    expect(find.text('Ready to import'), findsOneWidget);
    // 2 of the 5 were imported before — the headline counts only the new,
    // never the whole file over again
    expect(find.text('3 workouts are new'), findsOneWidget);
    expect(find.text('4 exercises already match the library'), findsOneWidget);
    expect(find.text('2 workouts are already here — they will be skipped'), findsOneWidget);
    expect(find.text('New exercises found'), findsOneWidget);
    expect(find.text('Zercher Squat'), findsOneWidget);
    expect(find.text('Building Climbing'), findsOneWidget);
    expect(find.text('12 sets'), findsOneWidget);
    expect(find.text('3 sets'), findsOneWidget);
    expect(find.text('Choose file'), findsNothing);

    // decline one, commit the rest
    await tester.tap(find.text('Building Climbing'));
    await tester.pump();
    await tester.tap(find.text('Import'));
    await tester.pumpTimes();

    // the commit carries the allowlist in the JSON envelope
    final commit = requests.last;
    expect(commit.headers['content-type'], startsWith('application/json'));
    expect(
      jsonDecode(commit.body),
      {
        'csv': _csv,
        'createCustom': ['Zercher Squat'],
      },
    );

    // the report counts what declining cost
    expect(find.text('Imported!'), findsOneWidget);
    expect(find.text('3 sets stayed behind with the exercises you declined'), findsOneWidget);
    expect(find.text('•  Zercher Squat'), findsOneWidget);
  });

  testWidgets('a full re-upload says nothing is new, not that everything is coming over', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode(_csv), name: 'strong.csv'),
    );
    serveImport(
      preview: {
        'source': 'strong',
        'workoutsFound': 537,
        'workoutsAlreadyImported': 537,
        'setsFound': 10467,
        'exercisesMatched': 61,
        'exercisesUnmatched': [
          {'name': 'Zercher Squat', 'sets': 12},
        ],
        'rowsSkipped': 0,
      },
    );

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    expect(find.text('Nothing new — all 537 workouts in this file are already here'), findsOneWidget);
    // the one line says it all; neither half of the contradiction renders
    expect(find.textContaining('ready to come over'), findsNothing);
    expect(find.textContaining('they will be skipped'), findsNothing);
  });

  testWidgets('cancelling the consent step walks away without writing anything', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode(_csv), name: 'strong.csv'),
    );
    serveImport(
      preview: {
        'source': 'strong',
        'workoutsFound': 5,
        'workoutsAlreadyImported': 0,
        'setsFound': 43,
        'exercisesMatched': 4,
        'exercisesUnmatched': [
          {'name': 'Zercher Squat', 'sets': 12},
        ],
        'rowsSkipped': 0,
      },
    );

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();
    expect(find.text('Ready to import'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpTimes();

    // the dry run stays the only trip; the page is back where it started
    expect(requests, hasLength(1));
    expect(find.text('Ready to import'), findsNothing);
    expect(find.text('Imported!'), findsNothing);
    expect(find.text('Choose file'), findsOneWidget);
  });

  testWidgets('a rejected file gets the friendly headline with the reason as detail', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode('not,a,strong,export'), name: 'random.csv'),
    );
    serveImport(statusCode: 400, preview: {'reason': 'missing "Workout Name" column'});

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    expect(requests, hasLength(1));
    expect(find.text("That file didn't work"), findsOneWidget);
    expect(find.text('missing "Workout Name" column'), findsOneWidget);
    expect(find.text('Imported!'), findsNothing);
  });

  testWidgets('backing out of the picker is a non-event', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(null);
    serveImport();

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    expect(requests, isEmpty);
    expect(find.text('Imported!'), findsNothing);
    expect(find.text("That file didn't work"), findsNothing);
    expect(find.text('Choose file'), findsOneWidget);
  });
}
