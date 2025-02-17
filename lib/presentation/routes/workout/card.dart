part of 'workout.dart';

class _TemplateCard extends StatelessWidget {
  final Template template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.bodyMedium?.copyWith(color: colorScheme.outline);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.name ?? '',
              style: textTheme.titleMedium,
            ),
            ...template.take(_maxPerCard).map(
              (exercise) {
                return Row(
                  spacing: 8,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          exercise.exercise.name,
                          style: style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Text(
                      '${exercise.length}x',
                      style: style,
                    )
                  ],
                );
              },
            ),
            if (template.length > _maxPerCard)
              Text(
                '...',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              )
          ],
        ),
      ),
    );
  }
}

const _maxPerCard = 5;
