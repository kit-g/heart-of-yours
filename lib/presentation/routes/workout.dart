import 'package:flutter/material.dart';
import 'package:heart/presentation/widgets/workout/active_workout.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';

class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<Workouts>(
        builder: (__, workouts, _) {
          return Scaffold(
            body: ActiveWorkout(
              workouts: workouts,
              appBar: SliverAppBar(
                scrolledUnderElevation: 0,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                pinned: true,
                expandedHeight: 80.0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(workouts.activeWorkout?.name ?? L.of(context).startWorkout),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
