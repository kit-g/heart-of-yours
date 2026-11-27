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

/// A template History can be narrowed to (#740): its name, the program it is
/// a session of, while that is shown, and else the folder it is filed under,
/// which tell two of one name apart.
typedef _FilterTemplate = ({String id, String name, Program? program, String? folder});

/// Whether [templates] still holds [id], a sample only with Example templates
/// on ([samples]), as they are named nowhere with it off.
bool _isHere(Templates templates, String id, {required bool samples}) {
  return switch (templates.lookup(id)) {
    final Template template => samples || !templates.samples.contains(template),
    null => false,
  };
}

/// [program] by its name; runs of one, [among] the rest, by when each began
/// too: the month, or the day where that is the same.
String _programName(L l, Program program, Iterable<Program> among) {
  final began = program.createdAt?.toLocal();
  if (began == null) return program.name;
  final month = DateFormat.yMMM(l.localeName);
  final alike = among.where((other) => other.name == program.name && other.id != program.id);
  if (alike.isEmpty) return program.name;
  final months = {
    for (final other in alike)
      if (other.createdAt case final DateTime at) month.format(at.toLocal()),
  };
  final when = months.contains(month.format(began)) ? DateFormat.yMMMd(l.localeName) : month;
  return '${program.name} · ${when.format(began)}';
}

/// [template] by its name, [among] the rest: with its folder's, where another
/// plain one has the same.
String _templateName(_FilterTemplate template, Iterable<_FilterTemplate> among) {
  final alike = among.any(
    (other) => other.program == null && other.name == template.name && other.id != template.id,
  );
  return switch ((alike, template.folder)) {
    (true, final String folder) => '${template.name} · $folder',
    _ => template.name,
  };
}

/// The templates to offer (#740): the user's own and the sessions of a
/// program still going, whether or not anything was trained from them, and
/// any other this device knows that the history names — a finished program's
/// session, a sample (an account's workout keeps no link to one once it is
/// saved: the server links only the account's own). A session whose program isn't shown (Programs off) is a
/// plain template, as it is on the Workout tab. One since deleted has no name
/// left, and is not guessed one from its workouts. Plain templates first, then
/// each program's sessions together.
List<_FilterTemplate> _filterTemplates(BuildContext context) {
  final templates = Templates.of(context);
  final programs = Programs.of(context);
  final preferences = Preferences.of(context);
  final trained = {for (final workout in Workouts.of(context).history) ?workout.templateId};
  final live = {for (final program in programs.following) program.id};

  Program? shown(Template template) => switch (template.programId) {
    final String id when preferences.programShown(programs.lookup(id)) => programs.lookup(id),
    _ => null,
  };
  bool offered(Template template) => switch (shown(template)) {
    final Program program => live.contains(program.id) || trained.contains(template.id),
    null => true,
  };
  final entries = [
    for (final template in [
      ...templates.where(offered),
      if (preferences.isOn(.sampleTemplates)) ...templates.samples.where((sample) => trained.contains(sample.id)),
    ])
      if (template.name case final String name when name.trim().isNotEmpty)
        (id: template.id, name: name, program: shown(template), folder: template.folder?.name),
  ];
  return [
    ...entries.where((entry) => entry.program == null),
    for (final id in {for (final entry in entries) ?entry.program?.id})
      ...entries.where((entry) => entry.program?.id == id),
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
    final used = _usedTemplates(context);
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
          // no template to pick, no way to them
          if (axis != .templates || templates.any((each) => _opens(each.id, used)))
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
        await _chooseTemplate(context, templates, used);
      // ticked, it is taken out, as a group is
      case _FilterAxis.from when filter.from != null:
        filter.from = null;
      case _FilterAxis.until when filter.until != null:
        filter.until = null;
      case _FilterAxis.from:
        final day = await _pickDay(context, last: filter.until, title: l.historyFilterFrom);
        if (day != null) filter.from = day;
      case _FilterAxis.until:
        final day = await _pickDay(context, first: filter.from, title: l.historyFilterUntil);
        if (day != null) filter.until = day;
    }
  }

  /// The templates the history names, once all of it is here; null before.
  Set<String>? _usedTemplates(BuildContext context) => switch (whole) {
    true => {for (final workout in Workouts.of(context).history) ?workout.templateId},
    false => null,
  };

  bool _opens(String id, Set<String>? used) => filter.templates.contains(id) || (used?.contains(id) ?? true);

  /// Picks one end of the stretch, never past the other: a day of the history,
  /// as far back as it is known to go, up to today.
  Future<DateTime?> _pickDay(
    BuildContext context, {
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
      initialDate: end,
      firstDate: start.isAfter(end) ? end : start,
      lastDate: end,
      title: title,
    );
  }

  Future<void> _chooseTemplate(BuildContext context, List<_FilterTemplate> templates, Set<String>? used) async {
    final l = L.of(context);
    final programs = {for (final template in templates) ?template.program?.id};
    final among = templates.map((each) => each.program).nonNulls;
    PopupMenuEntry<String> item(_FilterTemplate template) => CheckedPopupMenuItem<String>(
      key: AppKeys.historyFilterTemplate(template.id),
      value: template.id,
      checked: filter.templates.contains(template.id),
      enabled: _opens(template.id, used),
      child: Text(template.program == null ? _templateName(template, templates) : template.name),
    );
    final picked = await showMenu<String>(
      context: context,
      position: menuOver(context, context.findRenderObject()! as RenderBox),
      items: [
        ...templates.where((each) => each.program == null).map(item),
        for (final id in programs) ...[
          MenuHeading<String>(_programName(l, among.firstWhere((each) => each.id == id), among)),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // the longest still leaves its × on screen
        final widest = math.max(_shortest, constraints.maxWidth - _aroundLabel);
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
                  maxLabelWidth: widest,
                  onDeleted: () => filter.from = null,
                ),
              if (filter.until case final DateTime until)
                RemovableChip(
                  key: AppKeys.historyFilterUntilChip,
                  label: l.historyFilterUntilDay(days.format(until)),
                  maxLabelWidth: widest,
                  onDeleted: () => filter.until = null,
                ),
              if (filter.templates.isNotEmpty) ..._templates(context, l, widest),
              for (final group in _groupOrder.where(filter.groups.contains))
                RemovableChip(
                  avatar: Center(child: FamilyDot(MuscleFamily.of(group))),
                  label: group.label(l),
                  onDeleted: () => filter.remove(group),
                ),
            ],
          ),
        );
      },
    );
  }

  /// The page's gutters, the chip's own, and its ×.
  static const _aroundLabel = 32.0 + 56.0;
  static const _shortest = 64.0;

  /// Named as the menu names them, over the same templates.
  Iterable<Widget> _templates(BuildContext context, L l, double widest) {
    // what the names are read from
    final templates = Templates.watch(context);
    Programs.watch(context);
    Preferences.watch(context);
    final offered = _filterTemplates(context);
    final among = offered.map((each) => each.program).nonNulls;
    String label(String id) => switch (offered.where((each) => each.id == id).firstOrNull) {
      (:final name, program: final Program program, id: _, folder: _) => '$name · ${_programName(l, program, among)}',
      final _FilterTemplate plain => _templateName(plain, offered),
      // its name emptied since it was picked
      null => templates.lookup(id)?.name ?? l.defaultWorkoutName(),
    };

    return filter.templates.map(
      (id) => RemovableChip(
        key: AppKeys.historyFilterTemplateChip(id),
        label: label(id),
        maxLabelWidth: widest,
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
