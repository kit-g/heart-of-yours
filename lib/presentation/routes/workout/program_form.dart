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
    final copy = L.of(context);
    final form = switch ((programId, folderId)) {
      (final String id, _) => switch (Programs.watch(context).lookup(id)) {
        final Program program => ProgramFieldsForm(
          key: ValueKey(id),
          initial: program,
          title: copy.editProgram,
          saveLabel: copy.save,
          onSave: (fields) => _update(context, id, fields),
          onDone: onDone,
        ),
        null => null,
      },
      (null, final String id) => switch (Templates.watch(context).folders.where((each) => each.id == id).firstOrNull) {
        final TemplateFolder folder => _fromFolder(context, folder),
        null => null,
      },
      (null, null) => null,
    };
    return _ProgramsOnly(child: form ?? Scaffold(appBar: AppBar()));
  }

  Widget _fromFolder(BuildContext context, TemplateFolder folder) {
    final copy = L.of(context);
    final sessions = Templates.watch(context).templatesIn(folder).toList();
    return ProgramFieldsForm(
      key: ValueKey(folder.id),
      // a folder of three templates reads as three a week until the user
      // says otherwise; a week has seven days to put them in
      initial: Program(name: folder.name, perWeek: sessions.length.clamp(1, 7), weeks: _defaultWeeks),
      sessions: sessions,
      title: copy.newProgram,
      saveLabel: copy.programStartIt,
      // asked where a program is set up: the list is the user's, not this
      // program's, and stays on this phone
      afterDays: const GoEasyRow(),
      onSave: (fields) async {
        final analytics = Analytics.of(context);
        await Programs.of(context).create(
          Program(name: fields.name, perWeek: fields.perWeek, days: fields.days, weeks: fields.weeks),
          sessions: sessions,
        );
        analytics.programCreated(source: .folder, sessions: sessions.length);
        return true;
      },
      onDone: onDone,
    );
  }

  /// Onto the program as it stands now, not as it was when the form opened:
  /// a read from the server since may have moved its rules.
  static Future<bool> _update(BuildContext context, String id, ProgramFields fields) async {
    final programs = Programs.of(context);
    if (programs.lookup(id) case final Program program) await programs.update(program.withFields(fields));
    return true;
  }
}

/// What [ProgramFieldsForm] edits: a program's own fields, apart from its
/// sessions and rules.
typedef ProgramFields = ({String name, String? note, int? perWeek, Set<int> days, int? weeks});

extension ProgramWithFields on Program {
  /// This program with [fields]. Taking the weekly target away, a fixed
  /// length or the note is a real edit, which copyWith cannot make: a null
  /// there keeps the value.
  Program withFields(ProgramFields fields) {
    final (:name, :note, :perWeek, :days, :weeks) = fields;
    return copyWith(name: name, note: note, days: days, perWeek: perWeek, weeks: weeks).without({
      if (perWeek == null) .perWeek,
      if (weeks == null) .weeks,
      if (note == null) .note,
    });
  }
}

/// A program's own fields, starting from [initial]'s: its name, how many
/// times a week, the days it would rather fall on, and how long it runs, and
/// with [withNote] a line about it. Whose program it is, and what a save
/// does, is the caller's: the user's own (#348) or a coach's library (#557).
class ProgramFieldsForm extends StatefulWidget {
  final Program initial;

  /// Listed under the name, when the program is made from them.
  final List<Template> sessions;

  final String title;
  final String saveLabel;

  /// Whether the form edits the program's note.
  final bool withNote;

  /// What goes under the days, when something does.
  final Widget? afterDays;

  /// Saves the fields, and answers whether the page may go: one that could
  /// not save says why itself, and the form stays as it was.
  final Future<bool> Function(ProgramFields fields) onSave;

  /// Leaves the page once [onSave] has saved.
  final VoidCallback onDone;

  const new({
    super.key,
    required this.initial,
    this.sessions = const [],
    required this.title,
    required this.saveLabel,
    this.withNote = false,
    this.afterDays,
    required this.onSave,
    required this.onDone,
  });

  @override
  State<ProgramFieldsForm> createState() => _ProgramFieldsFormState();
}

class _ProgramFieldsFormState extends State<ProgramFieldsForm> {
  late final TextEditingController _name;
  late final TextEditingController _note;

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
    final program = widget.initial;
    _name = TextEditingController(text: program.name);
    _note = TextEditingController(text: program.note ?? '');
    _days = ValueNotifier({...program.days});
    _weeks = ValueNotifier(program.weeks ?? _defaultWeeks);
    _perWeek = ValueNotifier(program.perWeek ?? 0);
    _fixed = ValueNotifier(program.weeks != null);
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
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
    final sessions = widget.sessions;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                      key: AppKeys.programFormName,
                      controller: _name,
                      textCapitalization: .sentences,
                      maxLength: _maxName,
                      decoration: InputDecoration(labelText: copy.programName, counterText: ''),
                    ),
                    if (widget.withNote) ...[
                      const SizedBox(height: 16),
                      TextField(
                        key: AppKeys.programFormNote,
                        controller: _note,
                        textCapitalization: .sentences,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: _maxNote,
                        decoration: InputDecoration(labelText: copy.coachingProgramNote, counterText: ''),
                      ),
                    ],
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
                          value: switch (perWeek) {
                            0 => copy.programNoTarget,
                            _ => '$perWeek',
                          },
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
                    if (widget.afterDays case final Widget after) ...[
                      const SizedBox(height: 8),
                      after,
                    ],
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
                          key: AppKeys.programFormSave,
                          onPressed: ready ? _save : null,
                          child: Center(child: Text(widget.saveLabel)),
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
    );
  }

  void _toggleDay(int day) {
    final days = {..._days.value};
    if (!days.remove(day)) days.add(day);
    _days.value = days;
  }

  Future<void> _save() async {
    _saving.value = true;
    final perWeek = _perWeek.value;
    final note = _note.text.trim();
    final bool saved;
    try {
      saved = await widget.onSave((
        name: _name.text.trim(),
        // a form without the note leaves it as it was
        note: switch ((widget.withNote, note)) {
          (false, _) => widget.initial.note,
          (true, '') => null,
          (true, final note) => note,
        },
        perWeek: perWeek > 0 ? perWeek : null,
        days: _days.value,
        weeks: _fixed.value ? _weeks.value : null,
      ));
    } finally {
      if (mounted) _saving.value = false;
    }
    if (saved) widget.onDone();
  }
}

const _defaultWeeks = 8;
const _maxWeeks = 104;
const _maxPerWeek = 28;
const _maxName = 100;
const _maxNote = 500;

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
    final first = firstWeekdayOf(context, listen: true);
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
