part of 'exercises.dart';

/// The user's archived exercises. On a page wide enough for two, the one
/// picked opens beside the list, as in the library (#718).
class ExerciseArchive extends StatelessWidget {
  final void Function(Exercise, TapDownDetails?) onExercise;

  /// The exercise open beside the list.
  final String? selectedId;

  /// Its page, beside the list; absent for none.
  final Widget? detail;

  /// The way back, where the archive is the tab's page rather than one pushed
  /// over it.
  final Widget? leading;

  /// Into the workout under way, where the archive is the tab's page on a
  /// tablet: its button stays, as on the library it took the place of.
  final VoidCallback? onOpenActiveWorkout;

  const new({
    super.key,
    required this.onExercise,
    this.selectedId,
    this.detail,
    this.leading,
    this.onOpenActiveWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final L(:archivedExercises) = L.of(context);
    final archived = Exercises.watch(context).archived.toList();
    final preferences = Preferences.watch(context);
    final goEasy = goEasyOn(context);
    final list = Scaffold(
      appBar: AppBar(
        leading: leading,
        title: Text(archivedExercises),
      ),
      body: ListView.builder(
        itemBuilder: (_, index) {
          final each = archived[index];
          return ExerciseItem(
            exercise: each,
            preferences: preferences,
            goEasy: goEasy,
            selected: false,
            highlighted: each.id == selectedId,
            onExerciseSelected: onExercise,
          );
        },
        itemCount: archived.length,
      ),
    );
    return switch (LayoutProvider.of(context)) {
      .compact => list,
      // nothing picked, the list has the page; a pick opens beside it
      .wide => Scaffold(
        body: SafeArea(
          child: MasterDetail(
            masterWidth: (width) => width * 2 / 5,
            master: list,
            detail: detail,
          ),
        ),
        floatingActionButton: switch (onOpenActiveWorkout) {
          final VoidCallback open => WorkoutTimerFloatingButton(onPressed: open),
          null => null,
        },
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    };
  }
}
