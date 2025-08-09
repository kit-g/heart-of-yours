library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:heart/core/env/sentry.dart';
import 'package:heart/presentation/routes/done/done.dart';
import 'package:heart/presentation/routes/exercises/exercises.dart';
import 'package:heart/presentation/routes/history/history.dart';
import 'package:heart/presentation/routes/login/login.dart';
import 'package:heart/presentation/routes/profile/profile.dart';
import 'package:heart/presentation/routes/settings/settings.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart/presentation/widgets/app_frame.dart';
import 'package:heart/presentation/widgets/greetings_pane.dart';
import 'package:heart/presentation/widgets/responsive/responsive_builder.dart';
import 'package:heart/presentation/widgets/split_scaffold.dart';
import 'package:heart/presentation/widgets/workout/workout_detail.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

import 'modal_route.dart';

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
        onOpenActiveWorkout: () {
          HapticFeedback.mediumImpact();
          context.goToActiveWorkout();
        },
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

final _rootNavigatorKey = GlobalKey<NavigatorState>();

RouteBase _activeWorkoutRoute() {
  return GoRoute(
    path: _activeWorkoutPath,
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) {
      return ModalSheetPage(
        builder: (context) {
          final workouts = Workouts.watch(context);

          if (workouts.activeWorkout == null) {
            return const SizedBox.shrink();
          }

          return ActiveWorkoutSheet(workouts: workouts);
        },
      );
    },
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
          onNewWorkout: context.goToActiveWorkout,
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
          onOpenActiveWorkout: () {
            HapticFeedback.mediumImpact();
            context.goToActiveWorkout();
          },
          detail: switch (workoutId) {
            String() => child, // workout selected
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
              onNewWorkout: context.goToActiveWorkout,
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
              onOpenActiveWorkout: () {
                HapticFeedback.mediumImpact();
                context.goToActiveWorkout();
              },
            ),
          };
        },
        name: _historyName,
        routes: [
          GoRoute(
            path: ':workoutId',
            builder: (context, state) {
              try {
                final workoutId = state.pathParameters['workoutId']!;
                final workout = Workouts.of(context).lookup(workoutId);
                return WorkoutEditor(
                  copy: workout!.copy(sameId: true)..completeAllSets(),
                );
              } catch (e) {
                throw GoException(e.toString());
              }
            },
            name: _historyEditName,
            redirect: (context, state) {
              return switch (state.pathParameters['workoutId']) {
                String id when Workouts.of(context).lookup(id) != null => null,
                _ => _historyPath,
              };
            },
          ),
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
        .compact => detail,
        .wide => ExercisesPage(
          selectedId: selectedExerciseId,
          detail: switch (selectedExerciseId) {
            null => null,
            _ => detail,
          },
          onExercise: (exercise) => context.goToExerciseDetail(exercise.name),
          onOpenActiveWorkout: () {
            HapticFeedback.mediumImpact();
            context.goToActiveWorkout();
          },
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
            .wide => const SizedBox.shrink(), // already rendered by the builder
            .compact => ExercisesPage(
              onExercise: (exercise) => context.goToExerciseDetail(exercise.name),
              onShowArchived: context.goToExerciseArchive,
              onOpenActiveWorkout: () {
                HapticFeedback.mediumImpact();
                context.goToActiveWorkout();
              },
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
                  return Workouts.of(context).fetchWorkout(workoutId).then<void>(
                    (_) {
                      if (!context.mounted) return;
                      context.goToWorkoutEditor(workoutId);
                    },
                  );
                },
              );
            },
            redirect: (context, state) {
              final exercises = Exercises.of(context);
              // cold start from deep link
              if (!exercises.isInitialized) {
                return state.namedLocation(
                  _exercisesName,
                  queryParameters: {
                    ...state.uri.queryParameters,
                    'from': Uri.encodeComponent(state.uri.toString()),
                  },
                );
              }
              return switch (state.pathParameters['exerciseId']) {
                String id when exercises.lookup(id) != null => null,
                _ => _exercisesPath,
              };
            },
          ),
        ],
      ),
    ],
  );
}

