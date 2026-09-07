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
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/core/utils/backfill.dart';
import 'package:heart/core/utils/exercises.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/stats.dart';
import 'package:heart/core/utils/templates.dart';
import 'package:heart/core/utils/upsync.dart';
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
        // One gate for every remote leg below; Auth decides, the rest consult.
        // Above them all because each takes it at construction.
        Provider<RemoteAccess>(
          create: (_) => RemoteAccess(),
        ),
        ChangeNotifierProvider<AppTheme>(
          create: (_) => AppTheme(),
        ),
        // Above `Exercises`, which hands it the rest timers the account's
        // preferences come back with — the mirror that read feeds is this
        // notifier's, not a second copy inside `Exercises`.
        ChangeNotifierProvider<Timers>(
          create: (_) => Timers(service: db),
        ),
        ChangeNotifierProvider<Exercises>(
          create: (context) {
            final exercises = Exercises(
              onError: reportToSentry,
              remoteService: api,
              service: db,
              libraryService: CdnExerciseLibrary(cdn),
              catalogService: LocalCatalog(db),
              preferenceService: RemoteExercisePreferences(api),
              remote: RemoteAccess.of(context),
              onRestTimer: Timers.of(context).setRestTimer,
            );
            // sample templates arrive as content slugs plus per-locale
            // names; the CDN client resolves the slugs through the catalog
            // (loaded before any sample fetch — templates init is chained
            // behind the catalog's) and picks names by the device language
            cdn.resolveExercise = exercises.lookupByKey;
            cdn.languageTag = languageTag;
            return exercises;
          },
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
            remote: RemoteAccess.of(context),
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
            remote: RemoteAccess.of(context),
            onError: reportToSentry,
          ),
        ),
        ChangeNotifierProvider<PreviousExercises>(
          create: (_) => PreviousExercises(service: db),
        ),
        ChangeNotifierProvider<Preferences>(
          // Loaded here, before there is a session, not with the rest of
          // startup: the router's first decision — onboarding or the app —
          // waits on `Preferences.initialized`, and the sooner that is read
          // the shorter the wait. `_initApp` reads it again with the rest;
          // the second read is harmless.
          create: (_) => Preferences()..init(locale: PlatformDispatcher.instance.locale),
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
          create: (context) => Goals(
            service: LocalGoals(db),
            remoteService: api,
            remote: RemoteAccess.of(context),
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
        ChangeNotifierProvider<Alarms>(
          // same contract as _WorkoutTimeoutScheduler: with notifications off
          // the plugin is never initialized, so no call may reach it — and a
          // sign-out (or a uid switch) stops the timer through this
          create: (_) => Alarms(
            cancelRestTimerNotifications: switch (hasLocalNotifications ?? false) {
              true => cancelExerciseNotification,
              false => null,
            },
          ),
        ),
        // The pull half of "the app is catching up": after `Workouts`, whose
        // paging it drives, and above `Upsync`, whose completion callback
        // reaches it through `_resync` (#113). It waits for the replay through
        // `RemoteAccess` rather than through provider order.
        ChangeNotifierProvider<Backfill>(
          create: (context) => Backfill(
            local: LocalMirror(db),
            remote: RemoteAccountSummary(api),
            nextPage: Workouts.of(context).backfillPage,
            access: RemoteAccess.of(context),
            onError: reportToSentry,
          ),
        ),
        // The replay of an anonymous session's store into the account it
        // becomes. Reads and writes the mirror through the same adapters the
        // notifiers use, talks to the server through the same Api, and when
        // it is done the notifiers above re-pull what the server now holds.
        ChangeNotifierProvider<Upsync>(
          create: (context) => Upsync(
            local: LocalUpsync(db),
            remote: RemoteUpsync(api),
            exercises: db,
            folders: LocalTemplateFolders(db),
            templates: db,
            workouts: db,
            goals: LocalGoals(db),
            access: RemoteAccess.of(context),
            onError: reportToSentry,
            onComplete: () => _resync(context),
          ),
        ),
        // Last of the state classes: its callbacks below reach every one of
        // them through this context, which only sees what is provided above.
        ChangeNotifierProvider<Auth>(
          create: (context) {
            // the uid the state classes are currently keyed on
            String? current;
            return Auth(
              service: api,
              remote: RemoteAccess.of(context),
              onEnter: (session, userId) => _initApp(
                context,
                session,
                userId,
                hasLocalNotifications: hasLocalNotifications,
              ),
              // "Erase my data": the anonymous session's store is this
              // device's alone, so the wipe is the local database's to do
              onErase: db.eraseUser,
              // An anonymous session became an account: its rows move onto the
              // account's uid where that changed, and a replay is owed either
              // way — before the new uid is keyed into anything below.
              onLink: (from, to) async {
                final upsync = Upsync.of(context);
                final preferences = Preferences.of(context);
                await upsync.claim(from: from, to: to);
                if (from != to) await preferences.rekeyUser(from, to);
              },
              onUserChange: (user) {
                router.refresh();
                // One uid replacing another under a running app — an account
                // signed into from an anonymous session. A sign-out clears the
                // state on its way out; this switch has no such moment, so it
                // is cleared here, before the new uid is keyed in. Exercises
                // forgets it was initialized, which is what makes `_initApp`
                // run the full startup again for the new uid.
                if (current != null && user != null && user.id != current) {
                  clearUserState(context);
                }
                current = user?.id;
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
            );
          },
        ),
        Provider<Scrolls>(
          create: (_) => Scrolls(),
        ),
        // "Export my data": reads the mirror straight, through the same
        // adapters the notifiers use, so what goes in the file is what the
        // device holds — no server, and nothing from the health tables.
        // The mirror being *whole* is `Backfill`'s job, not this page's.
        Provider<DataExport>(
          create: (_) => DataExport(
            workouts: db,
            templates: db,
            folders: LocalTemplateFolders(db),
            exercises: db,
            goals: LocalGoals(db),
          ),
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

class _AppState extends State<_App> with WidgetsBindingObserver {
  /// The app's only lifecycle hook, and it sits here because [_App] is the
  /// highest widget that can still read the providers above it.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    // for didChangeLocales; the AppLifecycleListener above cannot carry it
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lifecycle.dispose();
    super.dispose();
  }

  /// Health is the one thing whose truth can change while Heart is in the
  /// background: its permissions are granted in another app entirely, and the
  /// platform never tells us what was decided there. See [Health.onResume],
  /// which throttles itself — this fires on every alt-tab.
  ///
  /// The session is the other: a first launch offline could not mint an
  /// anonymous uid, and coming back is the natural moment to try again.
  void _onResume() {
    if (!mounted) return;
    Health.of(context).onResume();
    Auth.of(context).ensureSession();
  }

  /// Localized backend content (the exercise catalog) is served per request
  /// from `Accept-Language`, so a device language change makes every cached
  /// localized string stale: restate the header, then re-fetch. Order matters
  /// — the re-fetch must go out under the new tag.
  @override
  void didChangeLocales(List<Locale>? locales) {
    final tag = languageTag(locales?.firstOrNull);
    Api.instance.localize(tag);
    if (mounted) {
      Exercises.of(context).onLocaleChanged(tag);
      // sample templates carry names picked at fetch time — same staleness,
      // same cure
      Templates.of(context).onLocaleChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Both brightnesses come from the picked preset's hand-tuned token sets;
    // the seed-color machinery (user-picked and remote-config) is retired.
    final light = theme(widget.theme.preset, .light);
    final dark = theme(widget.theme.preset, .dark);

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
      // Every locale heart_language ships — the backend serves exercise
      // content per request from `Accept-Language` (which states the raw
      // device locale, see `languageTag()`), so content can even lead the
      // chrome: a locale with translated exercises but no ARB yet still gets
      // localized content under English chrome. Every date in the app is
      // `DateFormat(…, localeName)`, so the resolved locale also carries
      // regional conventions (the `en_CA` "6/19" lesson).
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

    // Before anything below dials out: an account whose store is still owed a
    // replay keeps the remote leg closed to the sweeps until the replay is
    // done (see RemoteAccess.replaying). An anonymous session owes nothing.
    final upsync = Upsync.of(context);
    final backfill = Backfill.of(context);
    final owed = switch ((sessionToken, userId)) {
      (String _, String uid) => await upsync.restore(uid),
      _ => false,
    };
    if (!context.mounted) return;

    theme
      ..preset = Preset.fromStored(prefs.getBaseColor(userId))
      ..toMode(prefs.themeMode);

    // `onUserChange` has already set the id — it runs before this — so the only
    // thing left to wait for is the token.
    authenticated.then<void>(
      (_) {
        if (!context.mounted) return;
        Goals.of(context).init();
        // the replay needs the token too; it resumes from the ledger, so a
        // launch mid-run picks up where the last one stopped
        if (owed && userId != null) upsync.run(userId);
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

      init(lastSync: config.exercisesLastSynced, locale: languageTag()).then<void>(
        (hasExercises) {
          // everything below reads or writes against the exercise catalog —
          // templates and workouts persist rows with a foreign key onto
          // `exercises.name`. Running them against an empty catalog trades a
          // reported failure for a constraint violation, so stop here instead.
          if (!hasExercises) return;

          // since workouts initialization looks up exercises
          // in `Exercises`, we must chain these calls this way
          workouts.init().then<void>(
            (_) {
              router.refresh();
              return _initTrainingData(
                workouts: workouts,
                previous: previous,
                stats: stats,
                templates: templates,
                backfill: backfill,
              );
            },
          );
          timers.init();
        },
      );
    }
  });
}

/// Everything that reads the mirror against the server: the history pull, the
/// aggregations over it, the templates and their folders.
///
/// One function because it runs twice in one session's life — at start-up,
/// and again when the upsync of an anonymous session's store completes and the
/// remote leg opens for the first time.
Future<void> _initTrainingData({
  required Workouts workouts,
  required PreviousExercises previous,
  required Stats stats,
  required Templates templates,
  required Backfill backfill,
}) {
  templates.init();
  // Pulls what other devices logged into the local mirror, and heals anything
  // stranded here by a failed save. Until this ran at startup the only thing
  // that ran it was opening the History screen — so a workout from the phone
  // reached the tablet's goals and previous-set tags a launch late, after some
  // unrelated visit to History had quietly seeded it.
  return workouts.initHistory().then<void>(
    (_) async {
      // both read training data straight out of that mirror, so they are only
      // correct once it has been filled
      void readMirror() {
        previous.init();
        stats.init();
      }

      readMirror();

      // …and only *right* once the mirror is the whole account. Until the
      // backfill has run, the aggregations above and every goal that counts
      // workouts are computed over whatever prefix the device happens to hold
      // (#113), so they are computed again when it lands. A marked uid returns
      // here without a request.
      if (workouts.userId case String uid) {
        await backfill.run(uid);
        readMirror();
      }
    },
  );
}

/// The replay is done and the remote leg is open: pull what the account holds
/// — its own exercises, the history the mirror is now part of, its templates
/// and goals — over a mirror that so far only knew this device.
void _resync(BuildContext context) {
  if (!context.mounted) return;
  final exercises = Exercises.of(context);
  final config = RemoteConfig.of(context);
  final workouts = Workouts.of(context);
  final previous = PreviousExercises.of(context);
  final stats = Stats.of(context);
  final templates = Templates.of(context);
  final backfill = Backfill.of(context);
  Goals.of(context).init();
  exercises.init(lastSync: config.exercisesLastSynced, locale: languageTag()).then<void>(
    (hasExercises) {
      if (!hasExercises) return;
      _initTrainingData(
        workouts: workouts,
        previous: previous,
        stats: stats,
        templates: templates,
        backfill: backfill,
      );
    },
  );
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
