part of 'exercises.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;
  final void Function(String) onTapWorkout;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.onTapWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _CupertinoExerciseDetailPage(
          exercise: exercise,
          onTapWorkout: onTapWorkout,
        ),
      _ => _MaterialExerciseDetailPage(
          exercise: exercise,
          onTapWorkout: onTapWorkout,
        ),
    };
  }
}
