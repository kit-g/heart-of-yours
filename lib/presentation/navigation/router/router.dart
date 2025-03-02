library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/done.dart';
import 'package:heart/presentation/routes/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart_state/heart_state.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../routes/login/login.dart';
import '../../routes/profile/profile.dart';
import '../../widgets/app_frame.dart';

part 'constants.dart';

part 'extension.dart';

RouteBase _profileRoute() {
  return GoRoute(
    path: _profilePath,
    builder: (context, _) {
      return ProfilePage(
        onSettings: context.goToSettings,
      );
    },
    name: _profileName,
    routes: [
      GoRoute(
        path: _settingsPath,
        builder: (__, _) => const SettingsPage(),
        name: _settingsName,
      )
    ],
  );
}

RouteBase _workoutRoute() {
  return GoRoute(
    path: _workoutPath,
    builder: (__, _) => const WorkoutPage(),
    name: _workoutName,
    routes: [
      GoRoute(
        path: 'templates',
        builder: (__, state) {
          return TemplateEditor(
            isNewTemplate: state.uri.queryParameters['newTemplate'] == 'true',
          );
        },
        name: _templateEditorName,
      ),
    ],
  );
}

RouteBase _historyRoute() {
  return GoRoute(
    path: _historyPath,
    builder: (__, _) => const HistoryPage(),
    name: _historyName,
  );
}

RouteBase _exercisesRoute() {
  return GoRoute(
    path: _exercisesPath,
    builder: (__, _) => const ExercisesPage(),
    name: _exercisesName,
  );
}

RouteBase _loginRoute() {
  return GoRoute(
    path: _loginPath,
    builder: (context, state) {
      // login page and password recovery page will communicate through the query parameter
      // this will enable us to preserve the content of the email field.
      return LoginPage(
        onPasswordRecovery: (address) {
          context.goToPasswordRecoveryPage(address: address);
        },
        onSignUp: (address) {
          context.goToSignUp(address: address);
        },
        address: state.uri.queryParameters['address'],
      );
    },
    name: _loginName,
    redirect: (context, state) {
      final isLoggedIn = Auth.of(context).isLoggedIn;
      if (isLoggedIn) return _profilePath;
      return null;
    },
    routes: [
      GoRoute(
        path: _recoveryName,
        builder: (context, state) {
          return RecoveryPage(
            address: state.uri.queryParameters['address'],
            onLinkSent: (address) {
              return context.goNamed(_loginName, queryParameters: {'address': address});
            },
          );
        },
        name: _recoveryName,
      ),
      GoRoute(
        path: _signUpName,
        name: _signUpName,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: SignUpPage(
              address: state.uri.queryParameters['address'],
              onLogin: (address) {
                return context.goNamed(_loginName, queryParameters: {'address': address});
              },
            ),
            transitionsBuilder: (__, animation, _, child) {
              var scaleAnimation = Tween(begin: .8, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                ),
              );

              return ScaleTransition(
                scale: scaleAnimation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
          );
        },
      )
    ],
  );
}

RouteBase _workoutDoneRoute() {
  return GoRoute(
    path: _donePath,
    builder: (context, state) {
      try {
        final id = state.uri.queryParameters['workoutId'];
        final workout = Workouts.of(context).lookup(id!);
        return WorkoutDone(workout: workout!);
      } catch (_) {
        return const Scaffold();
      }
    },
    name: _doneName,
  );
}

abstract final class HeartRouter {
  static final config = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: _profilePath,
    observers: [
      SentryNavigatorObserver(),
    ],
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
      _loginRoute(),
      _workoutDoneRoute(),
    ],
    redirect: (context, state) {
      switch (state.fullPath?.split('/')) {
        // login sub-routes
        case ['', _loginName, String part]:
          // there might be a query in path, see _loginRoute
          return state.namedLocation(part, queryParameters: state.uri.queryParameters);
      }

      final isLoggedIn = Auth.of(context).isLoggedIn;

      if (!isLoggedIn) {
        // same as RecoveryPage
        return state.namedLocation(_loginName, queryParameters: state.uri.queryParameters);
      }

      if (Workouts.of(context).hasUnNotifiedActiveWorkout) {
        Workouts.of(context).notifyOfActiveWorkout();
        return _workoutPath;
      }

      return null;
    },
  );

  static void refresh() {
    return config.refresh();
  }

  static void goToExercise(String exerciseId) {
    return config.goNamed(
      'workout',
      queryParameters: {'exerciseId': exerciseId},
    );
  }
}
