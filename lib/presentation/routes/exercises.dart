import 'package:flutter/material.dart';
import 'package:heart/core/utils/misc.dart';
import 'package:heart/core/utils/scrolls.dart';
import 'package:heart/presentation/widgets/exercises/exercises.dart';
import 'package:heart/presentation/widgets/workout/timer.dart';
import 'package:heart_language/heart_language.dart';
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
    final exercises = Exercises.watch(context);
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
              centerTitle: true,
            ),
          ),
          exercises: exercises,
          searchController: _searchController,
          focusNode: _focusNode,
          backgroundColor: backgroundColor,
          onExerciseSelected: (e) {
            //
          },
        ),
      ),
      floatingActionButton: WorkoutTimerFloatingButton(
        scrollableController: Scrolls.of(context).exercisesDraggableController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
