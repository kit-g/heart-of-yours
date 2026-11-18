library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/app_upgrade.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/env/shortcuts.dart';
import 'package:heart/core/utils/goal_crossings.dart';
import 'package:heart/core/utils/program_calendar.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/navigation/program_link.dart';
import 'package:heart/presentation/navigation/pushes.dart' show pushesOn;
import 'package:heart/presentation/navigation/shortcuts.dart';
import 'package:heart/presentation/routes/coaching/coaching.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/messages/messages.dart';
import 'package:heart/presentation/routes/onboarding/onboarding.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/recaps/recaps.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/settings/upgrade_app.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/goals/goals.dart' show goalJudge;
import 'package:heart/presentation/widgets/app_frame.dart';
import 'package:heart/presentation/widgets/greetings_pane.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/metrics.dart' show readableWidth;
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/split_scaffold.dart';
import 'package:heart/presentation/widgets/workout/past_workout.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

import 'modal_route.dart';

part 'animation.dart';
part 'constants.dart';
part 'extension.dart';
part 'routes.dart';

final _logger = Logger('Router');

final class HeartRouter {
  final List<NavigatorObserver>? observers;

  final GoRouter config;

  new({this.observers})
    : config = GoRouter(
        navigatorKey: _rootNavigatorKey,
        debugLogDiagnostics: false,
        initialLocation: _profilePath,
        observers: observers,
        onEnter: _onEnter,
        routes: [
          StatefulShellRoute.indexedStack(
            pageBuilder: (context, state, shell) {
              return _spacePage(
                context,
                key: state.pageKey,
                child: AppFrame(shell: shell, onCoaching: context.goToCoaching),
              );
            },
            branches: [
              StatefulShellBranch(
                routes: [_profileRoute()],
              ),
              StatefulShellBranch(
                routes: [_workoutRoute()],
              ),
              StatefulShellBranch(
                routes: [_historyRoute()],
              ),
              StatefulShellBranch(
                routes: [_exercisesRoute()],
              ),
            ],
          ),
          _coachingRoute(),
          _invitationRoute(),
          _threadRoute(),
          _upgradeRequiredRoute(),
          _onboardingRoute(),
          _activeWorkoutRoute(),
          _loginRoute(),
          _workoutDoneRoute(),
          _restoreAccountRoute(),
          _avatarRoute(),
          _galleryRoute(),
          _programOverRoute(),
          _filteredExercisesRoute(),
          _exerciseArchiveOverRoute(),
          _libraryProgramOverRoute(),
          _exerciseOverRoute(),
          _workoutOverRoute(),
          if (kIsWeb)
            // Apple sign-in redirect
            GoRoute(
              path: _applePath,
              builder: (context, state) {
                return const Scaffold();
              },
            ),
        ],
        redirect: _redirect,
        onException: (_, state, router) {
          router.go(_profilePath);
          // The site's other pages. iOS's association claims all of
          // heart-of.me, so a tap on the privacy policy lands here; that is
          // not a broken route.
          if (state.uri.path.endsWith('.html')) return;
          // a link to somewhere the app has no screen for: worth knowing about,
          // not an error to triage. The path only — a query can carry anything.
          _logger.warning('No route for ${state.uri.path}');
        },
      );

  /// The Live Activity's tap, while the workout it opens is already on screen
  /// (#227), goes nowhere. Let through, [_decide] would switch to the workouts
  /// tab and open the sheet again — a jank over a screen that was already
  /// right, since the tap also brings a backgrounded app to the front exactly
  /// as it was left.
  ///
  /// With the Exercises tab left out (#608), a link into it (a shared
  /// exercise, the archive) opens the same page over the screen on view
  /// instead ([_openOverTheTab]). Only over the app's own tabs: on a gate
  /// (upgrade, restore, sign-in) the link goes on to [_decide], which holds it
  /// until the tabs are back ([takeLinkOverTheTab]), as it does a cold start's.
  static OnEnterResult _onEnter(BuildContext context, GoRouterState _, GoRouterState next, GoRouter router) {
    final current = router.routerDelegate.currentConfiguration;
    final onScreen = current.matches.any((match) => match.matchedLocation == _activeWorkoutPath);
    if (next.uri.path == _openWorkoutPath && onScreen) return const Block.stop();
    final overTabs = current.isNotEmpty && current.matches.first.route is StatefulShellRoute;
    if (overTabs && !AppVersionSentry.instance.upgradeRequired) {
      if (_overTheTab(context, next.uri) case final _OverTheTab link) {
        return Block.then(() => _openOverTheTab(context, router, link));
      }
    }
    return const Allow();
  }

