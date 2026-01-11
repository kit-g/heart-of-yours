library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/app_upgrade.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/settings/upgrade_app.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/app_frame.dart';
import 'package:heart/presentation/widgets/greetings_pane.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/split_scaffold.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';

import 'modal_route.dart';

part 'animation.dart';
part 'constants.dart';
part 'extension.dart';
part 'routes.dart';

final class HeartRouter {
  final List<NavigatorObserver>? observers;
  final void Function(dynamic error)? onError;

  final GoRouter config;

  HeartRouter({this.observers, this.onError})
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

    if (!isLoggedIn) {
      // same as RecoveryPage
      final from = Uri.encodeComponent(state.uri.toString());
      final query = Map<String, String>.from(state.uri.queryParameters);
      query['from'] ??= from;
      return state.namedLocation(_loginName, queryParameters: query);
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

    // deep link from cold start
    if (state.uri.queryParameters case {'from': String from}) {
      final link = Uri.tryParse(Uri.decodeComponent(from));
      return link?.path;
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
    return config.push(_activeWorkoutPath);
  }

  void goToWorkouts() {
    return config.goNamed(_workoutName);
  }
}
