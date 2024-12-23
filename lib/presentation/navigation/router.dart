import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/presentation/routes/exercises.dart';
import 'package:heart/presentation/routes/history.dart';
import 'package:heart/presentation/routes/settings.dart';
import 'package:heart/presentation/routes/workout.dart';
import 'package:heart_state/heart_state.dart';

import '../routes/login.dart';
import '../routes/profile.dart';
import '../widgets/app_frame.dart';

export 'package:go_router/go_router.dart' show GoRouterState;

const _profileName = 'profile';
const _profilePath = '/$_profileName';
const _loginName = 'login';
const _loginPath = '/$_loginName';
const _settingsName = 'settings';
const _settingsPath = _settingsName;
const _workoutName = 'workout';
const _workoutPath = '/$_workoutName';
const _historyName = 'history';
const _historyPath = '/$_historyName';
const _exercisesName = 'exercises';
const _exercisesPath = '/$_exercisesName';

RouteBase _profileRoute() {
  return GoRoute(
    path: _profilePath,
    builder: (__, _) => const ProfilePage(),
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
    builder: (__, _) => const LoginPage(),
    name: _loginName,
    redirect: (context, state) {
      final isLoggedIn = Auth.of(context).isLoggedIn;
      if (isLoggedIn) return _profilePath;
      return null;
    },
  );
}

abstract final class HeartRouter {
  static final config = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: _profilePath,
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
    ],
    redirect: (context, state) {
      final isLoggedIn = Auth.of(context).isLoggedIn;
      if (!isLoggedIn) return _loginPath;
      return null;
    },
  );

  static void refresh() {
    return config.refresh();
  }
}

extension ContextNavigation on BuildContext {
  void goHome() {
    return goNamed(_profileName);
  }

  void goToSettings() {
    return goNamed(_settingsName);
  }
}
