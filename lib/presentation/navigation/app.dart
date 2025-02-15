import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'router.dart';

class HeartApp extends StatelessWidget {
  const HeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
        ChangeNotifierProvider<Exercises>(
          create: (_) => Exercises(
            onError: reportToSentry,
            isCached: false,
            service: db,
          ),
        ),
        ChangeNotifierProvider<Stats>(
          create: (_) => Stats(
            onError: reportToSentry,
            service: db,
          ),
        ),
        ChangeNotifierProvider<Workouts>(
          create: (context) => Workouts(
            service: db,
            lookForExercise: Exercises.of(context).lookup,
            onError: (error, {stacktrace}) {
              Logger('Workouts')
                ..shout('${error.runtimeType}: $error')
                ..shout(stacktrace);
              reportToSentry(error, stacktrace: stacktrace);
            },
          ),
        ),
        ChangeNotifierProvider<Auth>(
          create: (context) => Auth(
            onUserChange: (user) {
              HeartRouter.refresh();
              Stats.of(context).userId = user?.id;
              Workouts.of(context).userId = user?.id;
            },
          ),
        ),
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences(),
        ),
        ChangeNotifierProvider<Timers>(
          create: (_) => Timers(),
        ),
        ChangeNotifierProvider<Alarms>(
          create: (_) => Alarms(),
        ),
        ChangeNotifierProvider<AppInfo>(
          create: (_) => AppInfo(
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Templates>(
          create: (_) => Templates(service: db),
        ),
        Provider<Scrolls>(
          create: (_) => Scrolls(),
        )
      ],
      builder: (__, _) {
        return Consumer<AppTheme>(
          builder: (__, theme, _) {
            return _App(theme: theme);
          },
        );
      },
    );
  }
}

class _App extends StatefulWidget {
  final AppTheme theme;

  const _App({required this.theme});

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> with AfterLayoutMixin<_App> {
  @override
  Widget build(BuildContext context) {
    const theme = MaterialTheme();
    return MaterialApp.router(
      theme: switch (widget.theme.color) {
        Color color => theme.theme(
            ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.light,
            ),
          ),
        null => theme.light(),
      },
      darkTheme: switch (widget.theme.color) {
        Color color => theme.theme(
            ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
            ),
          ),
        null => theme.dark(),
      },
      themeMode: widget.theme.mode,
      debugShowCheckedModeBanner: false,
      routerConfig: HeartRouter.config,
      supportedLocales: const [
        Locale('en', 'CA'),
        Locale('fr', 'CA'),
      ],
      localizationsDelegates: const [
        LocsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _initApp(context);
  }

  Future<void> _initApp(BuildContext context) async {
    initNotifications(
      platform: Theme.of(context).platform,
      onExerciseNotification: (exerciseId) {
        // exercises with a timer emit a local notification
        // when tapped on, it will:
        // - redirect the user to the workout page
        HeartRouter.goToExercise(exerciseId);
        // - trigger a slight animation highlighting the exercise
        Workouts.of(context).pointAt(exerciseId);
      },
      onUnknownNotification: reportToSentry,
    );

    _initAppInfo(context);

    var Exercises(:isInitialized, :init) = Exercises.of(context);
    final workouts = Workouts.of(context);

    final prefs = Preferences.of(context);
    final theme = AppTheme.of(context);
    await prefs.init();

    theme
      ..color = AppTheme.colorFromHex(prefs.getBaseColor())
      ..toMode(prefs.getThemeMode());

    if (!isInitialized) {
      init().then<void>(
        (_) {
          // since workouts initialization looks up exercises
          // in `Exercises`, we must chain these calls this way
          workouts.init().then<void>((_) => HeartRouter.refresh());
        },
      );
    }
  }

  Future<void> _initAppInfo(BuildContext context) {
    return AppInfo.of(context).init(
      () {
        return PackageInfo.fromPlatform().then<Package>(
          (info) {
            return (
              appName: info.appName,
              version: info.version,
              build: info.buildNumber,
            );
          },
        );
      },
    );
  }
}
