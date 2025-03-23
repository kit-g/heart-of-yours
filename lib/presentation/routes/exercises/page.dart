part of 'exercises.dart';

class ExercisesPage extends StatefulWidget {
  final void Function(Exercise) onExercise;

  const ExercisesPage({
    super.key,
    required this.onExercise,
  });

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> with AfterLayoutMixin<ExercisesPage> {
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
          // onExerciseSelected: (e) {
          //   showAdaptiveDialog(
          //     context: context,
          //     barrierDismissible: true,
          //     builder: (context) {
          //       return Dialog(
          //         child: ExerciseDetailPage(
          //           exercise: e,
          //         ),
          //       );
          //     },
          //   );
          // },
          onExerciseSelected: widget.onExercise,
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
