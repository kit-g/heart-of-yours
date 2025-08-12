import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart_state/heart_state.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  group('HeartApp (smoke)', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockConfigApi configApi;
    late TestAppHarness harness;

    setUp(() async {
      db = MockLocalDatabase();
      api = MockApi();
      configApi = MockConfigApi();
      harness = const TestAppHarness();
    });

    testWidgets('renders MaterialApp with expected localization delegates and supported locales', (tester) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        appConfig: AppConfig.test(allowsFeedbackFeature: false),
        hasLocalNotifications: false,
      );

      // Ensure we do not wrap with BetterFeedback when disabled
      expect(find.byType(BetterFeedback), findsNothing);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // Validate supported locales
      expect(app.supportedLocales, const [Locale('en', 'CA'), Locale('fr', 'CA')]);
      // Validate localization delegates presence (names only since comparing instances can be brittle)
      final delegateTypes = app.localizationsDelegates!.map((d) => d.runtimeType.toString()).toList();
      expect(delegateTypes, contains('LocsDelegate'));
      expect(delegateTypes, contains('_MaterialLocalizationsDelegate'));
      expect(delegateTypes, contains('_WidgetsLocalizationsDelegate'));
      expect(delegateTypes, contains('_GlobalCupertinoLocalizationsDelegate'));
    });

    testWidgets('core providers are available via Provider.of(context)', (tester) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        appConfig: AppConfig.test(allowsFeedbackFeature: false),
        hasLocalNotifications: false,
      );

      final element = tester.element(find.byType(MaterialApp));

      // App-level providers should be retrievable without exceptions
      expect(() => Provider.of<AppConfig>(element, listen: false), returnsNormally);
      expect(() => Provider.of<AppTheme>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Exercises>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Workouts>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Templates>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Stats>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Timers>(element, listen: false), returnsNormally);
      expect(() => Provider.of<PreviousExercises>(element, listen: false), returnsNormally);
      expect(() => Provider.of<RemoteConfig>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Preferences>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Auth>(element, listen: false), returnsNormally);
    });
  });
}
