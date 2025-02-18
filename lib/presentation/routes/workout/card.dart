part of 'workout.dart';

class _TemplateCard extends StatelessWidget {
  final Template template;
  final void Function(Template) onDelete;
  final void Function(Template) onEdit;
  final void Function(Template) onStartWorkout;
  final void Function(Template) onTap;

  const _TemplateCard({
    required this.template,
    required this.onDelete,
    required this.onEdit,
    required this.onStartWorkout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.bodyMedium?.copyWith(color: colorScheme.outline);
    return Card(
      shape: _shape,
      child: InkWell(
        onTap: () => onTap(template),
        customBorder: _shape,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                spacing: 8,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      template.name ?? '',
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<_TemplateOption>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity(vertical: -3, horizontal: -3),
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz),
                    itemBuilder: (_) {
                      return _TemplateOption.values.map(
                        (option) {
                          final (:copy, :style, :icon) = _item(context, option);
                          return PopupMenuItem<_TemplateOption>(
                            onTap: () => _onSelected(option),
                            child: Row(
                              spacing: 4,
                              children: [
                                icon,
                                Text(
                                  copy,
                                  style: style,
                                ),
                              ],
                            ),
                          );
                        },
                      ).toList();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
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
            )
          ],
        ),
      ),
    );
  }

  void _onSelected(_TemplateOption option) {
    return switch (option) {
      _TemplateOption.edit => onEdit(template),
      _TemplateOption.delete => onDelete(template),
      _TemplateOption.startWorkout => onStartWorkout(template),
    };
  }

  ({String copy, TextStyle? style, Widget icon}) _item(BuildContext context, _TemplateOption option) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return switch (option) {
      _TemplateOption.delete => (
          copy: L.of(context).delete,
          style: textTheme.titleSmall?.copyWith(color: colorScheme.error),
          icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
        ),
      _TemplateOption.edit => (
          copy: L.of(context).edit,
          style: textTheme.titleSmall,
          icon: const Icon(Icons.edit_rounded, size: 16),
        ),
      _TemplateOption.startWorkout => (
          copy: L.of(context).startWorkout,
          style: textTheme.titleSmall,
          icon: const Icon(Icons.fitness_center_rounded, size: 16),
        ),
    };
  }
}

const _maxPerCard = 5;

enum _TemplateOption { edit, startWorkout, delete }

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);
