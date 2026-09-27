import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:feedback/feedback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  group('HeartApp (smoke)', () {
    late MockLocalDatabase db;
    late MockApi api;
    late MockCdn cdn;
    late TestAppHarness harness;

    setUp(() async {
      db = MockLocalDatabase();
      api = MockApi();
      cdn = MockCdn();
      harness = const TestAppHarness();
      stubStartup(db, api);
    });

    testWidgets('renders MaterialApp with expected localization delegates and supported locales', (tester) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        appConfig: AppConfig.test(allowsFeedbackFeature: false),
        hasLocalNotifications: false,
        // lands on the profile, whose dashboard animates indefinitely
        settle: false,
      );

      // Ensure we do not wrap with BetterFeedback when disabled
      expect(find.byType(BetterFeedback), findsNothing);

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      // every locale heart_language ships — the list grows with the ARBs,
      // so assert through the same source rather than a hardcoded copy
      expect(app.supportedLocales, L.supportedLocales);
      // Validate localization delegates presence (names only since comparing instances can be brittle)
      final delegateTypes = app.localizationsDelegates!.map((d) => d.runtimeType.toString()).toList();
      expect(delegateTypes, contains('_LDelegate'));
      expect(delegateTypes, contains('_MaterialLocalizationsDelegate'));
      expect(delegateTypes, contains('_WidgetsLocalizationsDelegate'));
      expect(delegateTypes, contains('_GlobalCupertinoLocalizationsDelegate'));
      // by identity: flutter_localizations' delegates carry the same names, and
      // they translate flutter/material.dart's widgets, not material_ui's
      expect(app.localizationsDelegates, contains(GlobalMaterialLocalizations.delegate));
      expect(app.localizationsDelegates, contains(GlobalCupertinoLocalizations.delegate));

      // the dependencies still on flutter/material.dart read the app's theme
      // through this (see legacy_theme_bridge_test.dart); it has to sit above
      // every route
      expect(
        find.ancestor(
          of: find.byType(Navigator),
          // ignore: deprecated_member_use
          matching: find.byType(MaterialUiCompatibilityBridge),
        ),
        findsWidgets,
      );
    });

    testWidgets('core providers are available via Provider.of(context)', (tester) async {
      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        cdn: cdn,
        appConfig: AppConfig.test(allowsFeedbackFeature: false),
        hasLocalNotifications: false,
        // lands on the profile, whose dashboard animates indefinitely
        settle: false,
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
      expect(() => Provider.of<Preferences>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Charts>(element, listen: false), returnsNormally);
      expect(() => Provider.of<Auth>(element, listen: false), returnsNormally);
    });
  });
}
