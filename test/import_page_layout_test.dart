// Window-size coverage for the import page — the mechanism of
// integration_test/responsive_frame_test.dart applied to a single surface
// (docs/handoff.md #4). The page is prose and one button, so it measures its
// own LayoutBuilder constraints and caps the column at [readableWidth]
// instead of stretching to whatever an iPad offers.
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    // same baseline stubs as a11y_test.dart: enough for the profile stack to
    // render without throwing on an unstubbed call
    when(
      db.getWorkoutSummary(weeksBack: anyNamed('weeksBack'), userId: anyNamed('userId')),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);
    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);
    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));
    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer((_) async => ProgressGalleryResponse.fromJson({}));
  });

  Future<void> pumpImportPageAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
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
      // the dashboard animates indefinitely — settle would hang on it
      settle: false,
    );
    await tester.pumpTimes();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpTimes();
    await tester.tap(find.byIcon(Icons.upload_file_rounded));
    await tester.pumpTimes();
  }

  Size importColumnSize(WidgetTester tester) {
    return tester.getSize(
      find.descendant(
        of: find.byType(ImportDataPage),
        matching: find.byType(ListView),
      ),
    );
  }

  // No phone-size counterpart: driving to the page crosses the settings
  // screen, whose logo stripe renders wider than any phone under the test
  // environment's fallback font and overflows (the same constraint that has
  // a11y_test.dart pump a 1200-wide surface). The phone behavior is the
  // degenerate min(paneWidth, readableWidth) branch, verified by screenshot.
  testWidgets('an iPad window caps the import column at readableWidth', (tester) async {
    await pumpImportPageAt(tester, const Size(1194, 834));

    expect(importColumnSize(tester).width, readableWidth);
  });
}
