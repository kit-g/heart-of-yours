part of 'exercises.dart';

class ExerciseDetailPage extends StatelessWidget {
  final Exercise exercise;
  final Future<void> Function(String) onTapWorkout;
  final void Function(Exercise)? onShareExercise;
  final bool allowOptions;
  final Widget? leading;

  const ExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.onTapWorkout,
    this.allowOptions = true,
    this.leading,
     this.onShareExercise,
  });

  @override
  Widget build(BuildContext context) {
    return switch (Theme.of(context).platform) {
      .iOS || .macOS => _CupertinoExerciseDetailPage(
        exercise: exercise,
        onTapWorkout: onTapWorkout,
        allowOptions: allowOptions,
        leading: leading,
        onShareExercise: onShareExercise,
      ),
      _ => _MaterialExerciseDetailPage(
        exercise: exercise,
        onTapWorkout: onTapWorkout,
        allowOptions: allowOptions,
        leading: leading,
        onShareExercise: onShareExercise,
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
          allowOptions: false,
          leading: IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.close),
          ),
        ),
      );
    },
  );
}
