part of 'profile.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onSettings;
  final VoidCallback onAccount;
  final VoidCallback onAvatar;

  /// Where the no-account dialog's action lands: the login page.
  final VoidCallback onLogIn;

  const new({
    super.key,
    required this.onSettings,
    required this.onAccount,
    required this.onAvatar,
    required this.onLogIn,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AfterLayoutMixin<ProfilePage>, HasHaptic<ProfilePage> {
  final _searchController = TextEditingController();
  final _focus = FocusNode();

  /// Held so the listener can be removed without a context, which `dispose`
  /// cannot safely reach a provider through.
  Workouts? _workouts;

  @override
  void dispose() {
    _workouts?.removeListener(_onWorkoutsChanged);
    _searchController.dispose();
    _focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(
      :logOut,
      :noAccount,
      :settings,
      :workoutsPerWeekTitle,
      :workoutsPerWeekBody,
      :newChart,
      :viewAccountDetails,
      :viewProfilePhoto,
    ) = L.of(
      context,
    );
    final ThemeData(:textTheme, :platform) = Theme.of(context);

    final auth = Auth.watch(context);
    final user = auth.user;
    // between a sign-out and the anonymous session that replaces it
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final User(remoteAvatar: avatar, :email, :displayName, :localAvatar) = user;
    final isAnonymous = auth.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        title: Semantics(
          button: true,
          label: viewAccountDetails,
          child: GestureDetector(
            onTap: _toAccount,
            child: Row(
              spacing: 16,
              children: [
                Semantics(
                  button: true,
                  label: viewProfilePhoto,
                  child: GestureDetector(
                    onTap: _toAvatar,
                    child: Hero(
                      tag: 'avatar',
                      child: Avatar(
                        remote: avatar,
                        local: localAvatar,
                        radius: 24,
                      ),
                    ),
                  ),
                ),
                Text(
                  switch (isAnonymous) {
                    true => noAccount,
                    false => displayName ?? '?',
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: settings,
            onPressed: widget.onSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
          // macos renders things differently
          if (platform == .macOS) const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: switch (isAnonymous) {
              // there is nothing to log out of; the slot says what the session
              // is instead, and opens the one place that explains it
              true => IconButton.outlined(
                key: AppKeys.noAccount,
                tooltip: noAccount,
                onPressed: () => _showNoAccountDialog(context),
                icon: const Icon(Icons.no_accounts_outlined),
              ),
              false => IconButton.outlined(
                tooltip: logOut,
                onPressed: () {
                  AppTheme.of(context).onSignOut();
                  clearState(context);
                },
                icon: const Icon(Icons.logout_rounded),
              ),
            },
          ),
        ],
      ),
      body: Selector<Stats, WorkoutAggregation>(
        selector: (_, provider) => provider.workouts,
        builder: (_, workouts, _) {
          final emptyState = Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(
                child: WorkoutsAggregationChart(
                  opacity: .2,
                  workouts: WorkoutAggregation.dummy(),
                ),
              ),
              Column(
                children: [
                  Text(
                    workoutsPerWeekTitle,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    workoutsPerWeekBody,
                    style: textTheme.bodyLarge,
                  ),
                ],
              ),
            ],
          );

          return CustomScrollView(
            controller: Scrolls.of(context).profileScrollController,
            slivers: [
              // the replay of an anonymous session's store into the account
              // it just became — absent unless one is under way or just was
              const UpsyncRow(),
              // and its pull counterpart: the history being paged down behind
              // the charts that are drawn from it
              const BackfillRow(),
              _ProfileArea(
                workouts: workouts,
                emptyState: emptyState,
              ),
              const HealthSection(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const .symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: .end,
                    children: [
                      PrimaryButton.shrunk(
                        onPressed: () async {
                          final charts = Charts.of(context);
                          final scrolls = Scrolls.of(context);
                          final returned = await _showNewChartDialog(context, _searchController, _focus);
                          switch (returned) {
                            case (Exercise ex, ChartPreferenceType type):
                              final preference = ChartPreference.exercise(ex.id, type);
                              await charts.addPreference(preference);
                              await Future.delayed(const Duration(milliseconds: 100));
                              scrolls.scrollProfileToBottom();
                          }
                        },
                        child: Row(
                          spacing: 6,
                          children: [
                            const Icon(Icons.add_rounded),
                            Text(newChart),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const _Dashboard(),
            ],
          );
        },
      ),
    );
  }

  /// How many finished workouts the app knew about last time the aggregation
  /// was rebuilt. Deleting one — or finishing one elsewhere — has to rebuild it,
  /// or the profile keeps reporting a week that no longer exists and every goal
  /// keeps the value it cached against it.
  int? _knownWorkouts;

  @override
  void afterFirstLayout(BuildContext context) {
    final workouts = _workouts = Workouts.of(context);
    _knownWorkouts = workouts.history.length;
    workouts.addListener(_onWorkoutsChanged);

    Stats.of(context).init();
    _observeGoals();
  }

  /// Rebuilds the aggregation when the set of finished workouts changes.
  ///
  /// [Workouts] notifies constantly during an active session — every set ticked
  /// — so the count is the filter: only a workout appearing or disappearing is
  /// worth re-querying for.
  void _onWorkoutsChanged() {
    if (!mounted) return;
    final count = Workouts.of(context).history.length;
    if (count == _knownWorkouts) return;

    _knownWorkouts = count;
    Stats.of(context).init();
  }

  /// Records anything already achieved, once the goals and the local history
  /// they are measured against are both loaded.
  ///
  /// Here rather than in [Goals] itself because measuring a goal means reaching
  /// into the stats the app computes locally, which the notifier deliberately
  /// knows nothing about.
  Future<void> _observeGoals() async {
    final goals = Goals.of(context);
    final exercises = Exercises.of(context);
    final stats = Stats.of(context);

    await goals.init();
    await goals.observeProgress(
      (goal) => currentGoalValue(goal, exercises: exercises, workoutCount: workoutCounter(stats)),
    );
  }

  /// Account management is about an account — name, photo, deletion — every
  /// bit of which goes through the server. Without one, both taps land on the
  /// dialog that says so instead.
  void _toAccount() {
    buzz();
    switch (Auth.of(context).isAnonymous) {
      case true:
        _showNoAccountDialog(context);
      case false:
        widget.onAccount();
    }
  }

  void _toAvatar() {
    buzz();
    switch (Auth.of(context).isAnonymous) {
      case true:
        _showNoAccountDialog(context);
      case false:
        widget.onAvatar();
    }
  }

  /// The one place the account pitch lives: what the session is, what an
  /// account would add, what losing the phone means, and the way to log in.
  /// No banner and no reminder anywhere else — the icon in the app bar is the
  /// whole prompt, and "not now" means not now.
  Future<void> _showNoAccountDialog(BuildContext context) {
    final L(
      :noAccountTitle,
      :noAccountBodyLocal,
      :noAccountBodySignIn,
      :noAccountBodyLose,
      :notNow,
      :logIn,
    ) = L.of(
      context,
    );
    return showBrandedDialog<void>(
      context,
      icon: Icon(Icons.no_accounts_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
      title: Text(noAccountTitle, textAlign: .center),
      content: Column(
        mainAxisSize: .min,
        spacing: 12,
        children: [
          Text(noAccountBodyLocal, textAlign: .center),
          Text(noAccountBodySignIn, textAlign: .center),
          Text(noAccountBodyLose, textAlign: .center),
        ],
      ),
      actions: [
        _NoAccountActions(
          dismissCopy: notNow,
          logInCopy: logIn,
          onLogIn: () {
            Navigator.of(context, rootNavigator: true).pop();
            widget.onLogIn();
          },
        ),
      ],
    );
  }

  /// If an exercise is selected, [_showExercises] returns a (Exercise, ChartPreferenceType)? record,
  /// and this dialog returns it back to the widget.
  Future<dynamic> _showNewChartDialog(BuildContext context, TextEditingController controller, FocusNode focus) {
    final L(:newChart, :exercises) = L.of(context);
    return showBrandedDialog<dynamic>(
      context,
      title: Text(newChart),
      padding: .zero,
      content: SizedBox(
        width: double.maxFinite,
        child: ListTile(
          onTap: () async {
            final returned = await showExercisePicker(context, controller: controller, focus: focus);
            if (returned != null && context.mounted) {
              return Navigator.of(context, rootNavigator: true).pop(returned);
            }
          },
          title: Text(exercises),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

/// The no-account dialog's two actions: a neutral fill for the way out, the
/// accent — the button's own default, which also owns its ink — for the one
/// action. Not `primaryContainer`: that token is the dialog's own surface, so
/// a button in it disappears.
///
/// A widget rather than two buttons built where the dialog is opened, so the
/// fill comes from the theme the dialog is *showing* under: a dark-mode flip
/// while it is open repaints it, instead of leaving a light fill under
/// dark-mode ink.
class _NoAccountActions extends StatelessWidget {
  final String dismissCopy;
  final String logInCopy;
  final VoidCallback onLogIn;

  const new({required this.dismissCopy, required this.logInCopy, required this.onLogIn});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        PrimaryButton.wide(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Text(dismissCopy),
          ),
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
          },
        ),
        PrimaryButton.wide(
          key: AppKeys.noAccountLogIn,
          onPressed: onLogIn,
          child: Center(
            child: Text(logInCopy),
          ),
        ),
      ],
    );
  }
}
