part of 'router.dart';

// tracks state pf the desktop auth flow
enum _AuthPages {
  login,
  signUp,
  recovery;

  bool get isLogin => this == login;
}

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
            onImportData: context.goToImportData,
          );
        },
        name: _settingsName,
        routes: [
          GoRoute(
            path: _accountManagementPath,
            builder: (_, _) => const AccountManagementPage(onError: reportToSentry),
            name: _accountManagementName,
          ),
          GoRoute(
            path: _importDataPath,
            builder: (_, _) => const ImportDataPage(onError: reportToSentry),
            name: _importDataName,
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
        builder: (_, state) {
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

/// The active-workout sheet is a single global modal on the root navigator.
///
/// It can be opened concurrently from several places — the [HeartRouter._redirect]
/// side-effect on cold start/resume, notification taps, the workout FAB, and
/// template cards. Pushing unconditionally stacks duplicate sheets (the
/// "workout bottom sheet is doubled" bug), so every open funnels through here
/// and no-ops when a `/activeWorkout` match is already anywhere on the stack.
///
/// We scan the whole stack rather than just the top route because [GalleryPage]
/// can be pushed on top of the sheet, so the sheet is not always the topmost
/// match while still being present.
Future<void> _pushActiveWorkoutOnce(GoRouter router) {
  final alreadyOpen = router.routerDelegate.currentConfiguration.matches.any(
    (match) => match.matchedLocation == _activeWorkoutPath,
  );
  if (alreadyOpen) return Future<void>.value();
  return router.push(_activeWorkoutPath);
}

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

          return ActiveWorkoutSheet(
            workouts: workouts,
            onTapImage: context.goToGallery,
          );
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
          selectedId: workoutId,
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
            .wide => const SizedBox.shrink(), // already rendered by the builder
            .compact => HistoryPage(
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
              onTapImage: context.goToGallery,
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
                  copy: workout!,
                  onTapImage: context.goToGallery,
                  onClose: switch (LayoutProvider.of(context)) {
                    .compact => null,
                    .wide => context.goToHistory,
                  },
                );
              } catch (e) {
                throw GoException(e.toString());
              }
            },
            name: _historyEditName,
            // Resolves before deciding, rather than bouncing on a memory miss.
            //
            // The mirror holds only what has been paged in, so a synchronous
            // lookup sent every deep link into older history back to the list —
            // and would send *every* web deep link there, since that client has
            // no warm mirror at all. Redirecting is now reserved for a workout
            // the server itself will not produce.
            redirect: (context, state) async {
              final workouts = Workouts.of(context);
              return switch (state.pathParameters['workoutId']) {
                String id when workouts.lookup(id) != null => null,
                String id => switch (await workouts.fetchWorkout(id)) {
                  true => null,
                  false => _historyPath,
                },
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
          onExercise: (exercise, _) => context.goToExerciseDetail(exercise.name),
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
              onExercise: (exercise, _) => context.goToExerciseDetail(exercise.name),
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
                onExercise: (exercise, _) {
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
                    initialTab: state.uri.queryParameters['tab'],
                    onShareExercise: (exercise, {tab}) {
                      _onShareExercise(context, exercise, tab);
                    },
                    onFilter: context.goToFilteredExercises,
                    onTapAlternative: (alternative) {
                      context.goToExerciseDetail(alternative.name);
                    },
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
                initialTab: state.uri.queryParameters['tab'],
                // compact pushes the detail, so its default back arrow is
                // correct. Wide holds it in a pane with nothing behind it to go
                // back to, and "back" there should mean "put this away".
                leading: switch (LayoutProvider.of(context)) {
                  .compact => null,
                  .wide => IconButton(
                    key: AppKeys.closeDetail,
                    tooltip: L.of(context).close,
                    onPressed: context.closeExerciseDetail,
                    icon: const Icon(Icons.close),
                  ),
                },
                onTapWorkout: (workoutId) {
                  return Workouts.of(context).fetchWorkout(workoutId).then<void>(
                    (_) {
                      if (!context.mounted) return;
                      context.goToWorkoutEditor(workoutId);
                    },
                  );
                },
                onShareExercise: (exercise, {tab}) {
                  _onShareExercise(context, exercise, tab);
                },
                onFilter: context.goToFilteredExercises,
                onTapAlternative: (alternative) {
                  context.goToExerciseDetail(alternative.name);
                },
                onAddToWorkout: (exercise) => _onAddToWorkout(context, exercise),
              );
            },
            // Resolves before deciding, like the history route: a deep link
            // from a cold start arrives before the catalog loads. Bouncing to
            // `/exercises?from=…` here fed the top-level `from` handler, which
            // bounced straight back — go_router hit its redirect limit and the
            // link died on the profile page.
            redirect: (context, state) async {
              final exercises = Exercises.of(context);
              await _exercisesReady(exercises);
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
      // LayoutProvider owns the breakpoint for this route and both branches
      return LayoutProvider(
        currentStack: -1,
        builder: (context, layout, _) {
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
              builder: (_, page, _) {
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
            ),
          };
        },
      );
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
          // This screen is pushed as finishing *starts*, so the sets that just
          // earned a rung may not be in the database yet — goal progress is read
          // back out of it. Waiting on the finish is what makes the answer real
          // rather than one workout stale.
          achievementsCallback: () async {
            final workouts = Workouts.of(context);
            final goals = Goals.of(context);
            final exercises = Exercises.of(context);
            final stats = Stats.of(context);

            // The id the server settled on, not the one this device saved
            // under: `saveWorkout` adopts the server's when they differ, and
            // crediting a rung with the pre-save id had the server reject the
            // attribution outright — it was an id it had never seen.
            final finished = await workouts.finishing;
            // the aggregation is what whole-workout goals are judged against,
            // and it predates the workout that just landed
            await stats.init();

            final stamped = await goals.observeProgress(
              (goal) => currentGoalValue(goal, exercises: exercises, workoutCount: workoutCounter(stats)),
              // this screen is the one place that knows which session earned it
              achievedBy: finished?.id ?? workout.id,
            );

            // A recurring goal is never stamped, so it would otherwise go
            // uncelebrated the week it is met — announced here when this
            // session is what carried the period over.
            final carried = await goals.observePeriodWins(
              valueOf: (goal) => currentGoalValue(goal, exercises: exercises, workoutCount: workoutCounter(stats)),
              valueBefore: (goal) => currentGoalValue(
                goal,
                exercises: exercises,
                workoutCount: workoutCounter(stats),
                without: workout.start,
              ),
            );

            return [...stamped, ...carried];
          },
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

RouteBase _upgradeRequiredRoute() {
  return GoRoute(
    path: _upgradeAppPath,
    builder: (context, _) => const UpgradeRequiredPage(),
    name: _upgradeAppName,
  );
}

RouteBase _galleryRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _galleryPath,
    pageBuilder: (context, state) {
      switch (state.extra) {
        case (Iterable<Media> media, int index, _):
          return CustomTransitionPage(
            key: state.pageKey,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
                  child: child,
                ),
              );
            },
            child: GalleryPage(
              media: media.toList(),
              startingIndex: index,
            ),
          );
        default:
          throw GoError('Unknown navigation pattern to GalleryPage');
      }
    },
    name: _galleryName,
  );
}

