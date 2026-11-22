part of 'history.dart';

/// Where [group] sits head to foot: the order of the filter's menu and chips
/// (#610), whatever order they were picked in, and of a compact card's line
/// (#611). A switch, so a group heart_models adds cannot go unplaced.
int _headToFoot(MuscleGroupKey group) {
  return switch (group) {
    .neck => 0,
    .chest => 1,
    .back => 2,
    .shoulders => 3,
    .arms => 4,
    .core => 5,
    .glutes => 6,
    .legs => 7,
    .hamstrings => 8,
    .adductors => 9,
  };
}

/// [groups] head to foot.
List<MuscleGroupKey> _inBodyOrder(Iterable<MuscleGroupKey> groups) {
  return [...groups]..sort((one, two) => _headToFoot(one).compareTo(_headToFoot(two)));
}

/// Every group, head to foot.
final _groupOrder = _inBodyOrder(MuscleGroupKey.values);

/// What History's filter menu offers besides the muscle groups (#740).
enum _FilterAxis {
  from,
  until,
  templates;

  String label(L l) => switch (this) {
    .from => l.historyFilterFrom,
    .until => l.historyFilterUntil,
    .templates => l.historyFilterTemplates,
  };
}

/// A template History can be narrowed to (#740): its name, and the program it
/// is a session of, which tells two sessions of one name apart.
typedef _FilterTemplate = ({String id, String name, Program? program});

/// [program] by its name; two runs of one, [among] the rest, by when each
/// began too.
String _programName(L l, Program program, Iterable<Program> among) {
  final alike = among.any((other) => other.name == program.name && other.id != program.id);
  return switch ((alike, program.createdAt)) {
    (true, final DateTime began) => '${program.name} · ${DateFormat.yMMM(l.localeName).format(began.toLocal())}',
    _ => program.name,
  };
}

/// The templates to offer (#740): the user's own and the sessions of a
/// program still going, whether or not anything was trained from them, and
/// any other this device knows that the history names — a finished program's
/// session, a sample. One since deleted has no name left, and is not guessed
/// one from its workouts. Plain templates first, then each program's sessions
/// together.
List<_FilterTemplate> _filterTemplates(BuildContext context) {
  final templates = Templates.of(context);
  final programs = Programs.of(context);
  final preferences = Preferences.of(context);
  final trained = {for (final workout in Workouts.of(context).history) ?workout.templateId};
  final live = {for (final program in programs.following) program.id};

  // a session with its program put away (Programs off) is not offered, as the
  // program itself is shown nowhere
  bool offered(Template template) => switch (template.programId) {
    final String id =>
      preferences.programShown(programs.lookup(id)) && (live.contains(id) || trained.contains(template.id)),
    null => true,
  };
  final known = [
    ...templates.where(offered),
    ...templates.samples.where((sample) => trained.contains(sample.id)),
  ];
  final entries = [
    for (final template in known)
      if (template.name case final String name when name.trim().isNotEmpty)
        (
          id: template.id,
          name: name,
          program: switch (template.programId) {
            final String id => programs.lookup(id),
            null => null,
          },
        ),
  ];
  final sessions = <String?, List<_FilterTemplate>>{};
  for (final entry in entries) {
    (sessions[entry.program?.id] ??= []).add(entry);
  }
  return [
    ...?sessions[null],
    for (final MapEntry(:key, :value) in sessions.entries)
      if (key != null) ...value,
  ];
}

/// Narrows History to some workouts: those that trained some muscle groups
/// (#610), were started from some templates, or fall in a stretch of days
/// (#740). A menu of the groups, each one ticked while it is in the filter,
/// under the ways to the other two. Filled while any is on.
///
/// Once the whole history is on the device ([whole]), a group or a template
/// none of it trained is greyed: picking it could only empty the page. One
/// already in the filter stays live, so it can always be taken out.
class _FilterButton extends StatelessWidget {
  final HistoryFilter filter;
  final WorkoutGroups trained;
  final bool whole;

  /// Whether the library's tags are read, which place a workout's groups.
  final bool tagged;

  const new({required this.filter, required this.trained, required this.whole, required this.tagged});

  Future<void> _choose(BuildContext context) async {
    final l = L.of(context);
    final reached = switch (whole && tagged) {
      true => {for (final workout in Workouts.of(context).history) ...trained.of(workout)},
      false => null,
    };
    final templates = _filterTemplates(context);
    bool open(MuscleGroupKey group) => filter.groups.contains(group) || (reached?.contains(group) ?? true);
    bool isOn(_FilterAxis axis) => switch (axis) {
      .from => filter.from != null,
      .until => filter.until != null,
      .templates => filter.templates.isNotEmpty,
    };
    final picked = await showMenu<Object>(
      context: context,
      position: menuOver(context, context.findRenderObject()! as RenderBox),
      items: [
        for (final axis in _FilterAxis.values)
          // no templates, no way to them
          if (axis != .templates || templates.isNotEmpty)
            CheckedPopupMenuItem<_FilterAxis>(
              key: AppKeys.historyFilterAxis(axis.name),
              value: axis,
              checked: isOn(axis),
              child: Text(axis.label(l)),
            ),
        const PopupMenuDivider(),
        for (final group in _groupOrder)
          CheckedPopupMenuItem<MuscleGroupKey>(
            key: AppKeys.historyFilterGroup(group.value),
            value: group,
            checked: filter.groups.contains(group),
            enabled: open(group),
            child: Row(
              spacing: 8,
              children: [
                FamilyDot(MuscleFamily.of(group), enabled: open(group)),
                // wraps at large text rather than overflow the menu's width
                Flexible(child: Text(group.label(l))),
              ],
            ),
          ),
      ],
    );
    if (!context.mounted) return;
    switch (picked) {
      case final MuscleGroupKey group:
        filter.toggle(group);
      case _FilterAxis.templates:
        await _chooseTemplate(context, templates);
      case _FilterAxis.from:
        final day = await _pickDay(context, filter.from, last: filter.until, title: l.historyFilterFrom);
        if (day != null) filter.from = day;
      case _FilterAxis.until:
        final day = await _pickDay(context, filter.until, first: filter.from, title: l.historyFilterUntil);
        if (day != null) filter.until = day;
    }
  }

