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
    final style = Theme.of(context).textTheme.bodySmall;
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
            spacing: 8,
            children: [
              _Badge(exercise: exercise),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name),
                      Row(
                        children: [
                          Text(
                            exercise.target.value,
                            style: style,
                          ),
                          Text(
                            ' - ',
                            style: style,
                          ),
                          Text(
                            exercise.category.value,
                            style: style,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: switch (selected) {
                  true => const Icon(Icons.check_circle_rounded),
                  false => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
