library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/app_frame.dart';
import 'package:heart_state/heart_state.dart';

part 'animation.dart';
part 'constants.dart';
part 'extension.dart';

RouteBase _profileRoute() {
  return GoRoute(
    path: _profilePath,
    builder: (context, _) {
      return ProfilePage(
        onSettings: context.goToSettings,
        onAccount: context.goToAccountManagement,
        onAvatar: () {
          final user = Auth.of(context).user;
          if (user?.localAvatar != null) {
            return context.goToAvatar();
          }
          if (user?.remoteAvatar case String avatar when avatar.startsWith('https')) {
            return context.goToAvatar();
          }

          return context.goToAccountManagement();
        },
      );
    },
    name: _profileName,
    routes: [
      GoRoute(
        path: _settingsPath,
        builder: (context, _) {
          return SettingsPage(
            onAccountManagement: context.goToAccountManagement,
          );
        },
        name: _settingsName,
        routes: [
          GoRoute(
            path: _accountManagementPath,
            builder: (__, _) => const AccountManagementPage(onError: reportToSentry),
            name: _accountManagementName,
          ),
        ],
      ),
    ],
  );
}

RouteBase _workoutRoute() {
  return GoRoute(
    path: _workoutPath,
    builder: (context, _) {
      return WorkoutPage(
        goToTemplateEditor: context.goToTemplateEditor,
      );
    },
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
  final navigatorKey = GlobalKey<NavigatorState>();

  return ShellRoute(
    navigatorKey: navigatorKey,
    builder: (context, state, child) {
      final workoutId = state.pathParameters['workoutId'];

      return switch (LayoutProvider.of(context)) {
        LayoutSize.compact => child,
        LayoutSize.wide => HistoryPage(
            onNewWorkout: context.goToWorkouts,
            onSaveAsTemplate: (workout) {
              Templates.of(context).workoutToTemplate(workout);
              context.goToTemplateEditor(newTemplate: true);
            },
            onEditWorkout: (workout) {
              context.goToWorkoutEditor(workout.id);
            },
            onTapWorkout: (workout) {
              context.goToWorkoutEditor(workout.id);
            },
            onDeleteWorkout: (_) {
              context.goToHistory();
            },
            detail: switch (workoutId) {
              String() => child,
              null => null,
            },
          ),
      };
    },
    routes: [
      GoRoute(
        path: _historyPath,
        builder: (context, state) {
          return switch (LayoutProvider.of(context)) {
            LayoutSize.wide => const SizedBox.shrink(), // already rendered by the builder
            LayoutSize.compact => HistoryPage(
                onNewWorkout: context.goToWorkouts,
                onSaveAsTemplate: (workout) {
                  Templates.of(context).workoutToTemplate(workout);
                  context.goToTemplateEditor(newTemplate: true);
                },
                onEditWorkout: (workout) {
                  context.goToWorkoutEditor(workout.id);
                },
                onTapWorkout: (workout) {
                  context.goToWorkoutEditor(workout.id);
                },
              )
          };
        },
        name: _historyName,
        routes: [
          GoRoute(
            path: ':workoutId',
            builder: (context, state) {
              try {
                final workoutId = state.pathParameters['workoutId'];
                final workout = Workouts.of(context).lookup(workoutId!);
                return WorkoutEditor(
                  copy: workout!.copy(sameId: true)..completeAllSets(),
                );
              } catch (e) {
                throw GoException(e.toString());
              }
            },
            name: _historyEditName,
          )
        ],
      ),
    ],
  );
}

RouteBase _exercisesRoute() {
  final navigatorKey = GlobalKey<NavigatorState>();

  return ShellRoute(
    navigatorKey: navigatorKey,
    builder: (context, state, detail) {
      final selectedExerciseId = state.pathParameters['exerciseId'];

      return switch (LayoutProvider.of(context)) {
        LayoutSize.compact => detail,
        LayoutSize.wide => ExercisesPage(
            selectedId: selectedExerciseId,
            detail: switch (selectedExerciseId) {
              null => null,
              _ => detail,
            },
            onExercise: (exercise) => context.goToExerciseDetail(exercise.name),
          onShowArchived: context.goToExerciseArchive,

          ),
      };
    },
    routes: [
      GoRoute(
        path: _exercisesPath,
        name: _exercisesName,
        builder: (context, _) {
          return switch (LayoutProvider.of(context)) {
            LayoutSize.wide => const SizedBox.shrink(), // already rendered by the builder
            LayoutSize.compact => ExercisesPage(
                onExercise: (exercise) => context.goToExerciseDetail(exercise.name),
              onShowArchived: context.goToExerciseArchive,

              ),
          };
        },
        routes: [
          GoRoute(
            path: 'archived',
            builder: (context, _) {
              return ExerciseArchive(
                onExercise: (exercise) {
                  context.goToExerciseDetail(exercise.name);
                },
              );
            },
            name: _exerciseArchive,
            routes: [
              GoRoute(
                path: ':exerciseId',
                builder: (context, state) {
                  final exerciseId = state.pathParameters['exerciseId']!;
                  final exercise = Exercises.of(context).lookup(exerciseId);
                  return ExerciseDetailPage(
                    exercise: exercise!,
                    onTapWorkout: (_) async {},
                  );
                },
                name: _exerciseArchivedDetailName,
              ),
            ],
          ),
          GoRoute(
            path: ':exerciseId',
            name: _exerciseDetailName,
            builder: (context, state) {
              final exerciseId = state.pathParameters['exerciseId']!;
              final exercise = Exercises.of(context).lookup(exerciseId);

              return ExerciseDetailPage(
                exercise: exercise!,
                onTapWorkout: (workoutId) {
                  return Workouts.of(context).fetchWorkout(workoutId).then(
                    (_) {
                      if (!context.mounted) return;
                      context.goToWorkoutEditor(workoutId);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    ],
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
            transitionsBuilder: _pageTransition,
          );
        },
      ),
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
        return WorkoutDone(
          workout: workout!,
          onQuit: context.goToWorkouts,
          workoutsThisWeekCallback: () => Stats.of(context).getWeeklyWorkoutCount(workout.start),
        );
      } catch (e) {
        throw GoException('$e');
      }
    },
    name: _doneName,
  );
}

RouteBase _restoreAccountRoute() {
  return GoRoute(
    path: _restoreAccountPath,
    pageBuilder: (context, state) {
      return CustomTransitionPage(
        key: state.pageKey,
        child: RestoreAccountPage(
          onUndo: context.goToWorkouts,
          onError: reportToSentry,
        ),
        transitionsBuilder: _pageTransition,
      );
    },
    name: _restoreAccountName,
  );
}

RouteBase _avatarRoute() {
  return GoRoute(
    path: _avatarPath,
    builder: (context, _) => AvatarPage(
      onBack: context.goToProfile,
      onEdit: context.goToAccountManagement,
    ),
    name: _avatarName,
  );
}

final class HeartRouter {
  final List<NavigatorObserver>? observers;

  final GoRouter config;

  HeartRouter({this.observers})
    : config = GoRouter(
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
          _loginRoute(),
          _workoutDoneRoute(),
          _restoreAccountRoute(),
          _avatarRoute(),
        ],
        redirect: (context, state) {
          switch (state.fullPath?.split('/')) {
            // login sub-routes
            case ['', _loginName, String part]:
              // there might be a query in path, see _loginRoute
              return state.namedLocation(part, queryParameters: state.uri.queryParameters);
          }

          final auth = Auth.of(context);

          final isLoggedIn = auth.isLoggedIn;

          if (!isLoggedIn) {
            // same as RecoveryPage
            return state.namedLocation(_loginName, queryParameters: state.uri.queryParameters);
          }

          if (Workouts.of(context).hasUnNotifiedActiveWorkout && state.fullPath != _donePath) {
            return _workoutPath;
          }

          if (auth.user?.scheduledForDeletionAt != null) {
            return _restoreAccountPath;
          }

          return null;
        },
      );

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
}
