part of 'exercises.dart';

class _ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final String pushCopy;
  final String pullCopy;
  final String staticCopy;
  final void Function(Exercise)? onExerciseSelected;
  final bool selected;

  const _ExerciseItem({
    required this.exercise,
    required this.pushCopy,
    required this.pullCopy,
    required this.staticCopy,
    required this.selected,
    this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: switch (onExerciseSelected) {
          void Function(Exercise) f => () => f(exercise),
          null => null,
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name),
                      Text(
                        exercise.target,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
