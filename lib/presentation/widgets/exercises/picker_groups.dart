part of 'exercises.dart';

/// Picks how the picker groups the library (#620): a menu of the groupings,
/// the one in force checked, hanging off [anchor] — Settings' row. The
/// Exercises tab's options carry the same choices inline (#710). One choice
/// for every place the picker appears; the others follow it.
Future<void> showPickerGroupingMenu(BuildContext anchor) async {
  const width = 200.0;
  final shown = ShownPickerGrouping.of(Preferences.of(anchor));
  final (:position, :constraints) = menuEndingUnder(anchor, width: width);
  final picked = await showMenu<PickerGrouping>(
    context: anchor,
    position: position,
    constraints: constraints,
    items: shown.items(L.of(anchor), (each) => each),
  );
  if (!anchor.mounted) return;
  if (picked case final PickerGrouping picked) shown.apply(Preferences.of(anchor), picked);
}

/// The grouping a menu of the groupings showed when it opened, and what was
/// stored behind it then: Settings' menu and the Exercises tab's options
/// share both the items and the rule for a pick.
final class ShownPickerGrouping {
  /// The one checked.
  final PickerGrouping grouping;

  /// What was stored when the menu opened; null when nothing was.
  final ScreenChoiceRecord? stored;

  new of(Preferences preferences)
    : grouping = preferences.pickerGrouping,
      stored = preferences.screenChoices[ScreenChoice.pickerGrouping];

  /// The groupings as checked items, [grouping] checked, each answering with
  /// [value] of itself.
  List<CheckedPopupMenuItem<T>> items<T>(L l, T Function(PickerGrouping) value) {
    return [
      for (final each in PickerGrouping.values)
        CheckedPopupMenuItem<T>(
          value: value(each),
          checked: each == grouping,
          child: Text(each.label(l)),
        ),
    ];
  }

  /// Stores [picked] when it is a choice over what the menu showed.
  ///
  /// Another grouping than the checked one always is. The checked one is only
  /// while nothing has been stored since the menu opened: a grouping sync
  /// adopted from another device while the menu was up is newer than what the
  /// user saw, and tapping the checked one must not overwrite it. Otherwise
  /// it goes through too — a newer app's grouping reads as None and shows
  /// None checked, and picking None over it is a choice, which
  /// [Preferences.setPickerGrouping] tells apart from what is stored already.
  void apply(Preferences preferences, PickerGrouping picked) {
    final changedSince = preferences.screenChoices[ScreenChoice.pickerGrouping] != stored;
    if (picked == grouping && changedSince) return;
    preferences.setPickerGrouping(picked);
  }
}

/// One group of a grouped picker: its heading, pinned while its exercises
/// scroll under it, and the exercises when it is open. Folded until opened,
/// and remembered either way on this device.
class _ExerciseGroupSliver extends StatelessWidget {
  final ExerciseGroup group;
  final int count;
  final bool open;

  /// Whose thumbnail the heading wears (#711): [representativeOf] the group.
  final Exercise? picture;
  final Color? backgroundColor;
  final Widget list;

  const new({
    super.key,
    required this.group,
    required this.count,
    required this.open,
    this.picture,
    this.backgroundColor,
    required this.list,
  });

  /// The least a heading is, whatever its text: the picture, as tall as a
  /// row's, with the padding a row gives it.
  static const _minHeight = 56.0;

  /// How much of the accent an open heading's fill carries over the picker's
  /// own. Without it an open heading read as one more row of the exercises
  /// under it (#711). Folded ones keep the plain fill: a screen of them tinted
  /// ran together into one slab, and with nothing under them there is no row
  /// to tell them from.
  static const _tint = .08;

  /// The heading's padding above and below its one line.
  static const _verticalPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    // measured, not fixed: at the largest text sizes one line of the heading
    // is taller than a tap target, and a fixed extent clipped it
    final line = lineExtent(textTheme.titleSmall, MediaQuery.textScalerOf(context));

    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: FixedHeightHeaderDelegate(
            height: math.max(_minHeight, line + 2 * _verticalPadding),
            // blended rather than translucent: rows scroll under a pinned
            // heading, and must not show through it
            backgroundColor: Color.alphaBlend(
              colorScheme.primary.withValues(alpha: open ? _tint : 0),
              backgroundColor ?? colorScheme.surface,
            ),
            padding: .zero,
            child: _GroupHeading(group: group, count: count, open: open, picture: picture),
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
  final Exercise? picture;

  const new({required this.group, required this.count, required this.open, this.picture});

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
                if (picture case final Exercise picture) ExerciseBadge(exercise: picture),
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

/// Fades the list in when the grouping in force changes (#711) — between
/// grouped and ungrouped, from one grouping to another, or into a search,
/// which lists by match whatever the grouping — instead of snapping to the
/// new layout. With reduced motion it snaps, as everything else does.
///
/// A fade in rather than a cross-fade: two whole lists of slivers cannot sit
/// on top of each other in one scroll view, and the old one going at once
/// reads as the list rearranging itself rather than flickering.
class _GroupingTransition extends StatefulWidget {
  final PickerGrouping grouping;
  final Widget child;

  const new({required this.grouping, required this.child});

  @override
  State<_GroupingTransition> createState() => _GroupingTransitionState();
}

class _GroupingTransitionState extends State<_GroupingTransition> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );
  late final _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  @override
  void didUpdateWidget(covariant _GroupingTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grouping == oldWidget.grouping) return;
    switch (lessMotion(context)) {
      case true:
        _controller.value = 1;
      case false:
        _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // the list stays in the semantics tree while it fades in: a reader's
    // focus is not dropped on every change of grouping
    return SliverFadeTransition(opacity: _opacity, alwaysIncludeSemantics: true, sliver: widget.child);
  }
}
