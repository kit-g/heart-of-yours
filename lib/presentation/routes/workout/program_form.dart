part of 'workout.dart';

/// One screen from a folder to a running program (#348), and the same screen
/// for changing a program's own fields later: its name, how many times a week,
/// the days it would rather fall on, and how long it runs.
///
/// From a folder, the folder's templates become the program's sessions in
/// their order. They stay where they are, in the folder, as they were: a
/// session is a template carrying the program's id, so nothing is copied and
/// nothing counts against the template allowance twice.
///
/// New or an edit is the route's to say, never what has loaded: a program or
/// folder not there yet, or not anymore, is a bare page, as [ProgramPage] is,
/// and nothing on it can make a program.
class ProgramFormPage extends StatelessWidget {
  /// The folder a new program is made from.
  final String? folderId;

  /// The program being changed.
  final String? programId;

  /// Leaves the page once the program is saved.
  final VoidCallback onDone;

  const new fromFolder({super.key, required String this.folderId, required this.onDone}) : programId = null;

  const new edit({super.key, required String this.programId, required this.onDone}) : folderId = null;

  @override
  Widget build(BuildContext context) {
    final form = switch ((programId, folderId)) {
      (final String id, _) => switch (Programs.watch(context).lookup(id)) {
        final Program program => _ProgramForm(key: ValueKey(id), program: program, onDone: onDone),
        null => null,
      },
      (null, final String id) => switch (Templates.watch(context).folders.where((each) => each.id == id).firstOrNull) {
        final TemplateFolder folder => _ProgramForm(key: ValueKey(id), folder: folder, onDone: onDone),
        null => null,
      },
      (null, null) => null,
    };
    return form ?? Scaffold(appBar: AppBar());
  }
}

/// The form itself, for [program] or a new one from [folder]: its fields
/// start from what they were when it opened, and a save puts them on the
/// program as it is by then.
class _ProgramForm extends StatefulWidget {
  final Program? program;
  final TemplateFolder? folder;
  final VoidCallback onDone;

  const new({super.key, this.program, this.folder, required this.onDone});

  @override
  State<_ProgramForm> createState() => _ProgramFormState();
}

class _ProgramFormState extends State<_ProgramForm> {
  late final TextEditingController _name;

  /// 0 is no target.
  late final ValueNotifier<int> _perWeek;
  late final ValueNotifier<Set<int>> _days;

  /// Whether the program runs for [_weeks], or on.
  late final ValueNotifier<bool> _fixed;
  late final ValueNotifier<int> _weeks;
  final _saving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    final _ProgramForm(:program, :folder) = widget;
    final sessions = switch (folder) {
      final TemplateFolder folder => Templates.of(context).templatesIn(folder).length,
      null => 0,
    };

