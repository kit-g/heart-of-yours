part of 'exercises.dart';

class ExerciseItem extends StatelessWidget {
  final Exercise exercise;
  final Preferences preferences;
  final void Function(Exercise, TapDownDetails?)? onExerciseSelected;
  final bool selected;

  const ExerciseItem({
    super.key,
    required this.exercise,
    required this.preferences,
    required this.selected,
    this.onExerciseSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    TapDownDetails? details;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (d) => details = d,
        onTap: switch (onExerciseSelected) {
          void Function(Exercise, TapDownDetails?) f => () => f(exercise, details),
          null => null,
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            spacing: 8,
            children: [
              _Badge(exercise: exercise),
              Expanded(
                flex: 2,
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
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: switch (selected) {
                    true => const Align(
                      alignment: Alignment.centerRight,
                      child: Icon(Icons.check_circle_rounded),
                    ),
                    false => Selector<PreviousExercises, Map<String, dynamic>?>(
                      selector: (_, provider) => provider.last(exercise.name),
                      builder: (_, metric, _) {
                        return switch (metric) {
                          Map<String, dynamic> m => Align(
                            alignment: Alignment.centerRight,
                            child: PreviousSet(
                              previousValue: m,
                              prefs: preferences,
                              exercise: exercise,
                            ),
                          ),
                          null => const SizedBox.shrink(),
                        };
                      },
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
