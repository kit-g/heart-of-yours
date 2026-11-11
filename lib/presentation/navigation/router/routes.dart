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
    // the app opens in the space it was left in (#566): Profile itself, not
    // anything under it, so Settings stays reachable from Coaching
    redirect: (context, state) {
      if (state.fullPath != _profilePath) return null;
      return switch (Preferences.of(context).inCoachingSpace && coachingSpaceOn(context)) {
        true => _coachingClientsPath,
        false => null,
      };
    },
    builder: (context, _) {
      return ProfilePage(
        onCoaching: context.goToCoaching,
        onSettings: context.goToSettings,
        onAccount: context.goToAccountManagement,
        onLogIn: context.goToLogin,
        onRecaps: context.goToRecaps,
        onMonthlyReport: context.goToMonthlyReport,
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
        path: _recapsPath,
        // off, a link here is one the app has no screen for (`docs/opt-in.md`)
        redirect: (context, _) => Preferences.of(context).isOn(.recaps) ? null : _profilePath,
        builder: (context, _) => RecapsPage(onMonth: context.goToMonthlyReport),
        name: _recapsName,
        routes: [
          GoRoute(
            path: ':$_monthParam',
            redirect: (_, state) => _monthOf(state.pathParameters[_monthParam]) == null ? _profilePath : null,
            builder: (_, state) => MonthlyReportPage(month: _monthOf(state.pathParameters[_monthParam])!),
            name: _monthlyReportName,
          ),
        ],
      ),
      GoRoute(
        path: _settingsPath,
        builder: (context, _) {
          return SettingsPage(
            onAccountManagement: context.goToAccountManagement,
            onImportData: context.goToImportData,
            onExportData: context.goToExportData,
            onWhatsNew: context.goToWhatsNew,
            onRestTimers: context.goToRestTimers,
            onPushSettings: context.goToPushSettings,
            onFeatures: context.goToFeatures,
            onDeveloperApi: context.goToApiTokens,
            onErased: context.goToProfile,
          );
        },
        name: _settingsName,
        routes: [
          GoRoute(
            path: _accountManagementPath,
            builder: (context, _) {
              return AccountManagementPage(
                onError: reportToSentry,
                onDeleted: context.goToProfile,
              );
            },
            name: _accountManagementName,
          ),
          GoRoute(
            path: _importDataPath,
            builder: (_, _) => const ImportDataPage(onError: reportToSentry),
            name: _importDataName,
          ),
          GoRoute(
            path: _exportDataPath,
            builder: (_, _) => const ExportDataPage(onError: reportToSentry),
            name: _exportDataName,
          ),
          GoRoute(
            path: _apiTokensPath,
            builder: (context, _) => ApiTokensPage(onNewToken: context.goToNewApiToken, onError: reportToSentry),
            name: _apiTokensName,
            routes: [
              GoRoute(
                path: _newApiTokenPath,
                builder: (context, _) => NewApiTokenPage(onDone: context.goToApiTokens, onError: reportToSentry),
                name: _newApiTokenName,
              ),
            ],
          ),
          GoRoute(
            path: _whatsNewPath,
            builder: (context, _) => WhatsNewPage(onError: reportToSentry, onFeature: context.pushFeature),
            name: _whatsNewName,
          ),
          GoRoute(
            path: _restTimersPath,
            builder: (_, _) => const RestTimersPage(),
            name: _restTimersName,
          ),
          GoRoute(
            path: _pushSettingsPath,
            // off, a link here is one the app has no screen for (`docs/opt-in.md`)
            redirect: (context, _) => switch (pushesOn(context)) {
              true => null,
              false => '$_profilePath/$_settingsPath',
            },
            builder: (_, _) => const PushSettingsPage(),
            name: _pushSettingsName,
          ),
          GoRoute(
            path: _featuresPath,
            builder: (_, state) {
              return FeaturesPage(
                focus: Feature.values
                    .where((feature) => feature.value == state.uri.queryParameters[_featureQuery])
                    .firstOrNull,
                // only What's new passes one: anything else arrived as a link
                source: switch (state.extra) {
                  FeatureLinkSource source => source,
                  _ => .link,
                },
              );
            },
            name: _featuresName,
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
        goToProgram: (program) => context.goToProgram(program.id!),
        goToNewProgram: (folder) => context.goToNewProgram(folder.id!),
        goToLibrary: context.goToProgramLibrary,
        onLogPastWorkout: context.logPast,
      );
    },
    name: _workoutName,
    routes: [
      GoRoute(
        path: 'templates',
        builder: (context, state) {
          return TemplateEditor(
            isNewTemplate: state.uri.queryParameters['newTemplate'] == 'true',
            drafts: Templates.of(context),
          );
        },
        name: _templateEditorName,
      ),
      // before ':programId', which would otherwise take "library" for an id
      GoRoute(
        path: 'programs/library',
        builder: (context, _) => ProgramLibraryPage(onOpen: (program) => context.goToLibraryProgram(program.key)),
        name: _programLibraryName,
        routes: [
          GoRoute(
            path: ':key',
            builder: (context, state) {
              return LibraryProgramPage(
                programKey: state.pathParameters['key']!,
                // drilling in from here stacks: Back is this page
                onProgram: (program) => context.pushProgram(program.id!),
                onLibraryProgram: context.pushLibraryProgram,
              );
            },
            name: _libraryProgramName,
          ),
        ],
      ),
      // before ':programId', which would otherwise take "new" for an id
      GoRoute(
        path: 'programs/new/:folderId',
        builder: (context, state) {
          return ProgramFormPage.fromFolder(
            folderId: state.pathParameters['folderId']!,
            onDone: context.pop,
          );
        },
        name: _newProgramName,
      ),
      GoRoute(
        path: 'programs/:programId',
        builder: (context, state) {
          final programId = state.pathParameters['programId']!;
          return ProgramPage(
            programId: programId,
            onEdit: () => context.goToEditProgram(programId),
            onAbout: context.pushLibraryProgram,
            onEditSession: context.pushTemplateEditor,
            onOpenActiveWorkout: () {
              HapticFeedback.mediumImpact();
              context.goToActiveWorkout();
            },
            onGone: context.pop,
          );
        },
        name: _programName,
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              return ProgramFormPage.edit(
                programId: state.pathParameters['programId']!,
                onDone: context.pop,
              );
            },
            name: _editProgramName,
          ),
        ],
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

/// Opens the active-workout sheet once [Workouts] knows whether there is one.
///
/// The Live Activity's tap ([_openWorkoutPath]) can arrive before that: one that
/// launched the app is routed while `Workouts.init` is still reading the mirror,
/// and asked then, "no active workout" opens a sheet with nothing in it. Bounded,
/// so a session that never resolves cannot leave the tap waiting forever — it
/// then opens nothing, and the workouts tab it landed on is the right answer
/// anyway.
///
/// Always off the current turn: this is called from `_decide`, and pushing a
/// route while a redirect is still being resolved is what the delay in its
/// un-notified branch is also for.
Future<void> _openActiveWorkoutWhenResolved(Workouts workouts) async {
  await Future<void>.delayed(const Duration(milliseconds: 50));

  if (!workouts.hasResolvedActiveWorkout) {
    final resolved = Completer<void>();
    void check() {
      if (!workouts.hasResolvedActiveWorkout || resolved.isCompleted) return;
      workouts.removeListener(check);
      resolved.complete();
    }

    workouts.addListener(check);
    await resolved.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => workouts.removeListener(check),
    );
  }

  // finished or cancelled while the activity was still on the lock screen
  if (workouts.activeWorkout == null) return;

  // read after the wait, not carried across it
  if (_rootNavigatorKey.currentContext case BuildContext context when context.mounted) {
    return _pushActiveWorkoutOnce(GoRouter.of(context));
  }
}

