part of 'history.dart';

/// The groups History filters by (#610), head to foot: the order of the menu
/// and of the chips, whatever order they were picked in.
const _filterGroups = <MuscleGroupKey>[
  .chest,
  .back,
  .shoulders,
  .arms,
  .core,
  .legs,
  .glutes,
  .hamstrings,
  .adductors,
  .neck,
];

/// Narrows History to workouts that trained some muscle groups (#610): a menu
/// of the groups, each one ticked while it is in the filter. Filled while any
/// is.
///
/// Once the whole history is on the device, a group none of it trained is
/// greyed: picking it could only empty the page. One already in the filter
/// stays live, so it can always be taken out.
class _FilterButton extends StatelessWidget {
  final HistoryFilter filter;
  final Exercise? Function(ExerciseId) lookup;

  const new({required this.filter, required this.lookup});

  Future<void> _choose(BuildContext context) async {
    final l = L.of(context);
    final workouts = Workouts.of(context);
    final trained = switch (workouts.hasMoreHistory) {
      false => {for (final workout in workouts.history) ...workoutGroupsOf(workout, lookup: lookup)},
      true => null,
    };
    final picked = await showMenu<MuscleGroupKey>(
      context: context,
      position: menuOver(context, context.findRenderObject()! as RenderBox),
      items: [
        for (final group in _filterGroups)
          CheckedPopupMenuItem<MuscleGroupKey>(
            key: AppKeys.historyFilterGroup(group.value),
            value: group,
            checked: filter.groups.contains(group),
            enabled: filter.groups.contains(group) || (trained?.contains(group) ?? true),
            child: Text(group.label(l)),
          ),
      ],
    );
    if (picked case final MuscleGroupKey group) filter.toggle(group);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: AppKeys.historyFilter,
      tooltip: L.of(context).historyFilterTooltip,
      isSelected: filter.isOn,
      icon: const Icon(Icons.filter_alt_outlined),
      selectedIcon: const Icon(Icons.filter_alt_rounded),
      onPressed: () => _choose(context),
    );
  }
}

/// The groups History is filtered by (#610), each taken out by its ×.
class _FilterChips extends StatelessWidget {
  final HistoryFilter filter;

  const new({required this.filter});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    return SingleChildScrollView(
      key: AppKeys.historyFilterChips,
      scrollDirection: .horizontal,
      padding: const .fromLTRB(16, 4, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final group in _filterGroups.where(filter.groups.contains))
            Chip(
              deleteButtonTooltipMessage: l.removeFilter,
              labelPadding: .zero,
              label: Padding(
                padding: const .symmetric(horizontal: 4),
                child: Text(group.label(l), style: textTheme.bodyMedium),
              ),
              visualDensity: const VisualDensity(vertical: -4),
              onDeleted: () => filter.remove(group),
            ),
        ],
      ),
    );
  }
}

/// The filter found nothing, in the whole history (#610).
class _FilteredEmpty extends StatelessWidget {
  final VoidCallback onClear;

  const new({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final L(:historyFilterEmptyTitle, :historyFilterEmptyBody, :historyFilterClear) = L.of(context);
    return _Placeholder(
      key: AppKeys.historyFilterEmpty,
      title: historyFilterEmptyTitle,
      body: historyFilterEmptyBody,
      action: OutlinedButton(
        key: AppKeys.historyFilterClear,
        onPressed: onClear,
        child: Text(historyFilterClear),
      ),
    );
  }
}

/// The filter has found nothing yet, and older workouts are still being
/// paged in to look through (#610).
class _Searching extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Center(
      child: Padding(
        padding: const .all(16),
        child: Column(
          mainAxisSize: .min,
          spacing: 12,
          children: [
            const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Text(
              L.of(context).historyFilterSearching,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: .center,
            ),
          ],
        ),
      ),
    );
  }
}
