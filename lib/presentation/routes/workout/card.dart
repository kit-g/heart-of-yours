part of 'workout.dart';

class _TemplateCard extends StatelessWidget with HasHaptic<_TemplateCard> {
  final Template template;
  final void Function(Template)? onDelete;
  final void Function(Template)? onEdit;
  final void Function(Template)? onStartWorkout;
  final void Function(Template) onTap;
  final List<_TemplateOption>? options;

  const _TemplateCard({
    required this.template,
    this.onDelete,
    this.onEdit,
    this.onStartWorkout,
    this.options,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.bodyMedium?.copyWith(color: colorScheme.outline);
    return Card(
      shape: _shape,
      child: InkWell(
        onTap: () {
          buzz();
          onTap(template);
        },
        customBorder: _shape,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Row(
                spacing: 8,
                mainAxisAlignment: .spaceBetween,
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
                    padding: .zero,
                    icon: const Icon(Icons.more_horiz),
                    itemBuilder: (_) {
                      return (options ?? _TemplateOption.values).map(
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
              padding: const .symmetric(horizontal: 8.0),
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
                          ),
                        ],
                      );
                    },
                  ),
                  if (template.length > _maxPerCard)
                    Text(
                      '...',
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSelected(_TemplateOption option) {
    return switch (option) {
      .edit => onEdit?.call(template),
      .delete => onDelete?.call(template),
      .startWorkout => onStartWorkout?.call(template),
    };
  }

  ({String copy, TextStyle? style, Widget icon}) _item(BuildContext context, _TemplateOption option) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return switch (option) {
      .delete => (
        copy: L.of(context).delete,
        style: textTheme.titleSmall?.copyWith(color: colorScheme.error),
        icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
      ),
      .edit => (
        copy: L.of(context).edit,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.edit_rounded, size: 16),
      ),
      .startWorkout => (
        copy: L.of(context).startWorkout,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.fitness_center_rounded, size: 16),
      ),
    };
  }
}

const _maxPerCard = 5;

enum _TemplateOption { edit, startWorkout, delete }

const _shape = RoundedRectangleBorder(borderRadius: .all(.circular(8)));