  /// Whether the location on view is inside the Exercises tab.
  static bool onExercisesTab(BuildContext context) {
    return switch (GoRouter.of(context).state.uri.pathSegments) {
      [_exercisesName, ...] => true,
      _ => false,
    };
  }

  /// A link into the left-out Exercises tab that arrived before there was a
  /// screen to open it over: a cold start's, or one that met a gate.
  static _OverTheTab? _heldLink;

  /// Opens the link [_decide] held, once the app's tabs are on screen: the
  /// frame calls it after its first frame.
  static void takeLinkOverTheTab(BuildContext context) {
    if (_heldLink case final _OverTheTab link) {
      _heldLink = null;
      _openOverTheTab(context, GoRouter.of(context), link);
    }
  }

  /// The page for [link], over whatever is on screen. An exercise waits for
  /// the catalog, as the tab's own route does, since a link can come before
  /// it has loaded; one the device cannot find opens the library instead, as
  /// in the tab.
  static Future<void> _openOverTheTab(BuildContext context, GoRouter router, _OverTheTab link) async {
    final location = switch (link) {
      _ExerciseLink(:final reference, :final tab) => await () async {
        final exercises = Exercises.of(context);
        await _exercisesReady(exercises);
        return switch (_resolveExercise(exercises, reference)) {
          final Exercise exercise => router.namedLocation(
            _exerciseOverName,
            pathParameters: {'exerciseId': exercise.id},
            queryParameters: {'tab': ?tab},
          ),
          null => router.namedLocation(_filteredExercisesName),
        };
      }(),
      _ArchiveLink() => router.namedLocation(_exerciseArchiveOverName),
      _LibraryLink() => router.namedLocation(_filteredExercisesName),
    };
    // a second tap on the same link does not stack a second copy
    if (router.state.uri.toString() == location) return;
    router.push(location);
  }

  /// What [uri], a location inside the Exercises tab, opens while the tab is
  /// left out (#608). Null while the tab is there, or for a location outside
  /// it. Off means turned off: before the preferences load, the tab is there.
  static _OverTheTab? _overTheTab(BuildContext context, Uri uri) {
    if (Preferences.of(context).featureAnswer(.exercisesTab) != .off) return null;
    final tab = uri.queryParameters['tab'];
    return switch (uri.pathSegments) {
      [_exercisesName] => const _LibraryLink(),
      [_exercisesName, _exerciseArchivedSegment] => const _ArchiveLink(),
      // an exercise, archived or not; and a workout opened from its page,
      // which, over the tab, is a tap away on the exercise's history
      [_exercisesName, _exerciseArchivedSegment, final String id] ||
      [_exercisesName, final String id] ||
      [_exercisesName, final String id, _exerciseWorkoutSegment, _] => _ExerciseLink(id, tab: tab),
      _ => null,
    };
  }

  static FutureOr<String?> _redirect(BuildContext context, GoRouterState state) {
    // A first launch's opening screen is decided on a stored flag (see the
    // onboarding block in `_decide`), and until the store has been read the
    // flag reads as "seen" — so the first decision on mobile waits for it,
    // rather than opening the app and swapping the onboarding in a moment
    // later. A cold start pays this once, for as long as the platform takes to
    // hand over its preferences; every decision after finds it read.
    final prefs = Preferences.of(context);
    if (kIsWeb || prefs.isInitialized) return _decide(context, state);
    return prefs.initialized.then<String?>(
      (_) {
        // a tree torn down mid-wait (a test's) has nowhere left to go
        if (!context.mounted) return null;
        return _decide(context, state);
      },
    );
  }

