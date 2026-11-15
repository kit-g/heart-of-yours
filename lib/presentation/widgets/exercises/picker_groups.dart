part of 'exercises.dart';

/// Picks how the picker groups the library (#620), beside the filters it
/// works with. One choice for every place the picker appears.
///
/// Filled while a grouping is on, as the movement button is while a movement
/// filter is: the list's shape is the button's doing, and it should say so
/// without being opened.
class _GroupingButton extends StatelessWidget {
  new();

  final _key = GlobalKey();

  static const _menuWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final l = L.of(context);
    return Selector<Preferences, PickerGrouping>(
      selector: (_, preferences) => preferences.pickerGrouping,
      builder: (context, grouping, _) {
        final active = grouping != .none;

        return IconButton(
          key: AppKeys.pickerGrouping,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: .zero,
          iconSize: 20,
          tooltip: l.pickerGroupBy,
          icon: Icon(
            active ? Icons.view_agenda_rounded : Icons.view_agenda_outlined,
            key: _key,
            color: active ? colorScheme.primary : null,
          ),
          onPressed: () async {
            final picked = await showMenu<PickerGrouping>(
              context: context,
              position: menuUnderValue(context, _key, width: _menuWidth),
              constraints: const BoxConstraints.tightFor(width: _menuWidth),
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

  /// A tap target's height, and what the heading's one line needs at the
  /// largest text the picker is read at.
  static const _height = 48.0;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: FixedHeightHeaderDelegate(
            height: _height,
            backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
            padding: .zero,
            child: _GroupHeading(group: group, count: count, open: open),
          ),
        ),
        if (open) list,
      ],
    );
  }
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
    void toggle() => Preferences.of(context).togglePickerGroup(group.id);

    // The state goes out as copy rather than as the `expanded` flag: the flag
    // is announced in the platform's words, where it is announced at all, and
    // a heading that says it is folded has to say so in the app's language.
    return Semantics(
      container: true,
      header: true,
      button: true,
      label: label,
      value: open ? l.pickerGroupExpanded : l.pickerGroupCollapsed,
      onTapHint: open ? l.pickerGroupCollapse : l.pickerGroupExpand,
      onTap: toggle,
      excludeSemantics: true,
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
    );
  }
}
