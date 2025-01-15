part of 'profile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final L(:logOut, :settings, :workoutsPerWeekTitle, :workoutsPerWeekBody) = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);

    final auth = Auth.watch(context);
    final user = auth.user;
    if (user == null) return const Scaffold();
    final User(:avatar, :email, :displayName) = user;

    final workouts = WorkoutAggregation.fromJson(data['aggregations']!['workouts']!);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: CircleAvatar(
            foregroundImage: switch (avatar) {
              String avatar when avatar.startsWith('https') => NetworkImage(avatar),
              _ => null,
            },
            child: Text(displayName?.substring(0, 1) ?? '?'),
          ),
        ),
        title: Text(displayName ?? '?'),
        actions: [
          IconButton(
            tooltip: settings,
            onPressed: context.goToSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton.outlined(
            tooltip: logOut,
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (workouts.isEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                WorkoutsAggregationChart(
                  opacity: .2,
                  workouts: WorkoutAggregation.dummy(),
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
        ],
      ),
    );
  }

  void _logout(BuildContext context) {
    Auth.of(context).onSignOut();
    Exercises.of(context).onSignOut();
    Preferences.of(context).onSignOut();
    Alarms.of(context).onSignOut();
    Timers.of(context).onSignOut();
    Workouts.of(context).onSignOut();
  }
}

var data = {
  "aggregations": {
    "workouts": <String, dynamic>{
      // "2024-12-30T00:00:00_000000": [
      //   {"id": "2025-01-02T00:00.000000", "name": "Cardio"},
      //   {"id": "2025-01-02T00:00.000000", "name": "Cardio"},
      //   {"id": "2024-12-30T00:00.000000", "name": "Chest"},
      //   {"id": "2025-01-03T00:00.000000", "name": "Back"},
      //   {"id": "2025-01-03T00:00.000000", "name": "Back"},
      //   {"id": "2025-01-05T00:00.000000", "name": "Arms"}
      // ],
      // "2024-12-23T00:00:00_000000": [
      //   { "id": "2024-12-24T00:00.000000", "name": "Legs" },
      //   { "id": "2024-12-28T00:00.000000", "name": "Shoulders" }
      // ],
      // "2024-12-16T00:00:00_000000": [
      //   {"id": "2024-12-18T00:00.000000", "name": "Chest"},
      //   {"id": "2024-12-17T00:00.000000", "name": "Cardio"},
      //   {"id": "2024-12-19T00:00.000000", "name": "Arms"},
      //   // {"id": "2024-12-21T00:00.000000", "name": "Back"},
      //   // {"id": "2024-12-17T00:00.000000", "name": "Cardio"},
      //   // {"id": "2024-12-18T00:00.000000", "name": "Chest"},
      //   // {"id": "2024-12-16T00:00.000000", "name": "Legs"}
      // ],//
      // "2024-12-09T00:00:00_000000": [
      //   {"id": "2024-12-15T00:00.000000", "name": "Shoulders"},
      //   {"id": "2024-12-13T00:00.000000", "name": "Chest"},
      //   {"id": "2024-12-15T00:00.000000", "name": "Shoulders"},
      //   {"id": "2024-12-09T00:00.000000", "name": "Legs"},
      //   // {"id": "2024-12-10T00:00.000000", "name": "Arms"},
      //   {"id": "2024-12-13T00:00.000000", "name": "Chest"}
      // ],
      // "2024-12-02T00:00:00_000000": [
      //   {"id": "2024-12-07T00:00.000000", "name": "Cardio"},
      //   {"id": "2024-12-05T00:00.000000", "name": "Back"},
      //   {"id": "2024-12-02T00:00.000000", "name": "Chest"},
      //   {"id": "2024-12-02T00:00.000000", "name": "Chest"},
      //   {"id": "2024-12-04T00:00.000000", "name": "Shoulders"}
      // ],
      // // "2024-11-25T00:00:00_000000": [
      // //   {"id": "2024-11-28T00:00.000000", "name": "Legs"},
      // //   {"id": "2024-11-27T00:00.000000", "name": "Cardio"},
      // //   {"id": "2024-11-28T00:00.000000", "name": "Legs"},
      // //   {"id": "2024-11-30T00:00.000000", "name": "Back"},
      // //   {"id": "2024-11-29T00:00.000000", "name": "Chest"},
      // //   // {"id": "2024-11-30T00:00.000000", "name": "Back"},
      // //   // {"id": "2024-11-25T00:00.000000", "name": "Arms"}
      // // ],
      // "2024-11-18T00:00:00_000000": [
      //   {"id": "2024-11-22T00:00.000000", "name": "Shoulders"},
      //   {"id": "2024-11-21T00:00.000000", "name": "Cardio"}
      // ],
      // "2024-11-11T00:00:00_000000": [
      //   {"id": "2024-11-15T00:00.000000", "name": "Back"},
      //   {"id": "2024-11-16T00:00.000000", "name": "Legs"}
      // ],
      // // "2024-11-04T00:00:00_000000": [
      // //   {"id": "2024-11-10T00:00.000000", "name": "Arms"},
      // //   {"id": "2024-11-08T00:00.000000", "name": "Chest"}
      // // ],
      // "2024-10-28T00:00:00_000000": [
      //   {"id": "2024-10-29T00:00.000000", "name": "Legs"},
      //   {"id": "2024-10-31T00:00.000000", "name": "Cardio"},
      //   {"id": "2024-10-30T00:00.000000", "name": "Shoulders"},
      //   {"id": "2024-10-29T00:00.000000", "name": "Legs"},
      //   // {"id": "2024-11-02T00:00.000000", "name": "Back"},
      //   // {"id": "2024-10-31T00:00.000000", "name": "Cardio"}
      // ]
    }
  }
};
