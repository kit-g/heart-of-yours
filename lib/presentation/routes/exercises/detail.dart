part of 'exercises.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.onTapWorkout,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      .iOS || .macOS => _CupertinoExerciseDetailPage(
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

Future<void> showExerciseDetailDialog(BuildContext context, Exercise exercise) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExerciseDetailPage(
          exercise: exercise,
          onTapWorkout: (_) async {},
        ),
      );
    },
  );
}