RouteBase _loginRoute() {
  final currentAddress = ValueNotifier<String?>(null);
  final currentPage = ValueNotifier(_AuthPages.login);

  return GoRoute(
    path: _loginPath,
    builder: (context, state) {
      final layout = MediaQuery.sizeOf(context).width >= 600 ? LayoutSize.wide : LayoutSize.compact;
      return switch (layout) {
        // login page and password recovery page will communicate through the query parameter
        // this will enable us to preserve the content of the email field.
        .compact => LoginPage(
          onPasswordRecovery: (address) {
            context.goToPasswordRecoveryPage(address: address);
          },
          onSignUp: (address) {
            context.goToSignUp(address: address);
          },
          address: state.uri.queryParameters['address'],
        ),
        .wide => ValueListenableBuilder<_AuthPages>(
          valueListenable: currentPage,
          builder: (_, page, __) {
            return LayoutProvider(
              currentStack: -1,
              builder: (context, layout, _) {
                return SplitPaneScaffold(
                  reverse: page.isLogin,
                  leftPane: switch (page) {
                    .signUp => SignUpPage(
                      address: currentAddress.value,
                      onLogin: (address) {
                        currentPage.value = .login;
                        currentAddress.value = address;
                      },
                    ),
                    .login => LoginPage(
                      onPasswordRecovery: (address) {
                        currentPage.value = .recovery;
                        currentAddress.value = address;
                      },
                      onSignUp: (address) {
                        currentPage.value = .signUp;
                        currentAddress.value = address;
                      },
                      address: currentAddress.value,
                    ),
                    .recovery => RecoveryPage(
                      address: currentAddress.value,
                      onLinkSent: (address) {
                        currentPage.value = .login;
                        currentAddress.value = address;
                      },
                      isWideScreen: layout == .wide,
                    ),
                  },
                  rightPane: switch (page) {
                    .signUp => GreetingsPane(
                      title: L.of(context).signUpTitle,
                      body: L.of(context).signUpBody,
                    ),
                    .login => GreetingsPane(
                      title: L.of(context).logInTitle,
                      body: L.of(context).logInBody,
                    ),
                    .recovery => GreetingsPane(
                      title: L.of(context).recoverTitle,
                      body: L.of(context).recoverBody,
                    ),
                  },
                );
              },
            );
          },
        ),
      };
    },
    name: _loginName,
    redirect: (context, state) {
      final isLoggedIn = Auth.of(context).isLoggedIn;
      if (isLoggedIn) {
        return state.namedLocation(
          _profileName,
          queryParameters: state.uri.queryParameters,
        );
      }
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
          _activeWorkoutRoute(),
          _loginRoute(),
          _workoutDoneRoute(),
          _restoreAccountRoute(),
          _avatarRoute(),
        ],
        redirect: _redirect,
        onException: (_, state, router) {
          router.go(_profilePath);
          onError?.call('Router.onException: ${state.uri}');
        },
      );

  static FutureOr<String?> _redirect(BuildContext context, GoRouterState state) {
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
      final from = Uri.encodeComponent(state.uri.toString());
      final query = Map<String, String>.from(state.uri.queryParameters);
      query['from'] ??= from;
      return state.namedLocation(_loginName, queryParameters: query);
    }

    if (Workouts.of(context).hasUnNotifiedActiveWorkout && state.fullPath != _donePath) {
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

      // deep link from cold start
      if (state.uri.queryParameters case {'from': String from}) {
        final link = Uri.tryParse(Uri.decodeComponent(from));
        return link?.path;
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

  Future<void> goToActiveWorkout() {
    return config.push(_activeWorkoutPath);
  }
}

// tracks state pf the desktop auth flow
enum _AuthPages {
  login,
  signUp,
  recovery
  ;

  bool get isLogin => this == login;
}
