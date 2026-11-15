part of 'exercises.dart';

class ExerciseArchive extends StatelessWidget {
  final void Function(Exercise, TapDownDetails?) onExercise;

  const new({
    super.key,
    required this.onExercise,
  });

  @override
  Widget build(BuildContext context) {
    final L(:archivedExercises) = L.of(context);
    final archived = Exercises.watch(context).archived.toList();
    final preferences = Preferences.watch(context);
    final goEasy = goEasyOn(context);
    return Scaffold(
      appBar: AppBar(
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
            onExerciseSelected: onExercise,
          );
        },
        itemCount: archived.length,
      ),
    );
  }
}
