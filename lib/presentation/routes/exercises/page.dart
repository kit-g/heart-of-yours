part of 'exercises.dart';

class ExercisesPage extends StatefulWidget {
  final void Function(Exercise, TapDownDetails?) onExercise;
  final String? selectedId;
  final Widget? detail;
  final VoidCallback onShowArchived;
  final VoidCallback onOpenActiveWorkout;

  /// The way back, where the library is pushed over another tab rather than
  /// being the tab itself.
  final Widget? leading;

  const new({
    super.key,
    required this.onExercise,
    this.selectedId,
    this.detail,
    required this.onShowArchived,
    required this.onOpenActiveWorkout,
    this.leading,
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
    final L(exercises: exCopy, :exerciseOptions) = L.of(context);
    final layout = LayoutProvider.of(context);
    final listview = ExercisePicker(
      // the library, not a picker: no recently done above it
      showsRecent: false,
      appBar: SliverAppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        leading: widget.leading,
        pinned: true,
        expandedHeight: 80.0,
        flexibleSpace: FlexibleSpaceBar(
          title: Text(L.of(context).exercises),
          centerTitle: true,
        ),
        actions: [
          // a Builder for the button's own context: the options menu hangs
          // off the button
          Builder(
            builder: (button) => IconButton(
              tooltip: exerciseOptions,
              onPressed: () {
                _onExerciseOptions(
                  button,
                  onShowArchived: widget.onShowArchived,
                  hasArchived: exercises.archived.isNotEmpty,
                );
              },
              icon: Icon(
                switch (platform) {
                  .iOS || .macOS => Icons.more_horiz_rounded,
                  _ => Icons.more_vert_rounded,
                },
              ),
            ),
          ),
        ],
      ),
      exercises: exercises,
      searchController: _searchController,
      focusNode: _focusNode,
      backgroundColor: backgroundColor,
      onExerciseSelected: widget.onExercise,
      highlightedName: widget.selectedId,
      // the search that found nothing is the name the new one most likely
      // has; created, it is what that search finds (#529)
      onCreateExercise: (name) => showNewExerciseDialog(context, name: name),
    );

    return Scaffold(
      body: SafeArea(
        child: switch (layout) {
          .compact => listview,
          // nothing picked, the list has the page; a pick opens beside it
          .wide => MasterDetail(
            masterWidth: (width) => width * 2 / 5,
            master: listview,
            detail: widget.detail,
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