  static FutureOr<String?> _decide(BuildContext context, GoRouterState state) {
    final upgradeRequired = AppVersionSentry.instance.upgradeRequired;

    // app version to low, show dedicated UX
    if (state.fullPath == _upgradeAppPath) {
      // stay on upgrade page if still required
      if (upgradeRequired) return null;
      // otherwise, go to profile
      return _profilePath;
    }

    // redirect to upgrade page if required
    if (upgradeRequired) {
      return _upgradeAppPath;
    }

    // The Live Activity's tap target is an intent, not a screen:
    // `_activeWorkoutPath` is a modal sheet *pushed* onto whatever stack is
    // there (`_pushActiveWorkoutOnce`), so arriving at it as a location draws a
    // barrier over an empty navigator — the grey screen a Dynamic Island tap
    // produced in 1.9.0, with nothing to dismiss to. Land on the workouts tab
    // and push the sheet over it, the way a notification tap does.
    if (state.uri.path == _openWorkoutPath) {
      unawaited(_openActiveWorkoutWhenResolved(Workouts.of(context)));
      return _workoutPath;
    }

    switch (state.uri.path.split('/')) {
      // website path that points at account management page
      case ['', 'account.html']:
        return state.namedLocation(_accountManagementName);
    }

    switch (state.fullPath?.split('/')) {
      // login sub-routes
      case ['', _loginName, String part]:
        // there might be a query in path, see _loginRoute
        return state.namedLocation(part, queryParameters: state.uri.queryParameters);
      // Apple sign-in redirect, handled by Auth class
      case ['', _applePath]:
        return null;
    }

    final auth = Auth.of(context);

    final isLoggedIn = auth.isLoggedIn;

    // The sign-in gate is the web's alone. On mobile there is no such thing as
    // being signed out: a missing user is replaced by an anonymous one (see
    // Auth.ensureSession), the app works without an account, and the login
    // page is reached by name — from the profile's no-account dialog. The
    // one exception is a device that could not get a session at all, where
    // the gate is the only page that can still do something.
    if (!isLoggedIn && (kIsWeb || auth.sessionUnavailable)) {
      // same as RecoveryPage
      final from = Uri.encodeComponent(state.uri.toString());
      final query = Map<String, String>.from(state.uri.queryParameters);
      query['from'] ??= from;
      return state.namedLocation(_loginName, queryParameters: query);
    }

    // The first launch opens on the onboarding, once, before the anonymous
    // session lands anyone in the app — and only for a session with no account
    // behind it: an install that signs in already knows what an account adds.
    // The flag is a device's, so a later sign-out does not bring it back. The
    // web keeps its sign-in gate and never sees this.
    final isOnboarding = state.fullPath == _onboardingPath;
    final needsOnboarding =
        !kIsWeb && !Preferences.of(context).onboardingSeen && (auth.user == null || auth.isAnonymous);
    switch ((isOnboarding, needsOnboarding)) {
      case (true, true):
        return null;
      case (false, true):
        // same as the sign-in gate: a deep link opening a fresh install is
        // carried through and honoured on the way out
        final from = Uri.encodeComponent(state.uri.toString());
        final query = Map<String, String>.from(state.uri.queryParameters);
        query['from'] ??= from;
        return state.namedLocation(_onboardingName, queryParameters: query);
      case (true, false):
        return state.namedLocation(_profileName, queryParameters: state.uri.queryParameters);
      case (false, false):
        break;
    }

    // An active workout the user has not been shown: land on the workouts tab
    // and open its sheet over it, once. Marked shown here, where the decision
    // is made — it used to wait for WorkoutPage's first layout, and until then
    // every navigation was rewritten to the tab, the sheet's own push
    // included, each scheduling one more push: a stack of workouts pages and
    // no sheet (test/router_test.dart). The sheet's route is never rewritten.
    final workouts = Workouts.of(context);
    if (workouts.hasUnNotifiedActiveWorkout && state.fullPath != _donePath && state.fullPath != _activeWorkoutPath) {
      workouts.notifyOfActiveWorkout();
      Future.delayed(const Duration(milliseconds: 50)).then(
        (_) {
          _rootNavigatorKey.currentContext?.goToActiveWorkout();
        },
      );
      return _workoutPath;
    }

    if (auth.user?.scheduledForDeletionAt != null) {
      return _restoreAccountPath;
    }

    // A command from outside the app (#284): land on the workouts tab and do
    // what it asks over it. After the onboarding and the gates above, so a
    // fresh install meets them first and the link is carried through `from`,
    // and before the active-workout block below, which would otherwise take
    // the tab for itself and lose the link.
    if (_shortcut(context, state.uri) case String path) return path;

    // A calendar event's link (#391): like a command, it lands on the workouts
    // tab and does its work over it.
    if (_programSessionLink(context, state.uri) case String path) return path;

    // A link into the Exercises tab while it is left out (#608), with no tab
    // on screen to open it over (a cold start, or a gate it was carried
    // through): it lands on the first tab, and the frame opens it over that.
    if (_overTheTab(context, state.uri) case final _OverTheTab link) {
      _heldLink = link;
      return _profilePath;
    }

    // deep link carried through the login flow
    if (state.uri.queryParameters case {'from': String from}) {
      final carried = Uri.tryParse(Uri.decodeComponent(from));
      // A command has no screen to redirect to, and go_router does not decide
      // a redirect's destination again when nothing matches it: the link
      // would die as "no route". So a carried command is applied from here.
      if (carried case Uri uri) {
        if (_shortcut(context, uri) case String path) return path;
        if (_programSessionLink(context, uri) case String path) return path;
      }
      // the fragment too: an invitation's carries the coach's key fingerprint,
      // and a fresh install is exactly who arrives through one (#553)
      return switch (carried) {
        Uri(:final path, :final query, :final fragment) => Uri(
          path: path,
          query: switch (query) {
            '' => null,
            final query => query,
          },
          fragment: switch (fragment) {
            '' => null,
            final fragment => fragment,
          },
        ).toString(),
        null => null,
      };
    }

    return null;
  }