/// Resolves once the exercise catalog is initialized, or gives up after a
/// timeout so a failed init (no network, empty catalog) cannot hold the
/// navigation forever — the caller then falls back to the exercise list.
Future<void> _exercisesReady(Exercises exercises) {
  if (exercises.isInitialized) return Future<void>.value();

  final ready = Completer<void>();
  void onChange() {
    if (exercises.isInitialized && !ready.isCompleted) ready.complete();
  }

  exercises.addListener(onChange);
  return ready.future
      .timeout(const Duration(seconds: 10), onTimeout: () {})
      .whenComplete(() => exercises.removeListener(onChange));
}

/// Appends [exercise] to the workout in progress and confirms with a snack —
/// the workout lives on another tab, so the action offers the way there too.
Future<void> _onAddToWorkout(BuildContext context, Exercise exercise) async {
  await Workouts.of(context).startExercise(exercise);
  if (!context.mounted) return;

  final L(:exerciseAddedToWorkout, :goToWorkout) = L.of(context);
  snack(
    context,
    exerciseAddedToWorkout,
    action: SnackBarAction(
      label: goToWorkout,
      onPressed: () {
        if (context.mounted) context.goToActiveWorkout();
      },
    ),
  );
}

Future<void> _onShareExercise(BuildContext context, Exercise exercise, String? tab) async {
  final link = Uri.https(
    AppConfig.of(context).appDomain,
    'exercises/${exercise.name}',
    switch (tab) {
      String value => {'tab': value},
      null => null,
    },
  );
  Clipboard.setData(ClipboardData(text: link.toString()));

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L.of(context).copiedToClipboard),
      ),
    );
  }
}
