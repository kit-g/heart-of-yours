part of 'active_workout.dart';

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.exercise,
    required this.textTheme,
  });

  final String exercise;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 16,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          elevation: 3,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    exercise,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
