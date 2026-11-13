// Back at the root of the Exercises and History tabs, on a phone and on a
// tablet. On wide layouts those shells build their navigator only while the
// detail pane holds something, and go_router reads it on Back: an unbuilt one
// crashed an Android tablet with nothing selected (#628).
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;

  setUp(() {
    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    stubStartup(db, api);
    when(db.storeExercises(any, userId: anyNamed('userId'))).thenAnswer((_) async {});
  });

  for (final (device, size) in [('phone', const Size(390, 844)), ('tablet', const Size(1194, 834))]) {
    for (final (tab, key) in [('Exercises', AppKeys.exercisesStack), ('History', AppKeys.historyStack)]) {
      testWidgets('Back on the $tab root, on a $device, does not throw', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await const TestAppHarness().pumpHeartApp(
          tester,
          db: db,
          api: api,
          cdn: cdn,
          firebaseAuth: MockFirebaseAuth(signedIn: false),
          settle: false,
        );
        await tester.pumpTimes();
        await tester.tapByKey(key);
        await tester.pumpTimes();

        await tester.binding.handlePopRoute();
        await tester.pumpTimes();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
