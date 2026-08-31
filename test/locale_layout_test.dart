// Localized-copy layout sweep. Runs the main screens under every locale the
// app ships, on a phone-sized surface, and fails on any exception a longer
// translation provokes — RenderFlex overflows included, which is the point:
// Russian/Spanish/French labels run well past their English siblings, and a
// button that fits "Save" does not necessarily fit "Сохранить".
//
// The screen list and baseline stubs mirror a11y_test.dart (which mirrors
// router_test.dart); a third consumer means the shared harness is the next
// home for them when any of this changes again.
//
// The mid-session locale-change contract — a device language change restates
// `Accept-Language` and re-fetches the catalog — is pinned in heart_state's
// suite (`Exercises.onLocaleChanged`): app startup runs through `Zone.root`
// (see `_initApp`), outside the fake-async test zone, so the full-app harness
// cannot deterministically observe the API side of it.
import 'dart:convert';

import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:mockito/mockito.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

const _signInWithAppleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

enum _Screen { login, profile, workout, history, exercises, settings, importData }

void main() {
  late MockLocalDatabase db;
  late MockApi api;
  late MockCdn cdn;
  late TestAppHarness harness;

  // Real text metrics, or the sweep cries wolf: `flutter test` renders with
  // the Ahem block font, where every glyph is an em wide, and even English
  // overflows a phone-sized surface. The app bundles every family it uses
  // (display faces included), so load them all and measure what production
  // measures.
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final entry in manifest.cast<Map>()) {
      final loader = FontLoader(entry['family'] as String);
      for (final font in (entry['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _signInWithAppleChannel,
      (call) async => call.method == 'isAvailable' ? false : null,
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        _signInWithAppleChannel,
        null,
      ),
    );

    db = MockLocalDatabase();
    api = MockApi();
    cdn = MockCdn();
    harness = const TestAppHarness();

    when(
      db.getWorkoutSummary(
        weeksBack: anyNamed('weeksBack'),
        userId: anyNamed('userId'),
      ),
    ).thenAnswer((_) async => WorkoutAggregation.empty());
    when(db.getWeeklyWorkoutCount(any)).thenAnswer((_) async => 0);

    when(db.getExercises(userId: anyNamed('userId'))).thenAnswer((_) async => (null, <Exercise>[]));
    when(db.getExerciseUnits(any)).thenAnswer((_) async => <String, MeasurementUnit>{});
    when(
      db.storeExercises(any, userId: anyNamed('userId'), locale: anyNamed('locale')),
    ).thenAnswer((_) async {});
    when(api.getExercises()).thenAnswer((_) async => <Exercise>[]);
    when(api.getOwnExercises()).thenAnswer((_) async => <Exercise>[]);
    when(db.getPreferences(any)).thenAnswer((_) async => <ChartPreference>[]);

    when(db.getActiveWorkout(any)).thenAnswer((_) async => null);

    when(
      db.getWorkoutGallery(userId: anyNamed('userId')),
    ).thenAnswer((_) async => ProgressGalleryResponse(images: <WorkoutImage>[]));

    when(
      api.getWorkoutGallery(cursor: anyNamed('cursor')),
    ).thenAnswer(
      (_) async => ProgressGalleryResponse.fromJson({}),
    );
  });

  Future<void> pumpTo(WidgetTester tester, _Screen screen, Locale locale) async {
    // a phone-plausible surface: tight enough that copy that cannot fit says
    // so, wide enough that the fallback test font's metrics don't cry wolf
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    tester.platformDispatcher.localesTestValue = [locale];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final signedIn = screen != _Screen.login;
    final firebase = signedIn
        ? MockFirebaseAuth(
            mockUser: MockUser(uid: 'u1', email: 'u1@test'),
            signedIn: true,
          )
        : MockFirebaseAuth(signedIn: false);

    await harness.pumpHeartApp(
      tester,
      db: db,
      api: api,
      cdn: cdn,
      firebaseAuth: firebase,
      hasLocalNotifications: false,
      settle: false,
    );
    await tester.pumpTimes();

    switch (screen) {
      case _Screen.login:
      case _Screen.profile:
        break;
      case _Screen.workout:
        await tester.tapByKey(AppKeys.workoutStack);
      case _Screen.history:
        await tester.tapByKey(AppKeys.historyStack);
      case _Screen.exercises:
        await tester.tapByKey(AppKeys.exercisesStack);
      case _Screen.settings:
        await tester.tap(find.byIcon(Icons.settings_rounded));
      case _Screen.importData:
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await tester.pumpTimes();
        await tester.tap(find.byIcon(Icons.upload_file_rounded));
    }
    await tester.pumpTimes();
  }

  for (final locale in L.supportedLocales) {
    for (final screen in _Screen.values) {
      testWidgets(
        '${screen.name} lays out under $locale',
        (tester) async {
          await pumpTo(tester, screen, locale);

          // an overflow or any other layout exception fails the test on its
          // own, with the full error details in the log
        },
      );
    }
  }
}
