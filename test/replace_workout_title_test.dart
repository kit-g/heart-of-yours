import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

/// A workout replaced under the open sheet (#423): a start link's cancel and
/// start land in one frame, and the sheet showed the new workout's exercises
/// under the old one's name.
void main() {
  setUpAll(() async {
    // the app's own fonts, as the screens are laid out for them: the test font
    // is wider and overflows the app bars at phone width
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
    // the cancel withdraws the workout's notifications; no plugin registrant
    // runs under `flutter test` — see notification_refusal_test
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  Finder titled(String name) =>
      find.byWidgetPredicate((widget) => widget is TextField && widget.controller?.text == name);

  testWidgets('the sheet takes the new workout\'s name', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = MockLocalDatabase();
    final api = MockApi();
    stubStartup(db, api);
    final squat = Exercise(name: 'Squat', category: .barbell, target: .legs);
    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, [squat]));
    when(db.getExerciseNotes(any)).thenAnswer((_) async => {});
    when(db.deleteWorkout(any)).thenAnswer((_) async {});
    await const TestAppHarness().pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: MockCdn(),
      firebaseAuth: MockFirebaseAuth(mockUser: _AnonymousUser(), signedIn: true),
      settle: false,
    );
    final workouts = Workouts.of(tester.element(find.byType(MaterialApp)));
    await workouts.startWorkout(
      source: .template,
      template: Workout(name: 'Pull Day'),
    );
    await tester.tapByKey(AppKeys.workoutStack);
    await tester.pumpTimes();
    expect(titled('Pull Day'), findsOneWidget);

    // the replace a start link makes, with no frame between the two
    await workouts.cancelActiveWorkout();
    await workouts.startWorkout(
      source: .template,
      template: Workout(name: 'Leg Day')..add(squat),
    );
    await tester.pumpTimes();

    expect(titled('Leg Day'), findsOneWidget);
    expect(titled('Pull Day'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

// The upstream mock is mutable despite Firebase User's immutable annotation.
// ignore: must_be_immutable
class _AnonymousUser extends MockUser {
  new() : super(uid: 'muffin', isAnonymous: true);

  @override
  String? get photoURL => null;
}
