part of 'workout.dart';

class _TemplateCard extends StatelessWidget with HasHaptic<_TemplateCard> {
  final Template template;
  final void Function(Template)? onDelete;
  final void Function(Template)? onEdit;
  final void Function(Template)? onMove;
  final void Function(Template)? onStartWorkout;
  final void Function(Template) onTap;
  final List<_TemplateOption>? options;

  const _TemplateCard({
    required this.template,
    this.onDelete,
    this.onEdit,
    this.onMove,
    this.onStartWorkout,
    this.options,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.bodyMedium?.copyWith(color: colorScheme.outline);
    return Card(
      color: colorScheme.surfaceContainer,
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
      .move => onMove?.call(template),
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
      .move => (
        copy: L.of(context).moveToFolder,
        style: textTheme.titleSmall,
        icon: const Icon(Icons.drive_file_move_outlined, size: 16),
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

enum _TemplateOption { edit, move, startWorkout, delete }

const _shape = RoundedRectangleBorder(borderRadius: .all(.circular(8)));

/// Tiles [_TemplateCard]s to a comfortable reading width instead of a fixed
/// column count.
///
/// A fixed count is what made these cards square: two columns of an iPad in
/// landscape is a 900pt cell holding two lines of text. Deriving the count from
/// the width the grid actually gets means the same code covers a phone, either
/// iPad orientation and a browser window being dragged around.
class _TemplateGrid extends StatelessWidget {
  final List<Template> templates;
  final Widget Function(Template) card;

  const _TemplateGrid({
    required this.templates,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(8),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columnsFor(constraints.crossAxisExtent, maxExtent: _maxCardWidth),
              mainAxisExtent: _cardExtent(context, templates),
            ),
            delegate: SliverChildBuilderDelegate(
              (_, index) => card(templates[index]),
              childCount: templates.length,
            ),
          );
        },
      ),
    );
  }
}

/// [_TemplateGrid] for a box context: what a folder's [ExpansionTile] holds,
/// since tile children cannot be slivers. Same columns, same card height;
/// never a scrollable of its own.
class _TemplateGridBox extends StatelessWidget {
  final List<Template> templates;
  final Widget Function(Template) card;

  const _TemplateGridBox({
    required this.templates,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnsFor(constraints.maxWidth, maxExtent: _maxCardWidth),
            mainAxisExtent: _cardExtent(context, templates),
          ),
          itemCount: templates.length,
          itemBuilder: (_, index) => card(templates[index]),
        );
      },
    );
  }
}

/// Every cell in a grid shares one height, so reserve what the fullest
/// template here needs and no more. Derived from the text metrics rather than
/// hardcoded, because at 200% text scale a fixed height clips the rows.
double _cardExtent(BuildContext context, List<Template> templates) {
  final TextTheme(:titleMedium, :bodyMedium) = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  final longest = templates.fold(0, (longest, t) => max(longest, t.length));
  final listed = min(longest, _maxPerCard);
  final overflow = switch (longest > _maxPerCard) {
    true => 1,
    false => 0,
  };
  // a one-exercise template still gets a card, not a sliver
  final rows = max(_minRowsPerCard, listed + overflow);

  // the title row is as tall as its popup menu button, not its text
  final title = max(_menuButtonHeight, _lineExtent(titleMedium, scaler));
  return title + rows * _lineExtent(bodyMedium, scaler) + _cardMargin + _cardBottomPadding;
}

double _lineExtent(TextStyle? style, TextScaler scaler) {
  return scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.4);
}

/// An [IconButton] at the card's [VisualDensity] of -3.
const _menuButtonHeight = 36.0;

/// [Card]'s default margin, top and bottom.
const _cardMargin = 8.0;

/// Breathing room under the last exercise row, which is otherwise flush with
/// the bottom of the card.
const _cardBottomPadding = 8.0;

/// A card shorter than this reads as a fragment rather than a card, however few
/// exercises the template holds.
const _minRowsPerCard = 2;

const _maxCardWidth = 360.0;