    _name = TextEditingController(text: program?.name ?? folder?.name ?? '');
    _days = ValueNotifier({...?program?.days});
    _weeks = ValueNotifier(program?.weeks ?? _defaultWeeks);
    switch (program) {
      case final Program program:
        _perWeek = ValueNotifier(program.perWeek ?? 0);
        _fixed = ValueNotifier(program.weeks != null);
      case null:
        // a folder of three templates reads as three a week until the user
        // says otherwise; a week has seven days to put them in
        _perWeek = ValueNotifier(sessions.clamp(1, 7));
        _fixed = ValueNotifier(true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _perWeek.dispose();
    _days.dispose();
    _fixed.dispose();
    _weeks.dispose();
    _saving.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final label = textTheme.titleSmall;
    final isNew = widget.program == null;
    final sessions = switch (widget.folder) {
      final TemplateFolder folder => Templates.watch(context).templatesIn(folder).toList(),
      null => const <Template>[],
    };

    return _ProgramsOnly(
      child: Scaffold(
        appBar: AppBar(title: Text(isNew ? copy.newProgram : copy.editProgram)),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: .topCenter,
                child: SizedBox(
                  width: min(constraints.maxWidth, readableWidth),
                  child: ListView(
                    padding: const .all(16),
                    children: [
                      TextField(
                        controller: _name,
                        textCapitalization: .sentences,
                        maxLength: _maxName,
                        decoration: InputDecoration(labelText: copy.programName, counterText: ''),
                      ),
                      if (sessions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(copy.programSessions, style: label),
                        const SizedBox(height: 4),
                        ...sessions.indexed.map(
                          (each) => Padding(
                            padding: const .symmetric(vertical: 2),
                            child: Text(
                              '${each.$1 + 1}. ${_sessionName(copy, each.$2)}',
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ValueListenableBuilder(
                        valueListenable: _perWeek,
                        builder: (_, perWeek, _) {
                          return _NumberRow(
                            label: copy.programPerWeek,
                            value: perWeek == 0 ? copy.programNoTarget : '$perWeek',
                            onFewer: perWeek > 0 ? () => _perWeek.value-- : null,
                            onMore: perWeek < _maxPerWeek ? () => _perWeek.value++ : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(copy.programDays, style: label),
                      const SizedBox(height: 8),
                      ValueListenableBuilder(
                        valueListenable: _days,
                        builder: (_, days, _) => _DayToggles(days: days, onToggle: _toggleDay),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder(
                        valueListenable: _fixed,
                        builder: (_, fixed, _) {
                          return Column(
                            crossAxisAlignment: .stretch,
                            spacing: 8,
                            children: [
                              Row(
                                mainAxisAlignment: .spaceBetween,
                                children: [
                                  Text(copy.programLength, style: label),
                                  SettingSwitcher<bool>(
                                    value: fixed,
                                    children: {
                                      true: Text(copy.programFixedLength),
                                      false: Text(copy.programOngoing),
                                    },
                                    onValueChanged: (value) => _fixed.value = value ?? fixed,
                                  ),
                                ],
                              ),
                              if (fixed)
                                ValueListenableBuilder(
                                  valueListenable: _weeks,
                                  builder: (_, weeks, _) {
                                    return _NumberRow(
                                      value: copy.programWeeks(weeks),
                                      onFewer: weeks > 1 ? () => _weeks.value-- : null,
                                      onMore: weeks < _maxWeeks ? () => _weeks.value++ : null,
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ListenableBuilder(
                        listenable: Listenable.merge([_name, _saving]),
                        builder: (context, _) {
                          final ready = _name.text.trim().isNotEmpty && !_saving.value;
                          return PrimaryButton.wide(
                            onPressed: ready ? () => _save(context, sessions) : null,
                            child: Center(child: Text(isNew ? copy.programStartIt : copy.save)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleDay(int day) {
    final days = {..._days.value};
    if (!days.remove(day)) days.add(day);
    _days.value = days;
  }

  Future<void> _save(BuildContext context, List<Template> sessions) async {
    _saving.value = true;
    final programs = Programs.of(context);
    final analytics = Analytics.of(context);
    final name = _name.text.trim();
    final perWeek = _perWeek.value;
    final weeks = _fixed.value ? _weeks.value : null;

    try {
      switch (widget.program?.id) {
        case final String id:
          // onto the program as it stands now, not as it was when the form
          // opened: a read from the server since may have moved its rules
          final program = programs.lookup(id);
          if (program == null) break;
          // through the map rather than copyWith, which cannot clear a field:
          // taking the weekly target away, or a fixed length, is a real edit
          final fields = program.toMap()
            ..['name'] = name
            ..['days'] = (_days.value.toList()..sort())
            ..remove('perWeek')
            ..remove('weeks');
          await programs.update(
            Program.fromJson({
              ...fields,
              if (perWeek > 0) 'perWeek': perWeek,
              'weeks': ?weeks,
            }),
          );
        case null:
          await programs.create(
            Program(
              name: name,
              perWeek: perWeek > 0 ? perWeek : null,
              days: _days.value,
              weeks: weeks,
            ),
            sessions: sessions,
          );
          analytics.programCreated(source: .folder, sessions: sessions.length);
      }
    } finally {
      _saving.value = false;
    }
    widget.onDone();
  }
}

const _defaultWeeks = 8;
const _maxWeeks = 104;
const _maxPerWeek = 28;
const _maxName = 100;

/// A number set with a minus and a plus, the value between them as copy.
class _NumberRow extends StatelessWidget {
  final String? label;
  final String value;
  final VoidCallback? onFewer;
  final VoidCallback? onMore;

  const new({this.label, required this.value, required this.onFewer, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    return Row(
      children: [
        // with no label of its own it sits under the control it belongs to,
        // in the same column as the steppers that have one
        switch (label) {
          final String label => Expanded(child: Text(label, style: textTheme.titleSmall)),
          null => const Spacer(),
        },
        IconButton(tooltip: copy.programFewer, onPressed: onFewer, icon: const Icon(Icons.remove_rounded)),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Text(value, style: textTheme.titleMedium, textAlign: .center),
        ),
        IconButton(tooltip: copy.programMore, onPressed: onMore, icon: const Icon(Icons.add_rounded)),
      ],
    );
  }
}

/// The seven days, from the user's first, each a toggle: the days a program
/// would rather fall on. A hint for what is up next, never a rule.
class _DayToggles extends StatelessWidget {
  final Set<int> days;
  final void Function(int) onToggle;

  const new({required this.days, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final locale = L.of(context).localeName;
    final first = _firstWeekday(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final day = (first - 1 + index) % 7 + 1;
        // 2024-01-07 is a Sunday, ISO 7; the six days after it are 1 to 6
        final date = DateTime(2024, 1, 7 + day % 7);
        final on = days.contains(day);
        return Semantics(
          button: true,
          selected: on,
          label: DateFormat.EEEE(locale).format(date),
          excludeSemantics: true,
          child: Material(
            color: on ? colorScheme.primary : colorScheme.surfaceContainerHighest,
            shape: const CircleBorder(),
            clipBehavior: .antiAlias,
            child: InkWell(
              onTap: () => onToggle(day),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: Text(
                    DateFormat.EEEEE(locale).format(date),
                    style: textTheme.titleSmall?.copyWith(
                      color: on ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
