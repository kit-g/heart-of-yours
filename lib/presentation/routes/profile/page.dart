part of 'profile.dart';

class ProfilePage extends StatefulWidget {
  final VoidCallback onSettings;
  final VoidCallback onAccount;
  final VoidCallback onAvatar;

  const ProfilePage({
    super.key,
    required this.onSettings,
    required this.onAccount,
    required this.onAvatar,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with AfterLayoutMixin<ProfilePage>, HasHaptic<ProfilePage> {
  final _searchController = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final L(:logOut, :settings, :workoutsPerWeekTitle, :workoutsPerWeekBody, :newChart) = L.of(context);
    final ThemeData(:textTheme, :platform) = Theme.of(context);

    final auth = Auth.watch(context);
    final user = auth.user;
    if (user == null) return const Scaffold();
    final User(remoteAvatar: avatar, :email, :displayName, :localAvatar) = user;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        title: GestureDetector(
          onTap: _toAccount,
          child: Row(
            spacing: 16,
            children: [
              GestureDetector(
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
              Text(displayName ?? '?'),
            ],
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
            child: IconButton.outlined(
              tooltip: logOut,
              onPressed: () {
                AppTheme.of(context).onSignOut();
                clearState(context);
              },
              icon: const Icon(Icons.logout_rounded),
            ),
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
              _ProfileArea(
                workouts: workouts,
                emptyState: emptyState,
              ),
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
                              final preference = ChartPreference.exercise(ex.name, type);
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

  @override
  void afterFirstLayout(BuildContext context) {
    Stats.of(context).init();
    _observeGoals();
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
      (goal) => currentGoalValue(
        goal,
        exercises: exercises,
        workouts: stats.workouts,
        workoutsThisMonth: () => stats.getMonthlyWorkoutCount(DateTime.now()),
      ),
    );
  }

  void _toAccount() {
    buzz();
    widget.onAccount();
  }

  void _toAvatar() {
    buzz();
    widget.onAvatar();
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
