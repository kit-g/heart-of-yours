import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A text field's copy/paste toolbar under the feedback wrapper.
///
/// Flutter draws that toolbar in the root overlay, and with the feedback
/// feature on — every build but tests, `AppConfig.allowsFeedbackFeature`
/// defaults to true — the root overlay is feedback's, above MaterialApp. After
/// the move to material_ui the toolbar looked up material_ui's
/// MaterialLocalizations there and found only flutter/material.dart's, which
/// feedback supplies: a long press in any text field threw "No
/// MaterialLocalizations found". The app now hands feedback its own delegates,
/// material_ui's and cupertino_ui's both.
///
/// Android only: on iOS 16+ the field shows the native system context menu
/// (`SystemContextMenu`), which asks Flutter for no localizations at all.
void main() {
  testWidgets(
    'a long press in a text field shows the toolbar with feedback on',
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = MockLocalDatabase();
      final api = MockApi();
      stubStartup(db, api);
      // the long-press toolbar asks the clipboard whether Paste belongs in it
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => switch (call.method) {
          'Clipboard.hasStrings' => {'value': true},
          'Clipboard.getData' => {'text': 'bench'},
          _ => null,
        },
      );

      await const TestAppHarness().pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: MockCdn(),
        appConfig: AppConfig.test(allowsFeedbackFeature: true),
        firebaseAuth: MockFirebaseAuth(
          mockUser: MockUser(uid: 'u1', email: 'u1@test'),
          signedIn: true,
        ),
        settle: false,
      );
      await tester.tapByKey(AppKeys.exercisesStack);
      await tester.pumpTimes();

      final field = find.byType(TextField).first;
      await tester.enterText(field, 'bench');
      await tester.pumpTimes(2);
      await tester.longPress(field);
      await tester.pumpTimes(3);

      expect(tester.takeException(), isNull);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    },
  );
}
