import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/presentation/navigation/app.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A lightweight, reusable harness to keep widget tests DRY.
///
/// It lets tests pump HeartApp with injectable dependencies
/// (Api, ConfigApi, LocalDatabase) and with side-effectful
/// features disabled by default (notifications, BetterFeedback).
class TestAppHarness {
  const TestAppHarness();

  /// Pumps a HeartApp instance with the provided dependencies.
  ///
  /// Defaults are safe for tests: allowsFeedbackFeature=false and
  /// hasLocalNotifications=false to avoid platform channels.
  Future<void> pumpHeartApp(
    WidgetTester tester, {
    required LocalDatabase db,
    required Api api,
    required Cdn cdn,
    AppConfig? appConfig,
    bool hasLocalNotifications = false,
    HeartRouter? router,
    fb.FirebaseAuth? firebaseAuth,
    // The app has animations that never stop, so pumpAndSettle can hang on it.
    // Tests that only need a rendered frame can pump a fixed number instead.
    bool settle = true,
    int pumps = 8,
  }) async {
    final cfg = appConfig ?? AppConfig.test(allowsFeedbackFeature: false);

    // AppInfo.init runs during app startup; without this the platform channel
    // is missing under `flutter test` and every pump logs a stack trace
    PackageInfo.setMockInitialValues(
      appName: 'heart',
      packageName: 'me.heart.test',
      version: '0.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    await tester.pumpWidget(
      HeartApp(
        db: db,
        api: api,
        cdn: cdn,
        hasLocalNotifications: hasLocalNotifications,
        appConfig: cfg,
        firebaseAuth: firebaseAuth ?? MockFirebaseAuth(),
        router: router ?? HeartRouter(),
      ),
    );

    switch (settle) {
      case true:
        await pumpAndSettleSafe(tester);
      case false:
        for (var i = 0; i < pumps; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
    }
  }
}

/// Await pumpAndSettle with a timeout guard to reduce flakiness.
Future<void> pumpAndSettleSafe(WidgetTester tester, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      return;
    } catch (_) {
      // If pumpAndSettle throws because of pending animations, keep trying
    }
  }
  // Final attempt; let errors surface if they persist
  await tester.pumpAndSettle();
}

extension ExtWidgetTester on WidgetTester {
  Future<void> tapByKey(Key key, [Duration duration = const Duration(milliseconds: 100)]) async {
    await tap(find.byKey(key));
    await pump(duration);
  }

  /// Bounded alternative to pumpAndSettle for screens with never-ending
  /// animations (the dashboard): advances a fixed number of frames so pending
  /// futures and route transitions complete without waiting to settle.
  /// (Named to avoid WidgetTester's own pumpFrames.)
  Future<void> pumpTimes([int times = 8, Duration step = const Duration(milliseconds: 100)]) async {
    for (var i = 0; i < times; i++) {
      await pump(step);
    }
  }

  Future<void> enterTextAndWait(Finder finder, String text) async {
    await enterText(finder, text);
    await pump();
  }
}
