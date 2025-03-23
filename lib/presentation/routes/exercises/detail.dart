part of 'exercises.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _CupertinoExerciseDetailPage(exercise: exercise),
      _ => _MaterialExerciseDetailPage(exercise: exercise),
    };
  }
}
