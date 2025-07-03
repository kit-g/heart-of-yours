part of 'exercises.dart';

class ExercisesPage extends StatefulWidget {
  final void Function(Exercise) onExercise;
  final String? selectedId;
  final Widget? detail;

  const ExercisesPage({
    super.key,
    required this.onExercise,
    this.selectedId,
    this.detail,
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
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final exercises = Exercises.watch(context);
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
          LayoutSize.compact => listview,
          LayoutSize.wide => Row(
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
        scrollableController: Scrolls.of(context).exercisesDraggableController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
