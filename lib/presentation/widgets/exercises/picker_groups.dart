part of 'exercises.dart';

/// Picks how the picker groups the library (#620), beside the filters it
/// works with. One choice for every place the picker appears.
///
/// Filled while a grouping is on, as the movement button is while a movement
/// filter is: the list's shape is the button's doing, and it should say so
/// without being opened.
class const _GroupingButton(final PickerGrouping grouping) extends StatelessWidget {
  static const _menuWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final l = L.of(context);
    final active = grouping != .none;

    return IconButton(
      key: AppKeys.pickerGrouping,
      constraints: const .tightFor(width: 36, height: 36),
      padding: .zero,
      iconSize: 20,
      // names the grouping in force, so a screen reader hears what it is
      tooltip: l.pickerGroupBy(grouping.label(l)),
      icon: Icon(
        active ? Icons.view_agenda_rounded : Icons.view_agenda_outlined,
        color: active ? colorScheme.primary : null,
      ),
      onPressed: () async {
        final picked = await showMenu<PickerGrouping>(
          context: context,
          // this context is the button's own: the menu hangs off its right edge
          position: menuEndingUnder(context, width: _menuWidth),
          constraints: const .tightFor(width: _menuWidth),
          items: [
            for (final each in PickerGrouping.values)
              CheckedPopupMenuItem<PickerGrouping>(
                value: each,
                checked: each == grouping,
                child: Text(each.label(l)),
              ),
          ],
        );
        if (!context.mounted) return;
        if (picked case final PickerGrouping picked when picked != grouping) {
          Preferences.of(context).setPickerGrouping(picked);
        }
      },
    );
  }
}

/// One group of a grouped picker: its heading, pinned while its exercises
/// scroll under it, and the exercises when it is open. Folded until opened,
/// and remembered either way on this device.
class _ExerciseGroupSliver extends StatelessWidget {
  final ExerciseGroup group;
  final int count;
  final bool open;
  final Color? backgroundColor;
  final Widget list;

  const new({
    super.key,
    required this.group,
    required this.count,
    required this.open,
    required this.backgroundColor,
    required this.list,
  });

  /// A tap target's height: the least a heading is, whatever its text.
  static const _minHeight = 48.0;

  /// The heading's padding above and below its one line.
  static const _verticalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    // measured, not fixed: at the largest text sizes one line of the heading
    // is taller than a tap target, and a fixed extent clipped it
    final line = _lineExtent(textTheme.titleSmall, MediaQuery.textScalerOf(context));

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: FixedHeightHeaderDelegate(
            height: math.max(_minHeight, line + 2 * _verticalPadding),
            backgroundColor: backgroundColor ?? colorScheme.surface,
            padding: .zero,
            child: _GroupHeading(group: group, count: count, open: open),
          ),
        ),
        if (open) list,
      ],
    );
  }
}

/// One line of [style] at [scaler]'s size, as workout/card.dart measures its
/// rows.
double _lineExtent(TextStyle? style, TextScaler scaler) {
  return scaler.scale(style?.fontSize ?? 14) * (style?.height ?? 1.4);
}

class _GroupHeading extends StatelessWidget {
  final ExerciseGroup group;
  final int count;
  final bool open;

  const new({required this.group, required this.count, required this.open});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final label = group.label(l);

    void toggle() {
      // folding from a pinned heading would leave the list where it was —
      // somewhere in the groups below — and the heading gone from under the
      // finger; the list goes back to where the group starts
      if (open) _revealStart(context);
      Preferences.of(context).togglePickerGroup(group.id);
    }

    // The state goes out as copy rather than as the `expanded` flag: the flag
    // is announced in the platform's words, where it is announced at all, and
    // a heading that says it is folded has to say so in the app's language.
    return Semantics(
      container: true,
      header: true,
      button: true,
      label: l.pickerGroupHeading(label, count),
      value: open ? l.pickerGroupExpanded : l.pickerGroupCollapsed,
      onTapHint: open ? l.pickerGroupCollapse : l.pickerGroupExpand,
      onTap: toggle,
      excludeSemantics: true,
      // the header's fill is opaque: without a surface of its own the ripple
      // and the focus highlight would be painted under it
      child: Material(
        type: .transparency,
        child: InkWell(
          onTap: toggle,
          child: Padding(
            padding: const .symmetric(horizontal: 16),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: textTheme.titleSmall,
                  ),
                ),
                Text(
                  '$count',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                AnimatedRotation(
                  turns: open ? 0 : -0.25,
                  duration: lessMotion(context) ? Duration.zero : const Duration(milliseconds: 150),
                  child: Icon(Icons.expand_more_rounded, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Scrolls back to where the group around [context] starts, just under the
  /// headers pinned above it, when the list is past that point — the heading
  /// is pinned then. The group's own constraints say how far: what of it has
  /// scrolled off the top, and what the pinned headers cover. Nothing above
  /// the group changes when it folds, so the offset measured now holds after.
  static void _revealStart(BuildContext context) {
    final group = context.findAncestorRenderObjectOfType<RenderSliverMainAxisGroup>();
    final position = Scrollable.maybeOf(context)?.position;
    if (group == null || position == null) return;
    final SliverConstraints(:scrollOffset, :overlap) = group.constraints;
    final start = math.max(0.0, position.pixels - scrollOffset - overlap);
    if (start < position.pixels) position.jumpTo(start);
  }
}
