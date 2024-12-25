import 'package:flutter/material.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/presentation/widgets/exercise_picker.dart';
import 'package:heart/presentation/widgets/workout_sheet.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> with AfterLayoutMixin<ExercisesPage> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Consumer<Exercises>(
      builder: (context, exercises, _) {
        return Scaffold(
          body: SafeArea(
            child: ExercisePicker(
              appBar: SliverAppBar(
                scrolledUnderElevation: 0,
                backgroundColor: backgroundColor,
                pinned: true,
                expandedHeight: 80.0,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(L.of(context).exercises),
                ),
              ),
              exercises: exercises,
              searchController: _searchController,
              focusNode: _focusNode,
              backgroundColor: backgroundColor,
              onExerciseSelected: (e) {
                print(e);
              },
            ),
          ),
          floatingActionButton: Selector<Workouts, Workout?>(
            builder: (context, active, child) {
              if (active == null) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                onPressed: () {
                  showWorkoutSheet(context);
                },
                label: const Text('12:34:56'),
              );
            },
            selector: (_, workouts) => workouts.activeWorkout,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    var Exercises(:isInitialized, :init) = Exercises.of(context);
    if (!isInitialized) {
      init();
    }
  }
}
