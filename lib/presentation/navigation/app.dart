import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'router.dart';

class HeartApp extends StatelessWidget {
  const HeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
        ChangeNotifierProvider<Exercises>(
          create: (_) => Exercises(
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Workouts>(
          create: (context) => Workouts(
            lookForExercise: Exercises.of(context).lookup,
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Auth>(
          create: (context) => Auth(
            onUserChange: (user) {
              HeartRouter.refresh();
              Workouts.of(context).userId = user?.id;
            },
          ),
        ),
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences(),
        ),
        ChangeNotifierProvider<AppInfo>(
          create: (_) => AppInfo(
            onError: reportToSentry,
          ),
        ),
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

class _AppState extends State<_App> with AfterLayoutMixin<_App>, HasHaptic<_App> {
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
    _initAppInfo(context);
    var Exercises(:isInitialized, :init) = Exercises.of(context);
    final workouts = Workouts.of(context);

    if (!isInitialized) {
      init();
    }

    final prefs = Preferences.of(context);
    final theme = AppTheme.of(context);
    await prefs.init();

    theme
      ..color = AppTheme.colorFromHex(prefs.getBaseColor())
      ..toMode(prefs.getThemeMode());

    workouts.init().then((_) => HeartRouter.refresh());
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
