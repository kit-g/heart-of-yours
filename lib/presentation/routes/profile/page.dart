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
              SliverToBoxAdapter(
                child: workouts.isEmpty ? emptyState : WorkoutsAggregationChart(workouts: workouts),
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
                  ),
                ),
              ),
              const _Charts(),
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

class _Charts extends StatelessWidget {
  const _Charts();

  @override
  Widget build(BuildContext context) {
    final layout = LayoutProvider.of(context);
    final charts = Charts.watch(context);
    final preferences = Preferences.watch(context);
    final exercises = Exercises.watch(context);
    final l = L.of(context);
    final length = charts.length;
    final service = FakeExerciseHistoryService();

    return switch (layout) {
      .compact => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const .symmetric(horizontal: 16.0, vertical: 2),
            child: _Chart(
              preference: charts[index],
              settings: preferences,
              l: l,
              exercises: exercises,
              onDelete: (chart) => charts.removePreference(chart),
              exerciseHistoryService: service,
            ),
          ),
          childCount: length,
        ),
      ),
      .wide => SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.5,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _Chart(
            preference: charts[index],
            settings: preferences,
            exercises: exercises,
            onDelete: (chart) => charts.removePreference(chart),
            l: l,
            exerciseHistoryService: service,
          ),
          childCount: length,
        ),
      ),
    };
  }
}

class _Chart extends StatelessWidget {
  final ChartPreference preference;
  final Preferences settings;
  final Exercises exercises;
  final void Function(ChartPreference) onDelete;
  final ExerciseHistoryService exerciseHistoryService;
  final L l;

  const _Chart({
    required this.preference,
    required this.settings,
    required this.l,
    required this.exercises,
    required this.onDelete,
    required this.exerciseHistoryService,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:dividerColor) = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: .all(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: Padding(
        padding: const .all(8.0),
        child: _chart(context),
      ),
    );
  }

  Widget _chart(BuildContext context) {
    final ThemeData(:textTheme, :dividerColor) = Theme.of(context);
    Widget weightLabel(double y) {
      return switch (y % 2) {
        0 => Text(
          y.toInt().toString(),
          style: textTheme.bodySmall,
        ),
        _ => const SizedBox.shrink(),
      };
    }

    switch (preference.type) {
      case .exerciseWeight:
        final exerciseName = preference.exerciseName!;
        final exercise = exercises.lookup(exerciseName)!;
        return ExerciseChart(
          emptyState: _EmptyState(
            exercise: exercise,
            exerciseHistoryService: exerciseHistoryService,
            onDelete: onDelete,
            iconColor: dividerColor,
            l: l,
            preference: preference,
            textTheme: textTheme,
          ),
          callback: () => exercises.getWeightHistory(exercise),
          customLabel: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text('$exerciseName - ${l.weightUnit}'),
              FeedbackButton.circular(
                tooltip: l.delete,
                onPressed: () => onDelete(preference),
                child: Padding(
                  padding: const .all(1.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: dividerColor,
                  ),
                ),
              ),
            ],
          ),
          converter: (v) => settings.weightValue(v),
          getLeftLabel: weightLabel,
          errorState: const _ErrorState(),
        );
      case .exerciseReps:
        return throw UnimplementedError();
    }
  }
}

class _EmptyState extends StatelessWidget {
  final Exercise exercise;
  final ChartPreference preference;
  final ExerciseHistoryService exerciseHistoryService;
  final Color? iconColor;
  final void Function(ChartPreference) onDelete;
  final L l;
  final TextTheme? textTheme;

  const _EmptyState({
    required this.exercise,
    required this.preference,
    required this.exerciseHistoryService,
    required this.onDelete,
    required this.l,
    required this.iconColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: .center,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.white.withValues(alpha: .4),
            BlendMode.modulate,
          ),
          child: ExerciseChart(
            emptyState: const SizedBox.shrink(),
            callback: () => exerciseHistoryService.getWeightHistory('', exercise),
            converter: (v) => v.toDouble(),
            errorState: const SizedBox.shrink(),
            customLabel: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text('${exercise.name} - ${l.weightUnit}'),
                FeedbackButton.circular(
                  tooltip: l.delete,
                  onPressed: () => onDelete(preference),
                  child: Padding(
                    padding: const .all(1.0),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const .all(32.0),
          child: Column(
            children: [
              Text(
                l.emptyChartStateTitle,
                textAlign: .center,
                style: textTheme?.titleMedium,
              ),
              Text(
                l.emptyChartStateBody,
                textAlign: .center,
                style: textTheme?.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return const Text('error');
  }
}
