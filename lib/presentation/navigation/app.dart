import 'dart:async';

import 'package:feedback/feedback.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/theme/state.dart';
import 'package:heart/core/theme/theme.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/stats.dart';
import 'package:heart/core/utils/templates.dart';
import 'package:heart/core/utils/headers.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/widgets/image.dart';
import 'package:heart_api/heart_api.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_health/heart_health.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HeartApp extends StatelessWidget {
  final AppConfig appConfig;
  final Api api;
  final Cdn cdn;
  final LocalDatabase db;
  final HeartRouter router;
  final bool? hasLocalNotifications;
  final FirebaseAuth? firebaseAuth;

  const new({
    super.key,
    required this.appConfig,
    required this.api,
    required this.cdn,
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
            service: LocalStats(db),
          ),
        ),
        ChangeNotifierProvider<Workouts>(
          create: (context) => Workouts(
            service: db,
            remoteService: api,
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
            service: cdn,
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Templates>(
          create: (context) => Templates(
            service: db,
            remoteService: api,
            configService: cdn,
            folderService: LocalTemplateFolders(db),
            remoteFolderService: api,
            filingService: RemoteTemplateFiling(api),
            onError: reportToSentry,
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
        ChangeNotifierProvider<Charts>(
          create: (_) => Charts(
            onError: reportToSentry,
            service: db,
          ),
        ),
        ChangeNotifierProvider<Goals>(
          create: (_) => Goals(
            service: LocalGoals(db),
            remoteService: api,
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<Health>(
          // No remote service, deliberately: health data never leaves the
          // device. `healthStore()` degrades to a no-op reader off mobile.
          create: (_) => Health(
            device: healthStore(),
            local: db,
            onError: reportHealthFailure,
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
              Charts.of(context).userId = user?.id;
              Goals.of(context).userId = user?.id;
              Health.of(context).userId = user?.id;
              PreviousExercises.of(context).userId = user?.id;
              Stats.of(context).userId = user?.id;
              Templates.of(context).userId = user?.id;
              Timers.of(context).userId = user?.id;
              Workouts.of(context).userId = user?.id;
            },
            onError: reportToSentry,
            firebase: firebaseAuth,
            isWeb: kIsWeb,
          ),
        ),
        ChangeNotifierProvider<Alarms>(
          create: (_) => Alarms(cancelRestTimerNotifications: cancelExerciseNotification),
        ),
        Provider<Scrolls>(
          create: (_) => Scrolls(),
        ),
      ],
      builder: (_, _) {
        return Consumer<AppTheme>(
          builder: (_, theme, _) {
            return _App(
              theme: theme,
              config: appConfig,
              router: router,
              hasLocalNotifications: hasLocalNotifications ?? true,
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
  final bool hasLocalNotifications;

  const new({
    required this.theme,
    required this.config,
    required this.router,
    required this.hasLocalNotifications,
  });

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  /// The app's only lifecycle hook, and it sits here because [_App] is the
  /// highest widget that can still read the providers above it.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Health is the one thing whose truth can change while Heart is in the
  /// background: its permissions are granted in another app entirely, and the
  /// platform never tells us what was decided there. See [Health.onResume],
  /// which throttles itself — this fires on every alt-tab.
  void _onResume() {
    if (mounted) Health.of(context).onResume();
  }

  @override
  Widget build(BuildContext context) {
    final light = switch (widget.theme.color) {
      Color color => theme(
        ColorScheme.fromSeed(
          seedColor: color,
          brightness: .light,
        ),
      ),
      null => theme(
        ColorScheme.fromSeed(
          seedColor: AppTheme.colorFromHex(widget.config.themeColorHex) ?? Colors.white,
          brightness: .light,
        ),
      ),
    };
    final dark = switch (widget.theme.color) {
      Color color => theme(
        ColorScheme.fromSeed(
          seedColor: color,
          brightness: .dark,
        ),
      ),
      null => theme(
        ColorScheme.fromSeed(
          seedColor: AppTheme.colorFromHex(widget.config.themeColorHex) ?? Colors.white,
          brightness: .dark,
        ),
      ),
    };

    final app = MaterialApp.router(
      theme: light,
      darkTheme: dark,
      themeMode: widget.theme.mode,
      debugShowCheckedModeBanner: false,
      routerConfig: widget.router.config,
      // Wraps every route below Localizations so it can read L/AppConfig and
      // reach a ScaffoldMessenger for the notifications-off reminder.
      builder: (context, child) => _WorkoutTimeoutScheduler(
        enabled: widget.hasLocalNotifications,
        child: child ?? const SizedBox.shrink(),
      ),
      // until data is localized
      // English only until the translations are ready — but `en_CA` is not a
      // translation, it is the same copy under Canadian conventions, and
      // leaving it out is what made a Canadian phone read June the 19th as
      // "6/19". Every date in the app is `DateFormat(…, localeName)`, so the
      // resolved locale is the whole of that behaviour.
      supportedLocales: [const Locale('en'), const Locale('en', 'CA')],
      // supportedLocales: L.supportedLocales,
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

/// Manages the active-workout idle-timeout notification and the
/// notifications-off reminder. Sits below Localizations (via MaterialApp's
/// builder), so it can read L / [AppConfig] and reach a [ScaffoldMessenger].
///
/// Any change to the active workout counts as activity and pushes the timeout
/// notification back to `now + AppConfig.workoutTimeout`; finishing or
/// cancelling the workout clears it.
class _WorkoutTimeoutScheduler extends StatefulWidget {
  final Widget child;

  /// Mirrors HeartApp.hasLocalNotifications: when false, the notifications
  /// plugin is never initialized, so no call here may reach it.
  final bool enabled;

  const new({required this.child, required this.enabled});

  @override
  State<_WorkoutTimeoutScheduler> createState() => _WorkoutTimeoutSchedulerState();
}

class _WorkoutTimeoutSchedulerState extends State<_WorkoutTimeoutScheduler> {
  Workouts? _workouts;
  bool _hadActiveWorkout = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final workouts = Workouts.of(context);
    if (!identical(workouts, _workouts)) {
      _workouts?.removeListener(_onWorkoutsChanged);
      _workouts = workouts..addListener(_onWorkoutsChanged);
      _hadActiveWorkout = workouts.hasActiveWorkout;
      // Schedule for a workout already in progress at startup (a resume).
      if (workouts.hasActiveWorkout) _scheduleTimeout();
    }
  }

  @override
  void dispose() {
    _workouts?.removeListener(_onWorkoutsChanged);
    super.dispose();
  }

  void _onWorkoutsChanged() {
    if (!widget.enabled) return;
    final workouts = _workouts;
    if (workouts == null) return;

    final active = workouts.hasActiveWorkout;
    switch (active) {
      case true:
        _scheduleTimeout();
        // A fresh start (not every subsequent change): if the user kept rest
        // timers but has since revoked notifications, remind them.
        if (!_hadActiveWorkout) _remindIfNotificationsOff();
      case false:
        cancelWorkoutTimeoutNotification();
    }
    _hadActiveWorkout = active;
  }

  void _scheduleTimeout() {
    if (!widget.enabled || !mounted) return;
    final L(:workoutTimeoutTitle, :workoutTimeoutBody) = L.of(context);
    scheduleWorkoutTimeoutNotification(
      DateTime.now().add(AppConfig.of(context).workoutTimeout),
      title: workoutTimeoutTitle,
      body: workoutTimeoutBody,
    );
  }

  Future<void> _remindIfNotificationsOff() async {
    if (!Timers.of(context).isNotEmpty) return;
    final enabled = await hasNotificationsPermission(Theme.of(context).platform);
    if (enabled || !mounted) return;
    final L(:notificationsDisabledReminder, :settings) = L.of(context);
    remindNotificationsOff(context, message: notificationsDisabledReminder, settingsLabel: settings);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _initApp(
  BuildContext context,
  String? sessionToken,
  String? userId, {
  bool? hasLocalNotifications,
}) async {
  return Zone.root.run(() async {
    final workouts = Workouts.of(context);
    if (hasLocalNotifications ?? false) {
      initNotifications(
        platform: Theme.of(context).platform,
        onExerciseNotification: (exerciseId) {
          // exercises with a timer emit a local notification
          // when tapped on, it will:
          // - redirect the user to the workout page
          final HeartRouter(:goToActiveWorkout, :config, :goToWorkouts) = HeartRouter.of(context);

          if (Workouts.of(context).activeWorkout != null) {
            if (config.state.path != '/activeWorkout') {
              goToActiveWorkout();
              Future.delayed(const Duration(milliseconds: 300)).then(
                (_) {
                  // - trigger a slight animation highlighting the exercise
                  workouts.pointAt(exerciseId);
                },
              );
            } else {
              workouts.pointAt(exerciseId);
            }
          } else {
            // a notification banner might still be there even if the workout was finished or cancelled
            goToWorkouts();
          }
        },
        onWorkoutTimeoutNotification: () {
          final HeartRouter(:goToActiveWorkout, :goToWorkouts) = HeartRouter.of(context);
          switch (Workouts.of(context).activeWorkout) {
            case null:
              goToWorkouts();
            case _:
              goToActiveWorkout();
          }
        },
        onUnknownNotification: reportToSentry,
      );
    }

    final info = AppInfo.of(context);
    final appConfig = AppConfig.of(context);

    /// Completes once the API carries a session token.
    ///
    /// Held rather than fired and forgotten, because anything that talks to the
    /// server before it lands gets a 401 and pays for a forced token refresh to
    /// recover. The goals pull used to be exactly that: kicked from
    /// `onUserChange`, which runs *before* this, so every launch opened with a
    /// wasted round trip.
    final authenticated = _initAppInfo(context).then(
      (_) {
        _initApi(
          config: appConfig,
          sessionToken: sessionToken,
          appVersion: info.fullVersion,
        );

        AppImage.headers = imageHeaders(config: appConfig, appVersion: info.version, isWeb: kIsWeb);
      },
    );

    final Exercises(:isInitialized, :init) = Exercises.of(context);

    final templates = Templates.of(context);
    final prefs = Preferences.of(context);
    final theme = AppTheme.of(context);
    final timers = Timers.of(context);
    final previous = PreviousExercises.of(context);
    final config = RemoteConfig.of(context);
    final router = HeartRouter.of(context);
    final charts = Charts.of(context);
    final stats = Stats.of(context);
    final health = Health.of(context);

    await Future.wait(
      [
        config.init(),
        prefs.init(locale: View.of(context).platformDispatcher.locale),
      ],
    );

    // Nobody awaits startup, so the tree can be torn down while this is still
    // in flight. Everything below notifies a provider, and notifying a disposed
    // one throws — which in a test takes the whole shell process with it.
    if (!context.mounted) return;

    theme
      ..color = AppTheme.colorFromHex(prefs.getBaseColor(userId))
      ..toMode(prefs.themeMode);

    // `onUserChange` has already set the id — it runs before this — so the only
    // thing left to wait for is the token.
    authenticated.then<void>(
      (_) {
        if (context.mounted) Goals.of(context).init();
      },
    );

    if (!isInitialized) {
      // chart preferences are local-only and independent of the exercise
      // catalog — load them immediately rather than behind the remote sync,
      // so the dashboard doesn't sit on a spinner for the network round-trip
      charts.init();

      // Local-only too, and independent of the exercise catalog. A refused or
      // never-granted permission simply yields nothing.
      health.init();

      init(lastSync: config.exercisesLastSynced).then<void>(
        (hasExercises) {
          // everything below reads or writes against the exercise catalog —
          // templates and workouts persist rows with a foreign key onto
          // `exercises.name`. Running them against an empty catalog trades a
          // reported failure for a constraint violation, so stop here instead.
          if (!hasExercises) return;

          // since workouts initialization looks up exercises
          // in `Exercises`, we must chain these calls this way
          workouts
              .init()
              .then<void>(
                (_) {
                  router.refresh();
                  // Pulls what other devices logged into the local mirror, and
                  // heals anything stranded here by a failed save. Until this
                  // ran at startup the only thing that ran it was opening the
                  // History screen — so a workout from the phone reached the
                  // tablet's goals and previous-set tags a launch late, after
                  // some unrelated visit to History had quietly seeded it.
                  return workouts.initHistory();
                },
              )
              .then<void>(
                (_) {
                  // both read training data straight out of that mirror, so
                  // they are only correct once it has been filled
                  previous.init();
                  stats.init();
                },
              );
          templates.init();
          timers.init();
        },
      );
    }
  });
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
      isWeb: kIsWeb,
    ),
  );
}
