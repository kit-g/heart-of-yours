import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/widgets/health/settings.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

import 'support/health_fakes.dart';

/// The health block on the settings page — the feature's only permanent home.
/// The dashboard card is dismissible for good, so if this is wrong the feature
/// becomes unreachable.
void main() {
  late FakeHealthDevice device;
  late FakeHealthStore store;
  late Health health;
  late Preferences preferences;

  const userId = 'user-123';

  setUp(() async {
    preferences = await freshPreferences();
    device = FakeHealthDevice();
    store = FakeHealthStore();
    health = Health(device: device, local: store)..userId = userId;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<Health>.value(value: health),
          ChangeNotifierProvider<Preferences>.value(value: preferences),
        ],
        child: const MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(body: HealthSettings()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says what is read and where it stays', (tester) async {
    await health.init();
    await pump(tester);

    expect(find.text('Health'), findsOneWidget);
    expect(find.textContaining('resting heart rate'), findsOneWidget);
    expect(find.textContaining('on this device'), findsOneWidget);

    // The words that would overclaim. Workouts do sync; only this does not.
    expect(find.textContaining('private'), findsNothing);
    expect(find.textContaining('secure'), findsNothing);
  });

  testWidgets('is absent where there is no health store', (tester) async {
    device.supported = false;
    await health.init();
    await pump(tester);

    expect(find.text('Health'), findsNothing);
  });

  testWidgets('offers to ask before it ever has, and settings after', (tester) async {
    await health.init();
    await pump(tester);

    // Heart does not appear under the OS health permissions until it has asked
    // once, so sending the user there first would strand them on a page that
    // does not mention the app.
    expect(find.text('Show my health data'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);

    await preferences.setHealthAsked(userId);
    await pump(tester);

    expect(find.text('Show my health data'), findsNothing);
    expect(find.text('Open settings'), findsOneWidget);
  });

  // Where "settings" used to send an iOS user: Settings › Heart, which offers
  // cellular data, Siri and search and no mention of health whatsoever. The
  // label has to name the Health app because that is where the permission is,
  // and the hint has to exist because Heart's row is two unsignposted taps in.
  group('on iOS', () {
    final onIos = TargetPlatformVariant.only(TargetPlatform.iOS);

    testWidgets('names the Health app, and what to do once it opens', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pump(tester);

      expect(find.text('Open the Health app'), findsOneWidget);
      expect(find.text('Open settings'), findsNothing);
      // Apple gives no link straight to Heart's row, so the row says what to
      // do on arrival.
      expect(find.text('Tap your profile picture, then Apps'), findsOneWidget);
    }, variant: onIos);

    testWidgets('asks the platform where its health permissions live', (tester) async {
      await preferences.setHealthAsked(userId);
      await health.init();
      await pump(tester);

      await tester.tap(find.text('Open the Health app'));
      await tester.pump();

      expect(device.log, contains('openPermissions'));
    }, variant: onIos);
  });

  testWidgets('this is the way back in after the invitation was dismissed', (tester) async {
    await preferences.dismissHealthInvite(userId);
    await health.init();
    await pump(tester);

    expect(find.text('Show my health data'), findsOneWidget);
  });

  group('deleting', () {
    setUp(() {
      store.daily[HealthMetric.steps] = [(day: DateTime(2026, 8, 1), value: 8000)];
    });

    testWidgets('is offered only when there is something to delete', (tester) async {
      await pump(tester);
      expect(find.text('Delete health data'), findsNothing, reason: 'nothing read yet');

      await health.init();
      await pump(tester);
      expect(find.text('Delete health data'), findsOneWidget);
    });

    testWidgets('says it is Heart’s copy, not the store’s', (tester) async {
      await health.init();
      await pump(tester);

      await tester.tap(find.text('Delete health data'));
      await tester.pumpAndSettle();

      // Someone reading this must not think years of Apple Health history are
      // about to go.
      expect(find.textContaining("Heart's copy"), findsOneWidget);
      expect(find.textContaining('Nothing in your phone'), findsOneWidget);
      expect(find.textContaining('read it again'), findsOneWidget);
    });

    testWidgets('cancelling keeps the data', (tester) async {
      await health.init();
      await pump(tester);

      await tester.tap(find.text('Delete health data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.deleted, isEmpty);
      expect(health.hasData, isTrue);
    });

    testWidgets('confirming clears the local mirror and nothing else', (tester) async {
      await health.init();
      await pump(tester);

      await tester.tap(find.text('Delete health data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes, delete this'));
      await tester.pumpAndSettle();

      expect(store.deleted, [userId]);
      expect(health.hasData, isFalse);
      // The device store is a read-only source to us; forgetting must never
      // reach for it.
      expect(device.log, isNot(contains('delete')));
    });
  });
}
