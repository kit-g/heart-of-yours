part of 'exercises.dart';

class ExercisesPage extends StatefulWidget {
  final void Function(Exercise) onExercise;
  final String? selectedId;
  final Widget? detail;
  final VoidCallback onShowArchived;
  final VoidCallback onOpenActiveWorkout;

  const ExercisesPage({
    super.key,
    required this.onExercise,
    this.selectedId,
    this.detail,
    required this.onShowArchived,
    required this.onOpenActiveWorkout,
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
    final layout = LayoutProvider.of(context);
    final listview = ExercisePicker(
      appBar: SliverAppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        pinned: true,
        expandedHeight: 80.0,
        flexibleSpace: FlexibleSpaceBar(
          title: Text(L.of(context).exercises),
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
                  .iOS => Icons.more_horiz_rounded,
                  .macOS => Icons.more_horiz_rounded,
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
    );

    return Scaffold(
      body: SafeArea(
        child: switch (layout) {
          .compact => listview,
          .wide => Row(
            children: [
              Expanded(
                flex: 2,
                child: listview,
              ),
              const VerticalDivider(width: 1),
              switch (widget.detail) {
                null => const SizedBox.shrink(),
                Widget detail => Expanded(
                  flex: 3,
                  child: detail,
                ),
              },
            ],
          ),
        },
      ),
      floatingActionButton: WorkoutTimerFloatingButton(
        onPressed: widget.onOpenActiveWorkout,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
