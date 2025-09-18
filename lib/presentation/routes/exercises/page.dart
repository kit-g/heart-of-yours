part of 'exercises.dart';

class ExercisesPage extends StatefulWidget {
  final void Function(Exercise) onExercise;
  final VoidCallback onShowArchived;

  const ExercisesPage({
    super.key,
    required this.onExercise,
    required this.onShowArchived,
  });

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final _focusNode = FocusNode();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(scaffoldBackgroundColor: backgroundColor, :platform) = Theme.of(context);
    final exercises = Exercises.watch(context);
    final L(:newExercise, exercises: exCopy, :exerciseOptions) = L.of(context);
    return Scaffold(
      body: SafeArea(
        child: ExercisePicker(
          appBar: SliverAppBar(
            scrolledUnderElevation: 0,
            backgroundColor: backgroundColor,
            pinned: true,
            expandedHeight: 80.0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(exCopy),
              centerTitle: true,
            ),
            actions: [
              if (exercises.archived.isNotEmpty)
                IconButton(
                  tooltip: exerciseOptions,
                  onPressed: () {
                    _onExerciseOptions(context, onShowArchived: widget.onShowArchived);
                  },
                  icon: Icon(
                    switch (platform) {
                      TargetPlatform.iOS => Icons.more_horiz_rounded,
                      TargetPlatform.macOS => Icons.more_horiz_rounded,
                      _ => Icons.more_vert_rounded,
                    },
                  ),
                ),
              IconButton(
                tooltip: newExercise,
                onPressed: () {
                  showNewExerciseDialog(context);
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          exercises: exercises,
          searchController: _searchController,
          focusNode: _focusNode,
          backgroundColor: backgroundColor,
          onExerciseSelected: widget.onExercise,
        ),
      ),
      floatingActionButton: WorkoutTimerFloatingButton(
        scrollableController: Scrolls.of(context).exercisesDraggableController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
