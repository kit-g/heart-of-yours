import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/headers.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/image.dart';
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
    final config = ConfigApi(gateway: AppConfig.mediaLink);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
        ChangeNotifierProvider<Exercises>(
          create: (_) => Exercises(
            onError: reportToSentry,
            remoteService: api,
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
            remoteService: api,
            lookForExercise: Exercises.of(context).lookup,
            onError: (error, {stacktrace}) {
              Logger('Workouts')
                ..shout('${error.runtimeType}: $error')
                ..shout(stacktrace);
              reportToSentry(error, stacktrace: stacktrace);
            },
          ),
        ),
        Provider<RemoteConfig>(
          create: (_) => RemoteConfig(
            service: config,
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Templates>(
          create: (context) => Templates(
            service: db,
            remoteService: api,
            configService: config,
            onError: reportToSentry,
            lookForExercise: Exercises.of(context).lookup,
          ),
        ),
        ChangeNotifierProvider<Timers>(
          create: (_) => Timers(service: db),
        ),
        ChangeNotifierProvider<PreviousExercises>(
          create: (_) => PreviousExercises(service: db),
        ),
        ChangeNotifierProvider<Preferences>(
          create: (_) => Preferences(),
        ),
        ChangeNotifierProvider<AppInfo>(
          create: (_) => AppInfo(
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Auth>(
          create: (context) => Auth(
            service: api,
            onEnter: (session, userId) => _initApp(context, session, userId),
            onUserChange: (user) {
              HeartRouter.refresh();
              Exercises.of(context).userId = user?.id;
              PreviousExercises.of(context).userId = user?.id;
              Stats.of(context).userId = user?.id;
              Templates.of(context).userId = user?.id;
              Timers.of(context).userId = user?.id;
              Workouts.of(context).userId = user?.id;
            },
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Alarms>(
          create: (_) => Alarms(),
        ),
        Provider<Scrolls>(
          create: (_) => Scrolls(),
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

class _AppState extends State<_App> {
  @override
  Widget build(BuildContext context) {
    final light = switch (widget.theme.color) {
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
    };
    final dark = switch (widget.theme.color) {
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
    };
    return BetterFeedback(
      themeMode: widget.theme.mode,
      theme: FeedbackThemeData(
        sheetIsDraggable: false,
        feedbackSheetColor: light.colorScheme.surface,
        bottomSheetDescriptionStyle: light.textTheme.titleMedium!,
        colorScheme: light.colorScheme,
        bottomSheetTextInputStyle: light.textTheme.bodyMedium!,
        activeFeedbackModeColor: light.colorScheme.primary,
      ),
      darkTheme: FeedbackThemeData(
        feedbackSheetColor: dark.colorScheme.surface,
        bottomSheetDescriptionStyle: dark.textTheme.titleMedium!,
        colorScheme: dark.colorScheme,
        bottomSheetTextInputStyle: dark.textTheme.bodyMedium!,
        activeFeedbackModeColor: dark.colorScheme.primary,
      ),
      child: MaterialApp.router(
        theme: light,
        darkTheme: dark,
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
      ),
    );
  }
}

Future<void> _initApp(BuildContext context, String? sessionToken, String? userId) async {
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

  final info = AppInfo.of(context);
  _initAppInfo(context).then(
    (_) {
      _initApi(
        sessionToken: sessionToken,
        appVersion: info.fullVersion,
      );

      AppImage.headers = imageHeaders(appVersion: info.version);
    },
  );

  var Exercises(:isInitialized, :init) = Exercises.of(context);
  final workouts = Workouts.of(context);

  final templates = Templates.of(context);
  final prefs = Preferences.of(context);
  final theme = AppTheme.of(context);
  final timers = Timers.of(context);
  final previous = PreviousExercises.of(context);
  final config = RemoteConfig.of(context);

  await Future.wait(
    [
      config.init(),
      prefs.init(locale: View.of(context).platformDispatcher.locale),
    ],
  );

  theme
    ..color = AppTheme.colorFromHex(prefs.getBaseColor(userId))
    ..toMode(prefs.getThemeMode());

  if (!isInitialized) {
    init(lastSync: config.exercisesLastSynced).then<void>(
      (_) {
        // since workouts initialization looks up exercises
        // in `Exercises`, we must chain these calls this way
        workouts.init().then<void>((_) => HeartRouter.refresh());
        templates.init();
        timers.init();
        previous.init();
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
