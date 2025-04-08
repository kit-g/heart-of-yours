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
  @override
  Widget build(BuildContext context) {
    final L(:logOut, :settings, :workoutsPerWeekTitle, :workoutsPerWeekBody) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

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
          IconButton.outlined(
            tooltip: logOut,
            onPressed: () => clearState(context),
            icon: const Icon(Icons.logout_rounded),
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
                    )
                  ],
                )
              else
                WorkoutsAggregationChart(workouts: workouts),
              const SizedBox(height: 12),
              const _Ad(),
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
}

class _Ad extends StatelessWidget {
  const _Ad();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return AspectRatio(
      aspectRatio: 5 / 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: colorScheme.primaryContainer,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                  child: Center(
                    child: Text(
                      'More charts coming up!',
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