RouteBase _activeWorkoutRoute() {
  return GoRoute(
    path: _activeWorkoutPath,
    parentNavigatorKey: _rootNavigatorKey,
    pageBuilder: (context, state) {
      return ModalSheetPage(
        builder: (context) {
          final workouts = Workouts.watch(context);

          final active = workouts.activeWorkout;
          if (active == null) {
            return const SizedBox.shrink();
          }

          return ActiveWorkoutSheet(
            // a workout replaced under the open sheet — a start link's, whose
            // cancel and start land in one frame — gets a sheet of its own,
            // not the old one's name field (#423)
            key: ValueKey(active.id),
            workouts: workouts,
            onTapImage: context.goToGallery,
            // the sheet steps aside for the program, which is in the
            // Workout tab whichever tab is under it
            onOpenProgram: (program) {
              context.pop();
              context.pushProgramOverPage(program.id!);
            },
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
      // a workout or a skip (#391) in the detail pane, or the suspicious
      // entries (#428)
      final workoutId = state.pathParameters['workoutId'] ?? state.pathParameters['skipId'];
      final reviewing = state.topRoute?.name == _historyReviewName;
      // a workout being logged after the fact (#530) has no id yet
      final logging = state.topRoute?.name == _historyLogName;

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
          onTapSkip: (skip) {
            if (skip.id case final String id) context.goToSkip(id);
          },
          onEntryReview: context.goToEntryReview,
          onLogPastWorkout: context.logPast,
          onOpenActiveWorkout: () {
            HapticFeedback.mediumImpact();
            context.goToActiveWorkout();
          },
          detail: switch ((workoutId, reviewing || logging)) {
            (String(), _) || (_, true) => child, // workout selected, or the list
            (null, false) => null,
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
              onTapSkip: (skip) {
                if (skip.id case final String id) context.goToSkip(id);
              },
              onEntryReview: context.goToEntryReview,
              onLogPastWorkout: context.logPast,
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
          // before ':workoutId', which would take the word for an id
          GoRoute(
            path: 'review',
            builder: (context, state) {
              return EntryReviewPage(
                onOpenWorkout: context.openReviewedWorkout,
                onClose: switch (LayoutProvider.of(context)) {
                  .compact => null,
                  .wide => context.goToHistory,
                },
              );
            },
            name: _historyReviewName,
          ),
          // before ':workoutId' too: a workout that already happened, being
          // filled in (#530). It lives in what it was opened with, so a
          // location without it (a restored or typed one) goes to the list
          GoRoute(
            path: 'log',
            redirect: (_, state) {
              return switch (state.extra) {
                PastWorkout _ => null,
                _ => _historyPath,
              };
            },
            builder: (context, state) {
              final past = state.extra as PastWorkout;
              return WorkoutEditor(
                copy: past.workout,
                logTo: past.logTo,
                onClose: switch (LayoutProvider.of(context)) {
                  .compact => null,
                  .wide => context.goToHistory,
                },
              );
            },
            name: _historyLogName,
          ),
          GoRoute(
            path: 'skips/:skipId',
            builder: (context, state) {
              return SkipPage(
                skipId: state.pathParameters['skipId']!,
                onOpenProgram: context.pushProgramOverPage,
                onClose: switch (LayoutProvider.of(context)) {
                  .compact => null,
                  .wide => context.goToHistory,
                },
              );
            },
            name: _historySkipName,
          ),
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
          onExercise: (exercise, _) => context.goToExerciseDetail(exercise.id),
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
              onExercise: (exercise, _) => context.goToExerciseDetail(exercise.id),
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
                  context.goToExerciseDetail(exercise.id);
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
                      context.goToExerciseDetail(alternative.id);
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
              final exercise = _resolveExercise(Exercises.of(context), exerciseId);

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
                onHistoryMoved: (target) => context.replaceExerciseDetail(target.id),
                onTapWorkout: (workoutId) {
                  return Workouts.of(context).fetchWorkout(workoutId).then<void>(
                    (_) {
                      if (!context.mounted) return;
                      context.goToExerciseWorkout(exerciseId, workoutId);
                    },
                  );
                },
                onShareExercise: (exercise, {tab}) {
                  _onShareExercise(context, exercise, tab);
                },
                onFilter: context.goToFilteredExercises,
                onTapAlternative: (alternative) {
                  context.goToExerciseDetail(alternative.id);
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
                String id when _resolveExercise(exercises, id) != null => null,
                _ => _exercisesPath,
              };
            },
            routes: [
              // A workout opened from the exercise's history. Same editor the
              // history stack builds, hosted here so the reader never leaves
              // the exercises stack (or, on a tablet, its pane).
              GoRoute(
                path: 'workout/:workoutId',
                name: _exerciseWorkoutName,
                builder: (context, state) {
                  try {
                    final workoutId = state.pathParameters['workoutId']!;
                    final exerciseId = state.pathParameters['exerciseId']!;
                    final workout = Workouts.of(context).lookup(workoutId);
                    return WorkoutEditor(
                      copy: workout!,
                      onTapImage: context.goToGallery,
                      // compact is pushed, so the default back arrow returns
                      // to the exercise; the wide pane has no stack behind it,
                      // so close swaps the exercise detail back in
                      onClose: switch (LayoutProvider.of(context)) {
                        .compact => null,
                        .wide => () => context.goToExerciseDetail(exerciseId),
                      },
                    );
                  } catch (e) {
                    throw GoException(e.toString());
                  }
                },
                // Resolves before deciding, like the history editor: the
                // mirror holds only what has been paged in.
                redirect: (context, state) async {
                  final workouts = Workouts.of(context);
                  final detailPath = '$_exercisesPath/${state.pathParameters['exerciseId']}';
                  return switch (state.pathParameters['workoutId']) {
                    String id when workouts.lookup(id) != null => null,
                    String id => switch (await workouts.fetchWorkout(id)) {
                      true => null,
                      false => detailPath,
                    },
                    _ => detailPath,
                  };
                },
              ),
            ],
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
      // An anonymous session came here from its profile and may go back to it;
      // with no session at all this page is the gate, and there is no back.
      final onClose = switch (Auth.of(context).isLoggedIn) {
        true => context.goToProfile,
        false => null,
      };

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
              onClose: onClose,
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
                      onClose: onClose,
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
      // an anonymous session is logged in, and is exactly who this page is for
      final Auth(:isLoggedIn, :isAnonymous) = Auth.of(context);
      if (isLoggedIn && !isAnonymous) {
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
          workoutsThisWeekCallback: () => Stats.of(
            context,
          ).getWeeklyWorkoutCount(workout.start, firstWeekday: Preferences.of(context).firstWeekday),
          // This screen is pushed as finishing *starts*, so the sets that just
          // earned a rung may not be in the database yet — goal progress is read
          // back out of it. Waiting on the finish is what makes the answer real
          // rather than one workout stale.
          achievementsCallback: () async {
            final workouts = Workouts.of(context);
            final goals = Goals.of(context);
            final exercises = Exercises.of(context);
            final stats = Stats.of(context);
            final firstWeekday = Preferences.of(context).firstWeekday;
            // a goal a running program's cadence overrides is not judged, so
            // nothing celebrates what is set aside
            final running = runningPrograms(context);
            bool setAside(Goal goal) => pausedByPrograms(goal, running);

            // The id the server settled on, not the one this device saved
            // under: `saveWorkout` adopts the server's when they differ, and
            // crediting a rung with the pre-save id had the server reject the
            // attribution outright — it was an id it had never seen.
            final finished = await workouts.finishing;
            // the aggregation is what whole-workout goals are judged against,
            // and it predates the workout that just landed
            await stats.init();
            // the windows every goal below reads, each read once; `without`
            // filters what was read, so the before reading shares them too
            final lensSets = sharedLensSets(stats.getLensSets);
            final stamped = await goals.observeProgress(
              (goal) => currentGoalValue(
                goal,
                exercises: exercises,
                firstWeekday: firstWeekday,
                workoutCount: workoutCounter(stats, firstWeekday: firstWeekday),
                lensSets: lensSets,
              ),
              // this screen is the one place that knows which session earned it
              achievedBy: finished?.id ?? workout.id,
              setAside: setAside,
            );

            // A recurring goal is never stamped, so it would otherwise go
            // uncelebrated the week it is met — announced here when this
            // session is what carried the period over.
            final carried = await goals.observePeriodWins(
              setAside: setAside,
              valueOf: (goal) => currentGoalValue(
                goal,
                exercises: exercises,
                firstWeekday: firstWeekday,
                workoutCount: workoutCounter(stats, firstWeekday: firstWeekday),
                lensSets: lensSets,
              ),
              valueBefore: (goal) => currentGoalValue(
                goal,
                exercises: exercises,
                firstWeekday: firstWeekday,
                workoutCount: workoutCounter(stats, firstWeekday: firstWeekday),
                lensSets: lensSets,
                without: workout.start,
              ),
            );

            return [...stamped, ...carried];
          },
          // Same contract as the goals: wait out the write, then ask which
          // records now credit this session. The fold ties records to the
          // first session that set them, so an equalled-not-beaten value
          // stays with its original owner and is not re-celebrated here.
          recordsCallback: () async {
            final workouts = Workouts.of(context);
            final exercises = Exercises.of(context);

            final finished = await workouts.finishing ?? workout;
            return recordsSetBy(finished.id, finished, lookup: exercises.getExerciseRecords);
          },
          // the finish started the rules running (#350); this is their answer,
          // and nothing for a session they never ran on
          growthCallback: () => Programs.of(context).grownBy(workout.id) ?? Future.value(const []),
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

/// The first-launch carousel, on the root navigator so no shell chrome shows
/// under it. Both ways out mark it seen first, so the redirect that put the
/// reader here lets them leave; the deep link it may carry (`from`) rides on
/// to the profile, where the top-level redirect honours it.
RouteBase _onboardingRoute() {
  return GoRoute(
    path: _onboardingPath,
    name: _onboardingName,
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) {
      return OnboardingPage(
        onContinue: () {
          Preferences.of(context).markOnboardingSeen();
          context.goNamed(_profileName, queryParameters: state.uri.queryParameters);
        },
        onLogIn: () {
          Preferences.of(context).markOnboardingSeen();
          context.goToLogin();
        },
      );
    },
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

/// A deep-link reference to an exercise: the uuid for internal navigation,
/// or the env-stable slug from a shared link — see [_onShareExercise].
Exercise? _resolveExercise(Exercises exercises, String reference) {
  return exercises.lookup(reference) ?? exercises.lookupByKey(reference);
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

/// A shared link crosses environments and installs, and a uuid only resolves
/// in the database that minted it — so library links carry the env-stable
/// content slug ([Exercise.key]). Customs have no slug (and nothing to
/// resolve to elsewhere), so their link keeps the id and works on this
/// device's own install.
Future<void> _onShareExercise(BuildContext context, Exercise exercise, String? tab) async {
  final link = Uri.https(
    AppConfig.of(context).appDomain,
    'exercises/${exercise.key ?? exercise.id}',
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

/// A program's page over any tab (#F36): pushed on the root, so Back is the
/// page it was opened from.
RouteBase _programOverRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _programOverPath,
    name: _programOverName,
    builder: (context, state) {
      final programId = state.pathParameters['programId']!;
      // outside the shell, so the layout is this route's to provide
      return LayoutProvider(
        currentStack: -1,
        builder: (context, _, _) => ProgramPage(
          programId: programId,
          onEdit: () => context.pushProgramEditOver(programId),
          onAbout: context.pushLibraryProgramOver,
          onEditSession: context.pushTemplateEditor,
          onOpenActiveWorkout: () {
            HapticFeedback.mediumImpact();
            context.goToActiveWorkout();
          },
          onGone: context.pop,
        ),
      );
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: 'edit',
        name: _programEditOverName,
        builder: (context, state) {
          return LayoutProvider(
            currentStack: -1,
            builder: (context, _, _) => ProgramFormPage.edit(
              programId: state.pathParameters['programId']!,
              onDone: context.pop,
            ),
          );
        },
      ),
    ],
  );
}

/// The exercise library under a filter, over the tab that asked (#F37): a
/// count on the profile opens the exercises behind it, and Back returns to
/// the profile.
RouteBase _filteredExercisesRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _filteredExercisesPath,
    name: _filteredExercisesName,
    builder: (context, _) {
      // outside the shell, so the layout is this route's to provide
      return LayoutProvider(
        currentStack: -1,
        builder: (context, _, _) => ExercisesPage(
          leading: const BackButton(),
          onExercise: (exercise, _) => context.pushExerciseOver(exercise.id),
          onShowArchived: context.goToExerciseArchive,
          onOpenActiveWorkout: () {
            HapticFeedback.mediumImpact();
            context.goToActiveWorkout();
          },
        ),
      );
    },
  );
}

/// A library program over any tab: its next programs and the user's copy
/// stack over it in turn.
RouteBase _libraryProgramOverRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _libraryProgramOverPath,
    name: _libraryProgramOverName,
    builder: (context, state) {
      return LayoutProvider(
        currentStack: -1,
        builder: (context, _, _) => LibraryProgramPage(
          programKey: state.pathParameters['key']!,
          onProgram: (program) => context.pushProgramOverPage(program.id!),
          onLibraryProgram: context.pushLibraryProgramOver,
        ),
      );
    },
  );
}

/// An exercise over any tab: from the filtered library a profile count
/// opened, so Back walks back to the profile.
RouteBase _exerciseOverRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _exerciseOverPath,
    name: _exerciseOverName,
    builder: (context, state) {
      final exerciseId = state.pathParameters['exerciseId']!;
      final exercise = _resolveExercise(Exercises.of(context), exerciseId);
      if (exercise == null) return const Scaffold();
      return LayoutProvider(
        currentStack: -1,
        builder: (context, _, _) => ExerciseDetailPage(
          exercise: exercise,
          initialTab: state.uri.queryParameters['tab'],
          onTapWorkout: (workoutId) {
            return Workouts.of(context).fetchWorkout(workoutId).then<void>((_) {
              if (context.mounted) context.pushWorkoutOver(workoutId);
            });
          },
          onShareExercise: (exercise, {tab}) => _onShareExercise(context, exercise, tab),
          onFilter: (filter) => HeartRouter.of(context).goToFilteredExercises(Exercises.of(context), filter),
          onTapAlternative: (alternative) => context.pushExerciseOver(alternative.id),
          onAddToWorkout: (exercise) => _onAddToWorkout(context, exercise),
        ),
      );
    },
  );
}

/// A past workout over any tab: a goal rung it earned opens it where the
/// goal was, and Back returns there.
RouteBase _workoutOverRoute() {
  return GoRoute(
    parentNavigatorKey: _rootNavigatorKey,
    path: _workoutOverPath,
    name: _workoutOverName,
    builder: (context, state) {
      final workout = Workouts.of(context).lookup(state.pathParameters['workoutId']!);
      if (workout == null) return const Scaffold();
      return LayoutProvider(
        currentStack: -1,
        builder: (context, _, _) => WorkoutEditor(copy: workout, onTapImage: context.goToGallery),
      );
    },
  );
}

/// `2026-09`: a month in a path, by its first day.
String _monthKey(DateTime month) => '${month.year}-${month.month.toString().padLeft(2, '0')}';

/// The month a path names, or null for anything that is not `yyyy-MM`.
DateTime? _monthOf(String? key) {
  return switch (key?.split('-')) {
    [final year, final month] when month.length == 2 => switch ((int.tryParse(year), int.tryParse(month))) {
      (final int year, final int month) when month >= 1 && month <= 12 => DateTime(year, month),
      _ => null,
    },
    _ => null,
  };
}

/// The Coaching space (#566): its own shell and tabs, there only while
/// [coachingSpaceOn]. Off, a link into it is one the app has no screen for.
RouteBase _coachingRoute() {
  String? off(BuildContext context, GoRouterState _) => coachingSpaceOn(context) ? null : _profilePath;

  GoRoute page(String path, String name, Widget Function(VoidCallback onYourTraining) build) {
    return GoRoute(
      path: path,
      name: name,
      redirect: off,
      builder: (context, _) => build(context.leaveCoaching),
    );
  }

  return StatefulShellRoute.indexedStack(
    pageBuilder: (context, state, shell) {
      return NoTransitionPage<void>(
        key: state.pageKey,
        child: CoachingFrame(
          shell: shell,
          onYourTraining: context.leaveCoaching,
          onBackToWorkout: () {
            // the sheet goes over the Workout tab, as a Live Activity's tap
            // does, once the router has left the space: pushed in the same
            // frame, it would land over Coaching
            final router = GoRouter.of(context);
            context.leaveCoaching(to: _workoutName);
            WidgetsBinding.instance.addPostFrameCallback((_) => _pushActiveWorkoutOnce(router));
          },
        ),
      );
    },
    branches: [
      StatefulShellBranch(
        routes: [page(_coachingClientsPath, _coachingClientsName, (back) => ClientsPage(onYourTraining: back))],
      ),
      StatefulShellBranch(
        routes: [page(_coachingMessagesPath, _coachingMessagesName, (back) => CoachMessagesPage(onYourTraining: back))],
      ),
      StatefulShellBranch(routes: [_coachingProgramsRoute(off)]),
      StatefulShellBranch(
        routes: [page(_coachingMePath, _coachingMeName, (back) => CoachMePage(onYourTraining: back))],
      ),
    ],
  );
}

/// A coach's library (#557): the list, a new program, one program, and the
/// program form and template editor on it, as the coach's own programs have.
GoRoute _coachingProgramsRoute(GoRouterRedirect off) {
  return GoRoute(
    path: _coachingProgramsPath,
    name: _coachingProgramsName,
    redirect: off,
    builder: (context, _) {
      return CoachProgramsPage(
        onYourTraining: context.leaveCoaching,
        onOpen: context.goToCoachingProgram,
        onNew: context.goToNewCoachingProgram,
      );
    },
    routes: [
      // before ':programId', which would otherwise take "new" for an id
      GoRoute(
        path: 'new',
        name: _coachingNewProgramName,
        builder: (context, _) {
          final l = L.of(context);
          String? made;
          return ProgramFieldsForm(
            initial: Program(name: '', perWeek: 3, weeks: 8),
            title: l.newProgram,
            saveLabel: l.coachingProgramCreate,
            withNote: true,
            onSave: (fields) async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final program = await CoachLibrary.of(context).create(Program(name: '').withFields(fields));
                made = program.id;
                return true;
              } catch (error, stacktrace) {
                reportToSentry(error, stacktrace: stacktrace);
                messenger.snack(l.coachingProgramCreateFailed);
                return false;
              }
            },
            onDone: () => switch (made) {
              final String id => context.goToCoachingProgram(id),
              null => context.goToCoachingPrograms(),
            },
          );
        },
      ),
      GoRoute(
        path: ':programId',
        name: _coachingProgramName,
        builder: (context, state) {
          final programId = state.pathParameters['programId']!;
          return CoachProgramPage(
            key: ValueKey(programId),
            programId: programId,
            onEdit: () => context.pushCoachingProgramEdit(programId),
            onEditSession: ({required isNew}) => context.pushCoachingProgramSession(programId, isNew: isNew),
            onGone: context.goToCoachingPrograms,
          );
        },
        routes: [
          GoRoute(
            path: 'edit',
            name: _coachingProgramEditName,
            builder: (context, state) {
              final l = L.of(context);
              final library = CoachLibrary.of(context);
              final programId = state.pathParameters['programId']!;
              return switch (library.lookup(programId)) {
                final CoachLibraryProgram program => ProgramFieldsForm(
                  key: ValueKey(programId),
                  initial: program.program,
                  title: l.editProgram,
                  saveLabel: l.save,
                  withNote: true,
                  // one that doesn't reach the server is kept, and its page
                  // says so: the form has done its part either way
                  onSave: (fields) async {
                    final now = library.lookup(programId) ?? program;
                    await library.save(now.copyWith(program: now.program.withFields(fields)));
                    return true;
                  },
                  onDone: context.pop,
                ),
                null => Scaffold(appBar: AppBar()),
              };
            },
          ),
          GoRoute(
            path: 'session',
            name: _coachingProgramSessionName,
            builder: (context, state) {
              final l = L.of(context);
              final isNew = state.uri.queryParameters['new'] == 'true';
              return TemplateEditor(
                isNewTemplate: isNew,
                drafts: CoachLibrary.of(context),
                words: (
                  title: switch (isNew) {
                    true => l.coachingProgramNewSession,
                    false => l.coachingProgramEditSession,
                  },
                  hint: l.coachingProgramSessionName,
                ),
              );
            },
          ),
        ],
      ),
    ],
  );
}

/// A coach's invitation link (#553), whichever switch is on: the page is Your
/// coach's ask. A link without a token is one the app has no screen for.
RouteBase _invitationRoute() {
  return GoRoute(
    path: _invitationPath,
    // a token the server could have made, or no screen: the API refuses any
    // other before it reaches a path
    redirect: (_, state) => switch (state.uri.queryParameters[_invitationToken]) {
      final String token when _invitationTokenShape.hasMatch(token) => null,
      _ => _profilePath,
    },
    builder: (context, state) {
      final token = state.uri.queryParameters[_invitationToken]!;
      return InvitationPage(
        // a second link over the first is a new page, with its own preview
        key: ValueKey(token),
        token: token,
        fingerprint: switch (state.uri.fragment) {
          '' => null,
          final String fragment => fragment,
        },
        onDone: context.goToProfile,
        onMakeAccount: context.goToLogin,
      );
    },
  );
}