  /// Where a [ProgramSessionLink] in [uri] sends the app, having set it going
  /// — or null: not one. With no program shown there is none to open, and
  /// the link is only the workouts tab; which program is shown is known once
  /// the programs are read, so the link itself asks again (#593).
  static String? _programSessionLink(BuildContext context, Uri uri) {
    if (ProgramSessionLink.parse(uri) case ProgramSessionLink link) {
      if (Preferences.of(context).programsReach) {
        unawaited(
          runProgramSessionLink(
            link,
            programs: Programs.of(context),
            templates: Templates.of(context),
            workouts: Workouts.of(context),
            navigator: _rootNavigatorKey,
          ),
        );
      }
      return _workoutPath;
    }
    return null;
  }

  /// Where a [ShortcutLink] in [uri] sends the app, having set it going — or
  /// null: not a command, or the feature switched off, in which case the link
  /// is one the app has no screen for and goes where those go.
  static String? _shortcut(BuildContext context, Uri uri) {
    if (ShortcutLink.parse(uri) case ShortcutLink link) {
      if (Preferences.of(context).featureAnswer(.shortcuts) == .off) return null;
      unawaited(
        runShortcutLink(
          link,
          workouts: Workouts.of(context),
          templates: Templates.of(context),
          preferences: Preferences.of(context),
          navigator: _rootNavigatorKey,
        ),
      );
      return _workoutPath;
    }
    return null;
  }

  static HeartRouter of(BuildContext context) {
    return Provider.of<HeartRouter>(context, listen: false);
  }

  /// Null where no router is provided — a widget test's bare tree.
  static HeartRouter? maybeOf(BuildContext context) {
    return Provider.of<HeartRouter?>(context, listen: false);
  }

  /// A context under the root navigator, for a dialog shown by code that
  /// sits above it — the presenters in the app's `builder`.
  BuildContext? get rootContext => _rootNavigatorKey.currentContext;

  void refresh() {
    return config.refresh();
  }

  /// The Coaching space's clients, from a push about one (#567).
  void goToCoachingClients() => config.goNamed(_coachingClientsName);

  /// The Coaching space's messages, from a push saying one arrived (#567).
  void goToCoachingMessages() => config.goNamed(_coachingMessagesName);

  /// One conversation of the coach's, in Coaching (#556).
  void goToCoachingThread(String connectionId) {
    config.goNamed(_coachingThreadName, pathParameters: {'connectionId': connectionId});
  }

  /// A student's conversation with their coach, over the app (#556).
  void openThread(String connectionId) {
    config.pushNamed(_threadName, pathParameters: {'connectionId': connectionId});
  }

