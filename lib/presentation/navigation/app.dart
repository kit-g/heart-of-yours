import 'package:feedback/feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/headers.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/image.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HeartApp extends StatelessWidget {
  final AppConfig appConfig;
  final Api api;
  final ConfigApi config;
  final LocalDatabase db;
  final HeartRouter router;
  final bool? hasLocalNotifications;
  final FirebaseAuth? firebaseAuth;

  const HeartApp({
    super.key,
    required this.appConfig,
    required this.api,
    required this.config,
    required this.db,
    required this.router,
    this.hasLocalNotifications = true,
    this.firebaseAuth,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: appConfig),
        Provider<HeartRouter>.value(value: router),
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
            onEnter: (session, userId) => _initApp(
              context,
              session,
              userId,
              hasLocalNotifications: hasLocalNotifications,
            ),
            onUserChange: (user) {
              router.refresh();
              Exercises.of(context).userId = user?.id;
              PreviousExercises.of(context).userId = user?.id;
              Stats.of(context).userId = user?.id;
              Templates.of(context).userId = user?.id;
              Timers.of(context).userId = user?.id;
              Workouts.of(context).userId = user?.id;
            },
            onError: reportToSentry,
            firebase: firebaseAuth,
          ),
        ),
        ChangeNotifierProvider<Alarms>(
          create: (_) => Alarms(),
        ),
        Provider<Scrolls>(
          create: (_) => Scrolls(),
        ),
      ],
      builder: (_, _) {
        return Consumer<AppTheme>(
          builder: (__, theme, _) {
            return _App(
              theme: theme,
              config: appConfig,
              router: router,
            );
          },
        );
      },
    );
  }
}

class _App extends StatefulWidget {
  final AppTheme theme;
  final AppConfig config;
  final HeartRouter router;

  const _App({
    required this.theme,
    required this.config,
    required this.router,
  });

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
          seedColor: AppTheme.colorFromHex(widget.config.themeColorHex) ?? Colors.white,
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
          seedColor: AppTheme.colorFromHex(widget.config.themeColorHex) ?? Colors.white,
          brightness: Brightness.dark,
        ),
      ),
    };

    final app = MaterialApp.router(
      theme: light,
      darkTheme: dark,
      themeMode: widget.theme.mode,
      debugShowCheckedModeBanner: false,
      routerConfig: widget.router.config,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
    );

    return switch (widget.config.allowsFeedbackFeature) {
      false => app,
      true => BetterFeedback(
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
        child: app,
      ),
    };
  }
}

Future<void> _initApp(
  BuildContext context,
  String? sessionToken,
  String? userId, {
  bool? hasLocalNotifications,
}) async {
  if (hasLocalNotifications ?? false) {
    initNotifications(
      platform: Theme.of(context).platform,
      onExerciseNotification: (exerciseId) {
        // exercises with a timer emit a local notification
        // when tapped on, it will:
        // - redirect the user to the workout page
        HeartRouter.of(context).goToExercise(exerciseId);
        // - trigger a slight animation highlighting the exercise
        Workouts.of(context).pointAt(exerciseId);
      },
      onUnknownNotification: reportToSentry,
    );
  }

  final info = AppInfo.of(context);
  final appConfig = AppConfig.of(context);
  _initAppInfo(context).then(
    (_) {
      _initApi(
        config: appConfig,
        sessionToken: sessionToken,
        appVersion: info.fullVersion,
      );

      AppImage.headers = imageHeaders(config: appConfig, appVersion: info.version);
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
  final router = HeartRouter.of(context);

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
        workouts.init().then<void>((_) => router.refresh());
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

Future<void> _initApi({required AppConfig config, String? sessionToken, String? appVersion}) async {
  Api.instance.authenticate(
    headers(
      config: config,
      sessionToken: sessionToken,
      appVersion: appVersion,
    ),
  );
}
