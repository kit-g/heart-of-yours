import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/env/app_upgrade.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/licenses.dart';
import 'package:heart/core/env/logging.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/firebase.dart';
import 'package:heart/presentation/navigation/app.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

typedef AppRunner = Future<void> Function({
  required AppConfig appConfig,
  required LocalDatabase db,
  required Api api,
  required Cdn cdn,
  bool? hasLocalNotifications,
  FirebaseAuth? firebase,
});

@visibleForTesting
Future<void> bootstrap({
  required AppConfig config,
  Future<void> Function(Env env) initFirebase = initializeFirebase,
  Future<LocalDatabase> Function({bool isWeb}) initDb = LocalDatabase.init,
  SentryInit? initSentry = initSentry,
  AppRunner appRunner = _runner,
  LogInit? initLogging = initLogging,
  bool? hasLocalNotifications,
  FirebaseAuth? firebase,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  initLogging?.call(config.logLevel);
  registerLicenses();

  final api = Api(gateway: config.api);
  final cdn = Cdn(gateway: config.mediaLink);

  return Future.wait<dynamic>([
    initFirebase(config.env),
    initDb(isWeb: kIsWeb),
  ]).then<void>(
    (initialized) {
      final [_, db] = initialized;

      Future<void> run() {
        return appRunner(
          db: db as LocalDatabase,
          api: api,
          cdn: cdn,
          hasLocalNotifications: hasLocalNotifications,
          appConfig: config,
          firebase: firebase ?? FirebaseAuth.instance,
        );
      }

      return switch (initSentry) {
        FutureOr<void> Function(Future<void> Function(), AppConfig) callback => callback(run, config),
        null => run(),
      };
    },
  );
}

/// The conventional phone/tablet split: 600 logical pixels on the short edge.
///
/// Read off the view rather than a `MediaQuery`, because the orientation
/// preference is set before there is a widget tree to read one from. Anything
/// without a view — the browser, tests — counts as not a phone and stays free.
///
/// Off the **display**, not `view.physicalSize`, which is the window: it has
/// the system bars taken out of it and it swaps its sides with the device.
/// A 7" tablet measures 1200x1920 either way, but its window is 1200x1800
/// upright and 1920x1080 on its side — so a launch in landscape scored 540,
/// called itself a phone, and pinned the tablet to portrait for the life of
/// the process. The display is the device, whichever way up it is, which is
/// also what `sw600dp` means on the Android side of this decision.
///
/// `null` is a display with no size yet — unproven, but the whole failure
/// above was a number believed too early, so it defers rather than guesses.
/// See [_runner].
bool? get _isPhone {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  return switch (view?.display) {
    null => false,
    final display when display.size.isEmpty => null,
    final display => display.size.shortestSide / display.devicePixelRatio < 600,
  };
}

Future<void> _runner({
  required Api api,
  required AppConfig appConfig,
  required Cdn cdn,
  required LocalDatabase db,
  bool? hasLocalNotifications,
  Future<void> Function(List<DeviceOrientation> orientations) setOrientations = SystemChrome.setPreferredOrientations,
  FirebaseAuth? firebase,
}) {
  // Phones stay portrait — the layouts are not built for a 390pt-tall viewport.
  // Tablets are left to follow the device, which is what large-screen guidance
  // on both platforms asks for.
  //
  // The split has to be made here rather than with one blanket lock, because
  // the two platforms disagree: iPadOS ignores this preference entirely once an
  // app allows multitasking, but Android honours it. A blanket [.portraitUp]
  // reads as "phones only" on iOS while quietly pinning Android tablets too.
  // An unmeasured display answers neither: ask again after the first frame,
  // the first moment the size is certainly real. Nothing is on screen until
  // then, so the wait costs nothing.
  Future<void> applyOrientations() {
    return switch (_isPhone) {
      true => setOrientations(const [DeviceOrientation.portraitUp]),
      false => setOrientations(const <DeviceOrientation>[]),
      null => Future.sync(
        () => WidgetsBinding.instance.addPostFrameCallback((_) => applyOrientations()),
      ),
    };
  }

  return Future.wait([
    applyOrientations(),
    // Before `runApp`, so no session restored from the keychain is ever
    // momentarily live. See the function for why the keychain needs this.
    signOutIfFirstRunAfterInstall(firebase),
  ]).then<void>(
    (_) {
      final router = HeartRouter(
        observers: [
          SentryNavigatorObserver(),
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        ],
        onError: reportToSentry,
      );

      api
        ..onUpgradeRequired = (j) {
          AppVersionSentry.instance.requireUpgrade();
          router.refresh();
          return (j, 426);
        }
        ..onReauthenticate = () async {
          // An anonymous session never talks to the server, so there is no
          // 401 to recover from — and its token must never become a header.
          final user = firebase?.currentUser;
          if (user == null || user.isAnonymous) return false;
          final token = await user.getIdToken(true);
          if (token != null) {
            api.reauthenticate(token);
          }
          return token != null;
        };

      return runApp(
        HeartApp(
          db: db,
          api: api,
          cdn: cdn,
          hasLocalNotifications: hasLocalNotifications,
          appConfig: appConfig,
          firebaseAuth: firebase,
          router: router,
        ),
      );
    },
  );
}

Future<void> main() {
  return bootstrap(
    config: AppConfig.fromDartDefine(),
    hasLocalNotifications: true,
  );
}