  /// Picks one end of the stretch, never past the other: a day of the history,
  /// as far back as it is known to go, up to today.
  Future<DateTime?> _pickDay(
    BuildContext context,
    DateTime? held, {
    DateTime? first,
    DateTime? last,
    required String title,
  }) {
    final today = DateUtils.dateOnly(clock.now());
    final days = Workouts.of(context).history.map((workout) => DateUtils.dateOnly(workout.start.toLocal()));
    final oldest = switch (whole) {
      true => days.fold(today, (oldest, day) => day.isBefore(oldest) ? day : oldest),
      // what isn't here yet may be from any day
      false => DateTime(2000),
    };
    final end = last ?? today;
    final start = first ?? oldest;
    return showAdaptiveDatePicker(
      context,
      initialDate: held ?? end,
      firstDate: start.isAfter(end) ? end : start,
      lastDate: end,
      title: title,
    );
  }

  Future<void> _chooseTemplate(BuildContext context, List<_FilterTemplate> templates) async {
    final l = L.of(context);
    final theme = Theme.of(context);
    final used = switch (whole) {
      true => {for (final workout in Workouts.of(context).history) ?workout.templateId},
      false => null,
    };
    bool open(String id) => filter.templates.contains(id) || (used?.contains(id) ?? true);
    final programs = {for (final template in templates) ?template.program?.id};
    final among = templates.map((each) => each.program).nonNulls;
    PopupMenuEntry<String> item(_FilterTemplate template) => CheckedPopupMenuItem<String>(
      key: AppKeys.historyFilterTemplate(template.id),
      value: template.id,
      checked: filter.templates.contains(template.id),
      enabled: open(template.id),
      child: Text(template.name),
    );
    final picked = await showMenu<String>(
      context: context,
      position: menuOver(context, context.findRenderObject()! as RenderBox),
      items: [
        ...templates.where((each) => each.program == null).map(item),
        for (final id in programs) ...[
          PopupMenuItem<String>(
            enabled: false,
            height: 36,
            child: Text(
              _programName(l, among.firstWhere((each) => each.id == id), among),
              // a heading, not a choice greyed out
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ...templates.where((each) => each.program?.id == id).map(item),
        ],
      ],
    );
    if (picked != null) filter.toggleTemplate(picked);
  }

  @override
  Widget build(BuildContext context) {
    // in the leading slot, which Material inks in onSurface, but one of the
    // header's actions in look, which it inks in onSurfaceVariant
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return IconButton(
      key: AppKeys.historyFilter,
      tooltip: L.of(context).historyFilterTooltip,
      isSelected: filter.isOn,
      icon: Icon(Icons.filter_alt_outlined, color: color),
      selectedIcon: Icon(Icons.filter_alt_rounded, color: color),
      onPressed: () => _choose(context),
    );
  }
}

/// What History is filtered by (#610, #740), each taken out by its ×: the
/// days, the templates, then the groups.
class _FilterChips extends StatelessWidget {
  final HistoryFilter filter;

  const new({required this.filter});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final days = DateFormat.yMMMd(l.localeName);
    return SingleChildScrollView(
      key: AppKeys.historyFilterChips,
      scrollDirection: .horizontal,
      padding: const .fromLTRB(16, 4, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          if (filter.from case final DateTime from)
            RemovableChip(
              key: AppKeys.historyFilterFromChip,
              label: l.historyFilterFromDay(days.format(from)),
              onDeleted: () => filter.from = null,
            ),
          if (filter.until case final DateTime until)
            RemovableChip(
              key: AppKeys.historyFilterUntilChip,
              label: l.historyFilterUntilDay(days.format(until)),
              onDeleted: () => filter.until = null,
            ),
          if (filter.templates.isNotEmpty) ..._templates(context, l),
          for (final group in _groupOrder.where(filter.groups.contains))
            RemovableChip(
              avatar: Center(child: FamilyDot(MuscleFamily.of(group))),
              label: group.label(l),
              onDeleted: () => filter.remove(group),
            ),
        ],
      ),
    );
  }

  Iterable<Widget> _templates(BuildContext context, L l) {
    final templates = Templates.watch(context);
    final programs = Programs.watch(context);
    final preferences = Preferences.watch(context);
    Program? programOf(Template? template) => switch (template?.programId) {
      final String id => programs.lookup(id),
      null => null,
    };
    String label(String id) {
      final template = templates.lookup(id);
      final program = switch (programOf(template)) {
        final Program program when preferences.programShown(program) => program,
        _ => null,
      };
      return switch ((template?.name, program)) {
        (final String name, final Program program) when name.trim().isNotEmpty =>
          '$name · ${_programName(l, program, templates.map(programOf).nonNulls)}',
        (final String name, null) when name.trim().isNotEmpty => name,
        // deleted since it was picked: still taken out here
        _ => l.historyFilterTemplateGone,
      };
    }

    return filter.templates.map(
      (id) => RemovableChip(
        key: AppKeys.historyFilterTemplateChip(id),
        label: label(id),
        onDeleted: () => filter.removeTemplate(id),
      ),
    );
  }
}

/// The filter found nothing, in all of the history it looks at (#610).
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
