import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/headers.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'router/router.dart';

class HeartApp extends StatelessWidget {
  const HeartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final db = LocalDatabase();
    final api = Api(gateway: AppConfig.api);

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
        ChangeNotifierProvider<Templates>(
          create: (context) => Templates(
            service: db,
            onError: reportToSentry,
            lookForExercise: Exercises.of(context).lookup,
          ),
        ),
        ChangeNotifierProvider<Timers>(
          create: (_) => Timers(service: db),
        ),
        ChangeNotifierProvider<Auth>(
          create: (context) => Auth(
            service: api,
            onEnter: () => _initApp(context),
            onUserChange: (user) {
              HeartRouter.refresh();
              Stats.of(context).userId = user?.id;
              Templates.of(context).userId = user?.id;
              Timers.of(context).userId = user?.id;
              Workouts.of(context).userId = user?.id;
            },
          ),
        ),
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences(),
        ),
        ChangeNotifierProvider<Alarms>(
          create: (_) => Alarms(),
        ),
        ChangeNotifierProvider<AppInfo>(
          create: (_) => AppInfo(
            onError: reportToSentry,
          ),
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
    AppConfig;
    return MaterialApp.router(
      theme: switch (widget.theme.color) {
        Color color => theme(
            ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.light,
            ),
          ),
        null => theme(
            ColorScheme.fromSeed(
              seedColor: AppTheme.colorFromHex(AppConfig.themeColorHex) ?? Colors.white,
              brightness: Brightness.light,
            ),
          ),
      },
      darkTheme: switch (widget.theme.color) {
        Color color => theme(
            ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
            ),
          ),
        null => theme(
            ColorScheme.fromSeed(
              seedColor: AppTheme.colorFromHex(AppConfig.themeColorHex) ?? Colors.white,
              brightness: Brightness.dark,
            ),
          ),
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

  final auth = Auth.of(context);
  final info = AppInfo.of(context);
  _initAppInfo(context).then(
    (_) async {
      _initApi(
        sessionToken: await auth.sessionToken,
        appVersion: info.fullVersion,
      );
    },
  );

  var Exercises(:isInitialized, :init) = Exercises.of(context);
  final workouts = Workouts.of(context);

  final templates = Templates.of(context);
  final prefs = Preferences.of(context);
  final theme = AppTheme.of(context);
  final timers = Timers.of(context);
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
        templates.init();
        timers.init();
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

Future<void> _initApi({String? sessionToken, String? appVersion}) async {
  Api.instance.authenticate(
    headers(
      sessionToken: sessionToken,
      appVersion: appVersion,
    ),
  );
}
