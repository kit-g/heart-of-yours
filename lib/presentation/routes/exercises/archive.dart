part of 'exercises.dart';

class ExerciseArchive extends StatelessWidget {
  final void Function(Exercise, TapDownDetails?) onExercise;

  const ExerciseArchive({
    super.key,
    required this.onExercise,
  });

  @override
  Widget build(BuildContext context) {
    final L(:archivedExercises) = L.of(context);
    final archived = Exercises.watch(context).archived.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(archivedExercises),
      ),
      body: ListView.builder(
        itemBuilder: (_, index) {
          final each = archived[index];
          return ExerciseItem(
            exercise: each,
            preferences: Preferences.watch(context),
            selected: false,
            onExerciseSelected: onExercise,
          );
        },
        itemCount: archived.length,
      ),
    );
  }
}
