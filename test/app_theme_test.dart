import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/theme/state.dart';

import 'mocks.mocks.dart';
import 'support/harness.dart';

void main() {
  group('HeartApp theme composition', () {
    testWidgets('AppTheme toggles propagate to MaterialApp.themeMode', (tester) async {
      final db = MockLocalDatabase();
      final api = MockApi();
      final configApi = MockConfigApi();
      const harness = TestAppHarness();

      await harness.pumpHeartApp(
        tester,
        db: db,
        api: api,
        config: configApi,
        appConfig: AppConfig.test(allowsFeedbackFeature: false),
        hasLocalNotifications: false,
      );

      final materialAppFinder = find.byType(MaterialApp);
      expect(materialAppFinder, findsOneWidget);

      // Initially should follow system
      MaterialApp app = tester.widget<MaterialApp>(materialAppFinder);
      expect(app.themeMode, ThemeMode.system);

      // Switch to dark
      final ctx = tester.element(materialAppFinder);
      final theme = AppTheme.of(ctx);
      theme.toDark();
      await tester.pump();

      app = tester.widget<MaterialApp>(materialAppFinder);
      expect(app.themeMode, ThemeMode.dark);

      // Switch to light
      theme.toLight();
      await tester.pump();
      app = tester.widget<MaterialApp>(materialAppFinder);
      expect(app.themeMode, ThemeMode.light);

      // Back to system
      theme.toSystem();
      await tester.pump();
      app = tester.widget<MaterialApp>(materialAppFinder);
      expect(app.themeMode, ThemeMode.system);
    });
  });
}
