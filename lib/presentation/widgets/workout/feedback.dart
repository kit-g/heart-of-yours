part of 'workout_detail.dart';

class _Feedback extends StatelessWidget {
  const new({
    required this.exercise,
    required this.textTheme,
  });

  final String exercise;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 8.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width - 16,
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          // no shadow: a border keeps the drag proxy defined over content
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 8.0, vertical: 4),
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
