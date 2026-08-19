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

  /// The page calls the [Api] singleton; point its HTTP layer at [body].
  void serveImport(int statusCode, Map<String, dynamic> body) {
    Api(
      gateway: 'api.example.com',
      client: MockClient(
        (request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(body),
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

  testWidgets('picking a file uploads it raw and renders the report', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode(_csv), name: 'strong.csv'),
    );
    serveImport(200, {
      'source': 'strong',
      'workoutsFound': 5,
      'workoutsCreated': 3,
      'workoutsSkipped': 2,
      'setsCreated': 40,
      'exercisesMatched': 4,
      'exercisesCreated': ['Zercher Squat'],
      'rowsSkipped': 1,
    });

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    // transport: the raw CSV, not a JSON-quoted copy of it
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/v1/workouts/imports');
    expect(request.url.queryParameters['source'], 'strong');
    expect(request.body, _csv);

    // the report, in words
    expect(find.text('Imported!'), findsOneWidget);
    expect(find.text('3 workouts imported'), findsOneWidget);
    expect(find.text('40 sets in all'), findsOneWidget);
    expect(find.text('2 workouts were already here — skipped'), findsOneWidget);
    expect(find.text("1 row couldn't be read"), findsOneWidget);
    expect(find.text('New custom exercises'), findsOneWidget);
    expect(find.text('•  Zercher Squat'), findsOneWidget);
  });

  testWidgets('a rejected file gets the friendly headline with the reason as detail', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(
      XFile.fromData(utf8.encode('not,a,strong,export'), name: 'random.csv'),
    );
    serveImport(400, {'reason': 'missing "Workout Name" column'});

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    expect(find.text("That file didn't work"), findsOneWidget);
    expect(find.text('missing "Workout Name" column'), findsOneWidget);
    expect(find.text('Imported!'), findsNothing);
  });

  testWidgets('backing out of the picker is a non-event', (tester) async {
    FileSelectorPlatform.instance = _FakePicker(null);
    serveImport(200, const {});

    await pumpImportPage(tester);
    await tester.tap(find.text('Choose file'));
    await tester.pumpTimes();

    expect(requests, isEmpty);
    expect(find.text('Imported!'), findsNothing);
    expect(find.text("That file didn't work"), findsNothing);
    expect(find.text('Choose file'), findsOneWidget);
  });
}
