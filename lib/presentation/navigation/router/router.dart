library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/app_upgrade.dart';
import 'package:heart/core/env/config.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/core/utils/goals.dart';
import 'package:heart/core/utils/records.dart';
import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/onboarding/onboarding.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/settings/upgrade_app.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/app_frame.dart';
import 'package:heart/presentation/widgets/greetings_pane.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/split_scaffold.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

import 'modal_route.dart';

part 'animation.dart';
part 'constants.dart';
part 'extension.dart';
part 'routes.dart';

final class HeartRouter {
  final List<NavigatorObserver>? observers;
  final void Function(dynamic error)? onError;

  final GoRouter config;

  new({this.observers, this.onError})
    : config = GoRouter(
        navigatorKey: _rootNavigatorKey,
        debugLogDiagnostics: false,
        initialLocation: _profilePath,
        observers: observers,
        routes: [
          StatefulShellRoute.indexedStack(
            pageBuilder: (_, state, shell) {
              return NoTransitionPage<void>(
                key: state.pageKey,
                child: AppFrame(shell: shell),
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
          _upgradeRequiredRoute(),
          _onboardingRoute(),
          _activeWorkoutRoute(),
          _loginRoute(),
          _workoutDoneRoute(),
          _restoreAccountRoute(),
          _avatarRoute(),
          _galleryRoute(),
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
          onError?.call('Router.onException: ${state.uri}');
        },
      );

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

    if (Workouts.of(context).hasUnNotifiedActiveWorkout && state.fullPath != _donePath) {
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

    // deep link carried through the login flow
    if (state.uri.queryParameters case {'from': String from}) {
      return switch (Uri.tryParse(Uri.decodeComponent(from))) {
        Uri(hasQuery: true, :final path, :final query) => '$path?$query',
        Uri(:final path) => path,
        null => null,
      };
    }

    return null;
  }

  static HeartRouter of(BuildContext context) {
    return Provider.of<HeartRouter>(context, listen: false);
  }

  void refresh() {
    return config.refresh();
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

  void goToWorkouts() {
    return config.goNamed(_workoutName);
  }

  /// Opens one past session — what a goal rung links back to, crediting the
  /// workout that met it.
  void goToWorkoutEditor(String workoutId) {
    return config.go('$_historyPath/$workoutId');
  }
}
