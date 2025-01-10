part of 'exercises.dart';

class _DirectionBadge extends StatelessWidget {
  final ExerciseDirection direction;
  final String pushCopy;
  final String pullCopy;
  final String staticCopy;

  const _DirectionBadge({
    required this.direction,
    required this.pullCopy,
    required this.pushCopy,
    required this.staticCopy,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);

    return switch (direction) {
      ExerciseDirection.push => Tooltip(
          message: pushCopy,
          child: Icon(
            Icons.arrow_circle_right_outlined,
            color: colorScheme.tertiary,
            size: 20,
          ),
        ),
      ExerciseDirection.pull => Tooltip(
          message: pullCopy,
          child: Icon(
            Icons.arrow_circle_left_outlined,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
        ),
      ExerciseDirection.static => Tooltip(
          message: staticCopy,
          child: Icon(
            Icons.arrow_circle_down,
            color: colorScheme.onSurface,
            size: 20,
          ),
        ),
      ExerciseDirection.other => const SizedBox.shrink(),
    };
  }
}
