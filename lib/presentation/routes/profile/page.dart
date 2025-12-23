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
        builder: (_, workouts, __) {
          return ListView(
            controller: Scrolls.of(context).profileScrollController,
            children: [
              if (workouts.isEmpty)
                Stack(
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
                )
              else
                WorkoutsAggregationChart(workouts: workouts),
              const SizedBox(height: 12),
              PrimaryButton.shrunk(
                onPressed: () async {
                  final charts = Charts.of(context);
                  final returned = await _showNewChartDialog(context, _searchController, _focus);
                  switch (returned) {
                    case Exercise ex:
                      final preference = ChartPreference.exerciseWeight(ex.name);
                      charts.addPreference(preference);
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
          );
        },
      ),
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    Stats.of(context).init();
  }

  void _toAccount() {
    buzz();
    widget.onAccount();
  }

  void _toAvatar() {
    buzz();
    widget.onAvatar();
  }

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
            final returned = await _showExercises(context, controller, focus);
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

Future<Exercise?> _showExercises(BuildContext context, TextEditingController controller, FocusNode focus) {
  final ThemeData(
    colorScheme: ColorScheme(surfaceContainerLow: color),
  ) = Theme.of(
    context,
  );
  return showDialog<Exercise?>(
    context: context,
    builder: (context) {
      final exercises = Exercises.watch(context);
      return Card(
        child: ExercisePicker(
          appBar: SliverPersistentHeader(
            pinned: true,
            delegate: FixedHeightHeaderDelegate(
              backgroundColor: color,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -1),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                    ),
                  ),
                ],
              ),
              height: 40,
              borderRadius: const .all(.circular(12)),
            ),
          ),
          exercises: exercises,
          backgroundColor: color,
          searchController: controller,
          focusNode: focus,
          onExerciseSelected: (exercise) {
            return Navigator.of(context).pop(exercise);
          },
        ),
      );
    },
  );
}