  /// A coach's invitation (#553), as its link would open it.
  void openInvitation(String token, {String? fingerprint}) {
    return config.go(
      Uri(path: _invitationPath, queryParameters: {_invitationToken: token}, fragment: fingerprint).toString(),
    );
  }

  void goToExercise(String exerciseId) {
    return config.goNamed(
      'workout',
      queryParameters: {'exerciseId': exerciseId},
    );
  }

  Future<void> goToActiveWorkout() {
    return _pushActiveWorkoutOnce(config);
  }

  /// Opens the active workout's sheet and completes once it is on screen — not
  /// once it is closed, which is what [goToActiveWorkout]'s push completes on.
  /// For something that goes over the sheet, such as the Finish question a
  /// link asks (#284): a dialog shown before the sheet's page has landed is
  /// attached to the page under it, and the sheet then covers it.
  Future<void> showActiveWorkout() async {
    if (!_isActiveWorkoutOpen) unawaited(_pushActiveWorkoutOnce(config));
    // the push is parsed off this turn and built a frame later; bounded, so
    // a sheet that never comes (the workout finished meanwhile) cannot hang
    for (var frames = 0; frames < 30 && !_isActiveWorkoutOpen; frames++) {
      await WidgetsBinding.instance.endOfFrame;
    }
    await WidgetsBinding.instance.endOfFrame;
  }

  bool get _isActiveWorkoutOpen {
    return config.routerDelegate.currentConfiguration.matches.any(
      (match) => match.matchedLocation == _activeWorkoutPath,
    );
  }

  void goToWorkouts() {
    return config.goNamed(_workoutName);
  }

  /// The summary of a workout just finished — from the phone's Finish, or the
  /// watch's (#183), which arrives above any route and has no router context.
  void goToWorkoutDone(String? workoutId) {
    return config.goNamed(_doneName, queryParameters: {'workoutId': workoutId});
  }

  /// Opens one past session — what a goal rung links back to, crediting the
  /// workout that met it.
  void goToWorkoutEditor(String workoutId) {
    return config.go('$_historyPath/$workoutId');
  }

  /// A program's page, from outside it: a calendar event's link (#391).
  void goToProgram(String programId) {
    return config.goNamed(_programName, pathParameters: {'programId': programId});
  }

  /// The library showing only [filter] — from a count on the profile, the
  /// exercises behind it — the previous filters cleared, as a chip's tap does.
  ///
  /// Pushed over the tab it was opened from, so Back — Android's too —
  /// returns there rather than leaving the Exercises tab, or the app.
  void goToFilteredExercises(Exercises exercises, ExerciseFilter filter) {
    exercises
      ..clearFilters()
      ..addFilter(filter);
    config.pushNamed(_filteredExercisesName);
  }

  /// A program's page over whichever tab it was opened from — a workout in
  /// History, an exercise's chart, a goal on the profile: Back returns there
  /// rather than to the Workout tab's root.
  void pushProgramOver(String programId) {
    config.pushNamed(_programOverName, pathParameters: {'programId': programId});
  }

  /// A past workout over whichever tab it was opened from — a goal rung it
  /// earned: Back returns there rather than to History's list.
  void pushWorkoutOver(String workoutId) {
    config.pushNamed(_workoutOverName, pathParameters: {'workoutId': workoutId});
  }

  /// A program's page over the Workout tab's page that named it — a folder
  /// its sessions live in: pushed, so Back returns there.
  void pushProgram(String programId) {
    config.pushNamed(_programName, pathParameters: {'programId': programId});
  }

  /// A day set aside with "Not today" (#312), in History.
  void goToSkip(String skipId) {
    return config.goNamed(_historySkipName, pathParameters: {'skipId': skipId});
  }
}

/// A location inside the Exercises tab, read while the tab is left out (#608).
sealed class _OverTheTab {
  const new();
}

/// An exercise by id or by a shared link's slug, and the tab of its page.
final class _ExerciseLink extends _OverTheTab {
  final String reference;
  final String? tab;

  const new(this.reference, {this.tab});
}

final class _ArchiveLink extends _OverTheTab {
  const new();
}

final class _LibraryLink extends _OverTheTab {
  const new();
}
