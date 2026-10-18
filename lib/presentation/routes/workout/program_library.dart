part of 'workout.dart';

/// Heart's ready-made programs (#352, #162): every one, grouped by who it is
/// for, and one filter for what it needs. The library asks nothing; it shows
/// the plans.
class ProgramLibraryPage extends StatefulWidget {
  final void Function(LibraryProgram) onOpen;

  const new({super.key, required this.onOpen});

  @override
  State<ProgramLibraryPage> createState() => _ProgramLibraryPageState();
}

class _ProgramLibraryPageState extends State<ProgramLibraryPage> {
  final _gear = ValueNotifier(_Gear.any);

  @override
  void initState() {
    super.initState();
    // opened from a link before anything asked for it
    ProgramLibrary.of(context).ensure();
  }

  @override
  void dispose() {
    _gear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final library = ProgramLibrary.watch(context);
    final tag = languageTag();
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);

    return _ProgramsOnly(
      child: Scaffold(
        appBar: AppBar(title: Text(copy.programLibrary)),
        // nothing to show until the file is in: no apology, no spinner
        body: switch (library.available) {
          false => const SizedBox.shrink(),
          true => SafeArea(
            child: ValueListenableBuilder(
              valueListenable: _gear,
              builder: (context, gear, _) {
                final shown = library.programs.where(gear.fits).toList();
                return ListView(
                  padding: const .all(16),
                  children: [
                    Center(
                      child: Semantics(
                        label: copy.libraryEquipment,
                        child: SettingSwitcher<_Gear>(
                          key: AppKeys.libraryEquipment,
                          value: gear,
                          children: {for (final each in _Gear.values) each: Text(each.label(copy))},
                          onValueChanged: (value) => _gear.value = value ?? gear,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (shown.isEmpty)
                      Padding(
                        padding: const .symmetric(vertical: 24),
                        child: Text(
                          copy.libraryNothingFits,
                          textAlign: .center,
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    for (final audience in [...LibraryAudience.values, null])
                      if (shown.where((program) => program.audience == audience).toList() case final group
                          when group.isNotEmpty) ...[
                        Padding(
                          padding: const .only(top: 16, bottom: 8),
                          child: Text(_audienceLabel(copy, audience), style: textTheme.titleMedium),
                        ),
                        // cards measure the room the page got: one column on a
                        // phone, more across a tablet rather than one 1100pt card
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const gap = 8.0;
                            final width = constraints.maxWidth;
                            final columns = columnsFor(width, maxExtent: _libraryCardMaxWidth);
                            Widget card(LibraryProgram program) {
                              return _LibraryCard(program: program, tag: tag, onTap: () => widget.onOpen(program));
                            }

                            // in rows, each card as tall as the tallest beside
                            // it: a free-height grid left neighbours ragged
                            return Column(
                              crossAxisAlignment: .stretch,
                              spacing: gap,
                              children: [
                                for (final row in List.generate(
                                  (group.length / columns).ceil(),
                                  (index) => group.skip(index * columns.toInt()).take(columns.toInt()).toList(),
                                ))
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: .stretch,
                                      spacing: gap,
                                      children: [
                                        for (final program in row) Expanded(child: card(program)),
                                        // a short last row keeps its columns
                                        for (final _ in Iterable.generate(columns.toInt() - row.length))
                                          const Expanded(child: SizedBox.shrink()),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
        },
      ),
    );
  }
}

/// The widest a library card gets before the page adds a column beside it.
const _libraryCardMaxWidth = 420.0;

/// The library's one filter: what a program needs.
enum _Gear {
  any(null),
  none(.none),
  home(.home),
  gym(.gym);

  final LibraryEquipment? equipment;

  new(this.equipment);

  bool fits(LibraryProgram program) => equipment == null || program.equipment == equipment;

  String label(L copy) {
    return switch (this) {
      .any => copy.libraryEquipmentAny,
      .none => copy.libraryEquipmentNone,
      .home => copy.libraryEquipmentHome,
      .gym => copy.libraryEquipmentGym,
    };
  }
}

String _audienceLabel(L copy, LibraryAudience? audience) {
  return switch (audience) {
    .startingOut => copy.libraryStartingOut,
    .gettingBack => copy.libraryGettingBack,
    .keepMuscle => copy.libraryKeepMuscle,
    .gettingStronger => copy.libraryGettingStronger,
    null => copy.libraryMore,
  };
}

/// The user's history with [key] in words, or null when they never started
/// it: "Following now", "Finished", "Stopped at week 5 of 12".
String? _history(BuildContext context, String key) {
  final copy = L.of(context);
  final history = Programs.watch(context).historyOf(key, now: DateTime.now(), firstWeekday: firstWeekdayOf(context));
  return switch (history) {
    LibraryFollowing() => copy.libraryFollowingNow,
    LibraryFinished() => copy.libraryFinishedIt,
    LibraryTried(:final week, weeks: final int weeks) => copy.libraryStoppedAt(week, weeks),
    LibraryTried(:final week, weeks: null) => copy.libraryStoppedAtOpen(week),
    null => null,
  };
}

/// How often, how long and for how many weeks, in a line.
String _facts(L copy, LibraryProgram program) {
  return [
    if (program.perWeek case final int perWeek) copy.libraryPerWeek(perWeek),
    if (program.minutes case final int minutes) copy.libraryMinutes(minutes),
    switch (program.weeks) {
      final int weeks => copy.programWeeks(weeks),
      null => copy.programOngoing,
    },
  ].join(' · ');
}

/// A library program as the library lists it: its name, the facts that pick
/// one, and what it is, in its own words.
class _LibraryCard extends StatelessWidget {
  final LibraryProgram program;
  final String tag;
  final VoidCallback onTap;

  const new({required this.program, required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);

    return Material(
      key: AppKeys.libraryProgram(program.key),
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 4,
            children: [
              Row(
                spacing: 8,
                crossAxisAlignment: .start,
                children: [
                  Expanded(child: Text(program.name.of(tag), style: textTheme.titleMedium)),
                  // what the user has done with it, small, beside its name
                  if (_history(context, program.key) case final String history)
                    DecoratedBox(
                      key: AppKeys.libraryHistory(program.key),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: const .all(.circular(8)),
                      ),
                      child: Padding(
                        padding: const .symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          history,
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                ],
              ),
              Text(_facts(copy, program), style: muted),
              if (program.note case final ContentText note)
                Text(note.of(tag), style: textTheme.bodyMedium, maxLines: 3, overflow: .ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of Heart's programs before committing to it: the plan with its sets,
/// who it is for, how it grows, the research behind each part beside that
/// part, and the safety notes, once. Nothing is copied until "Start program".
class LibraryProgramPage extends StatefulWidget {
  final String programKey;

  /// Opens the user's program: the one just started, or a copy already followed.
  final void Function(Program) onProgram;

  /// Opens another of the library's programs, one to go on to.
  final void Function(String key) onLibraryProgram;

  const new({super.key, required this.programKey, required this.onProgram, required this.onLibraryProgram});

  @override
  State<LibraryProgramPage> createState() => _LibraryProgramPageState();
}

class _LibraryProgramPageState extends State<LibraryProgramPage> {
  final _starting = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    ProgramLibrary.of(context).ensure();
  }

  @override
  void dispose() {
    _starting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ProgramLibrary.watch(context);
    final program = library.lookup(widget.programKey);
    // not read yet, or gone from a newer file
    if (program == null) return Scaffold(appBar: AppBar());

    return _ProgramsOnly(child: _page(context, library, program));
  }

  Widget _page(BuildContext context, ProgramLibrary library, LibraryProgram program) {
    final copy = L.of(context);
    final tag = languageTag();
    final exercises = Exercises.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    Widget heading(String text) {
      return Padding(
        padding: const .only(top: 24, bottom: 6),
        child: Text(text, style: textTheme.titleSmall),
      );
    }

    Widget claims(Iterable<LibraryClaim> claims) => _Claims(claims: claims.toList(), tag: tag);

    List<Widget> section(String title, ContentText? text, String on) {
      return switch (text) {
        null => const [],
        final ContentText text => [
          heading(title),
          Text(text.of(tag), style: textTheme.bodyMedium),
          claims(program.claimsAbout(on)),
        ],
      };
    }

    // a claim about several rules reads once, under how the program grows,
    // and not again when it is about the growing as a whole too
    final rules = {
      for (final key in program.ruled) ...program.claimsAbout('rule', exercise: key),
    }.difference(program.claimsAbout('grows').toSet());
    final sessionNames = {
      for (final session in program.sessions) session.id: session.name.of(tag),
    };
    final sources = [
      for (final key in program.sources) ?library.source(key),
    ];
    final next = [
      for (final key in program.next) ?library.lookup(key),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(program.name.of(tag))),
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
                    Text(_facts(copy, program), style: muted),
                    if (_history(context, program.key) case final String history) ...[
                      const SizedBox(height: 4),
                      Text(history, key: AppKeys.libraryHistory(program.key), style: textTheme.labelLarge),
                    ],
                    if (program.note case final ContentText note) ...[
                      const SizedBox(height: 8),
                      Text(note.of(tag), style: textTheme.bodyLarge),
                    ],
                    if (program.claimsAbout('program') case final about when about.isNotEmpty) ...[
                      heading(copy.libraryWhy),
                      claims(about),
                    ],
                    if (program.safety.map(library.safety).nonNulls.toList() case final notes when notes.isNotEmpty)
                      _SafetyNotes(notes: notes, tag: tag),
                    ...section(copy.libraryWho, program.who, 'who'),
                    ...section(copy.libraryWeek, program.week, 'week'),
                    ...section(copy.programGrowth, program.grows, 'grows'),
                    if (rules.isNotEmpty) claims(rules),
                    if (program.deload case final Deload deload) ...[
                      const SizedBox(height: 8),
                      Text(copy.libraryDeload(deload.every), style: textTheme.bodyMedium),
                      claims(program.claimsAbout('deload')),
                    ],
                    ...section(copy.libraryMisses, program.misses, 'misses'),
                    if (program.phases.isNotEmpty) ...[
                      heading(copy.libraryPhases),
                      for (final phase in program.phases)
                        _PhaseLine(
                          name: phase.name?.of(tag),
                          length: switch (phase.cycles) {
                            final int cycles => copy.programWeeks(cycles),
                            null => copy.libraryPhaseOn,
                          },
                          sessions: [for (final id in phase.sessions) ?sessionNames[id]],
                        ),
                      claims(program.claimsAbout('phases')),
                      claims(program.claimsAbout('tests')),
                    ],
                    heading(copy.programSessions),
                    claims(program.claimsAbout('rest')),
                    for (final session in program.sessions)
                      _LibrarySessionCard(
                        session: session,
                        preview: session.preview(resolve: exercises.lookupByKey, tag: tag),
                        test: program.tests.containsKey(session.id),
                        claims: program.claimsAbout('session', session: session.id).toList(),
                        exerciseClaims: (exercise) => program.claimsAbout(
                          'exercise',
                          session: session.id,
                          exercise: exercise,
                        ),
                        tag: tag,
                      ),
                    // after the sessions, once the program is known: what the
                    // list marks in them is what is harder (#396)
                    const SizedBox(height: 16),
                    const GoEasyRow(),
                    if (next.isNotEmpty) ...[
                      heading(copy.libraryNext),
                      for (final each in next)
                        ListTile(
                          key: AppKeys.libraryNext(each.key),
                          contentPadding: .zero,
                          title: Text(each.name.of(tag)),
                          subtitle: Text(_facts(copy, each), style: textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => widget.onLibraryProgram(each.key),
                        ),
                      claims(program.claimsAbout('next')),
                    ],
                    if (sources.isNotEmpty) ...[
                      heading(copy.librarySources),
                      for (final source in sources) _SourceEntry(source: source, tag: tag),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16, 8, 16, 8),
          child: Center(
            heightFactor: 1,
            child: SizedBox(
              width: readableWidth,
              child: _StartBar(
                program: program,
                starting: _starting,
                onStart: () => _start(context, program),
                onOpen: widget.onProgram,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Makes [program] the user's own, under its name, and opens it. With an
  /// account its sessions get a folder of the program's name; a session
  /// without one has no folders to file them in.
  Future<void> _start(BuildContext context, LibraryProgram program) async {
    final copy = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final templates = Templates.of(context);
    final programs = Programs.of(context);
    final analytics = Analytics.of(context);
    final resolve = Exercises.of(context).lookupByKey;
    final remote = RemoteAccess.of(context);
    final tag = languageTag();

    // the days it would rather fall on, asked as it starts, as a program made
    // from a folder asks in its form; waved away, nothing starts
    final days = await showDialog<Set<int>>(context: context, builder: (_) => const _StartDays());
    if (days == null) return;

    _starting.value = true;
    // made only once the copy is known to resolve, and taken back if the
    // program then fails: "nothing changed" leaves no empty folder behind
    TemplateFolder? folder;
    try {
      final order = templates.fold(-1, (highest, template) => max(highest, template.order)) + 1;
      if (program.copy(resolve: resolve, tag: tag) == null) {
        throw StateError('no session of ${program.key} resolves');
      }
      if (remote.allowed) {
        folder = await templates.createFolder(_freeFolderName(templates, program.name.of(tag)));
      }
      final made = program.copy(resolve: resolve, tag: tag, folder: folder, order: order)!;

      final started = await programs.create(made.program.copyWith(days: days), sessions: made.sessions);
      analytics.programCreated(source: .library, sessions: made.sessions.length, library: program.key);
      if (context.mounted) widget.onProgram(started);
    } catch (e, s) {
      reportToSentry(e, stacktrace: s);
      if (folder case final TemplateFolder made) {
        await templates.deleteFolder(made).catchError((Object e, StackTrace s) => reportToSentry(e, stacktrace: s));
      }
      messenger.showSnackBar(SnackBar(content: Text(copy.libraryStartFailed)));
    } finally {
      _starting.value = false;
    }
  }
}

/// Which days a ready-made program would rather fall on, asked as it starts:
/// the week from the user's first day (#339), each day a toggle. A hint for
/// what is up next, never a rule — so Skip starts it with none.
class _StartDays extends StatefulWidget {
  const new();

  @override
  State<_StartDays> createState() => _StartDaysState();
}

class _StartDaysState extends State<_StartDays> {
  final _days = ValueNotifier(<int>{});

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  void _toggle(int day) {
    _days.value = switch (_days.value.contains(day)) {
      true => {..._days.value}..remove(day),
      false => {..._days.value, day},
    };
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return AlertDialog(
      key: AppKeys.libraryStartDays,
      title: Text(copy.libraryStartDays),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: dialogWidth),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            Text(
              copy.libraryStartDaysHint,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            ValueListenableBuilder(
              valueListenable: _days,
              builder: (_, days, _) => _DayToggles(days: days, onToggle: _toggle),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: AppKeys.libraryStartDaysSkip,
          onPressed: () => Navigator.of(context).pop(<int>{}),
          child: Text(copy.skip),
        ),
        ValueListenableBuilder(
          valueListenable: _days,
          builder: (context, days, _) {
            return PrimaryButton.shrunk(
              key: AppKeys.libraryStartDaysStart,
              onPressed: switch (days.isEmpty) {
                true => null,
                false => () => Navigator.of(context).pop(days),
              },
              child: Text(copy.programStartIt),
            );
          },
        ),
      ],
    );
  }
}

/// [name], or the first "name 2", "name 3"… that no folder has yet: the same
/// program started twice files its sessions apart.
String _freeFolderName(Templates templates, String name) {
  final taken = {for (final folder in templates.folders) folder.name};
  if (!taken.contains(name)) return name;
  return Iterable.generate(taken.length + 1, (index) => '$name ${index + 2}').firstWhere(
    (candidate) => !taken.contains(candidate),
  );
}

/// What the page's bottom offers: to start the program, to open the copy
/// already followed, or — when its sessions don't fit the template allowance —
/// why it can't be started, in place of a button that would fail.
class _StartBar extends StatelessWidget {
  final LibraryProgram program;
  final ValueNotifier<bool> starting;
  final VoidCallback onStart;
  final void Function(Program) onOpen;

  const new({required this.program, required this.starting, required this.onStart, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final templates = Templates.watch(context);
    final following = Programs.watch(
      context,
    ).following.where((each) => each.source == program.key).firstOrNull;
    final sessions = program.sessions.length;

    if (following != null) {
      return PrimaryButton.wide(
        key: AppKeys.libraryOpenYours,
        onPressed: () => onOpen(following),
        child: Center(heightFactor: 1, child: Text(copy.libraryOpenYours)),
      );
    }

    if (!templates.allowsNewTemplates(sessions)) {
      return Text(
        copy.libraryNoRoom(sessions - templates.templateRoom),
        textAlign: .center,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    return ValueListenableBuilder(
      valueListenable: starting,
      builder: (_, busy, _) {
        return PrimaryButton.wide(
          key: AppKeys.libraryStart,
          onPressed: busy ? null : onStart,
          child: Center(heightFactor: 1, child: Text(copy.programStartIt)),
        );
      },
    );
  }
}

/// The safety notes a program names, as the library words them, once.
class _SafetyNotes extends StatelessWidget {
  final List<LibrarySafety> notes;
  final String tag;

  const new({required this.notes, required this.tag});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Container(
      margin: const .only(top: 16),
      padding: const .all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const .all(.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(Icons.health_and_safety_outlined, size: 20, color: colorScheme.onSurfaceVariant),
              Text(L.of(context).librarySafety, style: textTheme.titleSmall),
            ],
          ),
          for (final note in notes) Text(note.text.of(tag), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A phase in a line: its name, how long it runs, and its sessions.
class _PhaseLine extends StatelessWidget {
  final String? name;
  final String length;
  final List<String> sessions;

  const new({required this.name, required this.length, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      padding: const .only(bottom: 6),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text([?name, length].join(' · '), style: textTheme.bodyMedium),
          Text(
            sessions.join(', '),
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A session of a library program: its exercises, each with its sets, rest,
/// and what it can be swapped for, and the research about any of it.
class _LibrarySessionCard extends StatelessWidget {
  final LibrarySession session;
  final Template preview;
  final bool test;
  final List<LibraryClaim> claims;
  final Iterable<LibraryClaim> Function(String exerciseId) exerciseClaims;
  final String tag;

  const new({
    required this.session,
    required this.preview,
    required this.test,
    required this.claims,
    required this.exerciseClaims,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final exercises = preview.toList();

    return Container(
      margin: const .only(bottom: 8),
      padding: const .all(12),
      decoration: BoxDecoration(
        border: Border.all(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(child: Text(session.name.of(tag), style: textTheme.titleMedium)),
              if (test) Text(copy.libraryTest, style: textTheme.labelMedium?.copyWith(color: colorScheme.primary)),
            ],
          ),
          if (session.note case final ContentText note) Text(note.of(tag), style: muted),
          _Claims(claims: claims, tag: tag),
          for (final exercise in exercises)
            Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    Flexible(child: Text(exercise.exercise.name, style: textTheme.bodyLarge)),
                    if (exercise.superset != null &&
                        exercises.where((each) => each.superset == exercise.superset).length > 1)
                      Text(copy.librarySuperset, style: textTheme.labelSmall?.copyWith(color: colorScheme.primary)),
                  ],
                ),
                Text(_setsLine(copy, exercise), style: muted),
                if (goEasyMarks(context, exercise.exercise) case final marks when marks.isNotEmpty)
                  GoEasyMarker(marks: marks, exercise: exercise.exercise, candidates: Exercises.of(context)),
                if (exercise.pattern case final String pattern)
                  Text(copy.libraryOrAny(PatternFilter(pattern).label(copy)), style: muted),
                _Claims(claims: exerciseClaims(exercise.id).toList(), tag: tag),
              ],
            ),
        ],
      ),
    );
  }
}

/// An exercise's sets in a line: "3 × 8–12 · 1:30 rest", the main sets apart
/// from the lighter ones after them, and each set's own aim where they differ.
String _setsLine(L copy, WorkoutExercise exercise) {
  final sets = exercise.toList();
  final main = sets.where((set) => set.target?.supplemental != true).toList();
  final lighter = sets.length - main.length;
  final aims = main.map((set) => _aim(copy, set.target)).toList();
  final first = aims.firstOrNull ?? '';

  return [
    switch (aims.every((aim) => aim == first)) {
      true => copy.librarySets(main.length, first),
      false => aims.join(', '),
    },
    if (lighter > 0) copy.libraryLighterSets(lighter),
    if (exercise.totalReps case final TargetRange total)
      copy.libraryTotalReps(switch (total) {
        TargetRange(isExact: true, :final min) => '${min.round()}',
        TargetRange(:final min, max: null) => '${min.round()}+',
        TargetRange(:final min, :final num max) => '${min.round()}–${max.round()}',
      }),
    if (exercise.rest case final int rest when rest > 0) copy.libraryRest(_clock(copy, rest)),
  ].join(' · ');
}

/// What a set aims for: its reps, time or distance, a share of a max, and
/// how many reps to leave in reserve.
String _aim(L copy, SetTarget? target) {
  if (target == null) return '';
  String range(TargetRange range, String Function(num) shown) {
    return switch (range) {
      TargetRange(isExact: true, :final min) => shown(min),
      TargetRange(:final min, max: null) => '${shown(min)}+',
      TargetRange(:final min, :final num max, amrap: true) => '${shown(min)}–${shown(max)}+',
      TargetRange(:final min, :final num max) => '${shown(min)}–${shown(max)}',
    };
  }

  final percent = NumberFormat.percentPattern(copy.localeName);
  return [
    if (target[.reps] case final TargetRange reps) range(reps, (value) => '${value.round()}'),
    if (target[.duration] case final TargetRange time) range(time, (value) => _clock(copy, value.round())),
    if (target.share case final num share) '@ ${percent.format(share)}',
    if (target.rir case final num rir)
      '(${copy.libraryInReserve(NumberFormat.decimalPattern(copy.localeName).format(rir))})',
  ].join(' ');
}

/// [seconds] as a clock past a minute, as seconds under it.
String _clock(L copy, int seconds) {
  return switch (seconds) {
    < 60 => '$seconds ${copy.sec}',
    _ => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
  };
}

/// Research sentences beside the part of a program they explain, each with
/// links to what it rests on. Nothing at all when there are none.
class _Claims extends StatelessWidget {
  final List<LibraryClaim> claims;
  final String tag;

  const new({required this.claims, required this.tag});

  /// A claim as a quote: its words, and its sources under them.
  Widget _quote(BuildContext context, LibraryClaim claim, List<LibrarySource> sources, {required bool inert}) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colorScheme.outlineVariant, width: 2)),
      ),
      child: Padding(
        padding: const .only(left: 10),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 2,
          children: [
            Text(claim.text.of(tag), style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            Wrap(
              spacing: 12,
              children: [for (final source in sources) _SourceLink(source: source, inert: inert)],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) return const SizedBox.shrink();
    final library = ProgramLibrary.of(context);

    return Padding(
      padding: const .only(top: 6),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 6,
        children: [
          for (final claim in claims)
            switch ([for (final key in claim.sources) ?library.source(key)]) {
              // one source to open: the whole quote is its link, one control
              final sources when sources.where((source) => source.url != null).length == 1 => _Linked(
                url: sources.firstWhere((source) => source.url != null).url!,
                child: _quote(context, claim, sources, inert: true),
              ),
              // several: one tap cannot open them all, so each is its own
              final sources => _quote(context, claim, sources, inert: false),
            },
        ],
      ),
    );
  }
}

/// The whole of something as one link to [url]: a single control, read as a
/// link, with ink inset to its shape.
class _Linked extends StatelessWidget {
  final Uri url;
  final Widget child;
  final Key? linkKey;

  const new({required this.url, required this.child, this.linkKey});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        link: true,
        child: InkWell(
          key: linkKey,
          borderRadius: const .all(.circular(6)),
          onTap: () => _open(url),
          child: child,
        ),
      ),
    );
  }
}

/// A source as a short link beside a claim: who, and when. [inert] when the
/// claim around it is the link: it still looks like one, and is not a second
/// control.
class _SourceLink extends StatelessWidget {
  final LibrarySource source;
  final bool inert;

  const new({required this.source, this.inert = false});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final short = [?source.who?.split(',').first.trim(), ?source.year?.toString()].join(', ');
    final style = textTheme.labelSmall?.copyWith(
      color: colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: colorScheme.primary,
    );
    return switch (source.url) {
      null => Text(short.isEmpty ? source.title : short, style: textTheme.labelSmall),
      Uri() when inert => Padding(
        padding: const .symmetric(vertical: 4),
        child: Text(short.isEmpty ? source.title : short, style: style),
      ),
      final Uri url => Tooltip(
        message: source.title,
        child: InkWell(
          onTap: () => _open(url),
          child: Padding(
            padding: const .symmetric(vertical: 4),
            child: Semantics(link: true, child: Text(short.isEmpty ? source.title : short, style: style)),
          ),
        ),
      ),
    };
  }
}

/// A source in the program's list: its title as the link, who published it
/// and when, and what it found.
class _SourceEntry extends StatelessWidget {
  final LibrarySource source;
  final String tag;

  const new({required this.source, required this.tag});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final title = Text(
      source.title,
      style: switch (source.url) {
        null => textTheme.bodyMedium,
        Uri() => textTheme.bodyMedium?.copyWith(
          color: colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary,
        ),
      },
    );
    final entry = Column(
      crossAxisAlignment: .start,
      spacing: 2,
      children: [
        title,
        if ([?source.who, ?source.year?.toString()] case final byline when byline.isNotEmpty)
          Text(byline.join(', '), style: muted),
        if (source.finding case final ContentText finding) Text(finding.of(tag), style: muted),
      ],
    );
    return Padding(
      padding: const .only(bottom: 10),
      // the whole entry opens the source, not just its title
      child: switch (source.url) {
        null => entry,
        final Uri url => _Linked(url: url, linkKey: AppKeys.librarySource(source.key), child: entry),
      },
    );
  }
}

/// Opens a source where it is published, out of the app.
Future<void> _open(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);
