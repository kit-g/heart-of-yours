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
    LibraryFinished(:final DateTime on) => copy.programFinishedOn(
      DateFormat.MMMd(copy.localeName).format(on.toLocal()),
    ),
    LibraryFinished() => copy.libraryFinishedIt,
    LibraryTried(:final week, weeks: final int weeks) => copy.libraryStoppedAt(week, weeks),
    LibraryTried(:final week, weeks: null) => copy.libraryStoppedAtOpen(week),
    null => null,
  };
}

/// How often, how long and for how many weeks, in a line.
String _facts(L copy, LibraryProgram program) => [for (final (_, fact) in _factsOf(copy, program)) fact].join(' · ');

/// How often, how long and for how many weeks, each with the icon its badge
/// wears on the program's page.
List<(IconData, String)> _factsOf(L copy, LibraryProgram program) {
  return [
    if (program.perWeek case final int perWeek) (Icons.event_repeat_rounded, copy.libraryPerWeek(perWeek)),
    if (program.minutes case final int minutes) (Icons.timer_outlined, copy.libraryMinutes(minutes)),
    (
      Icons.date_range_rounded,
      switch (program.weeks) {
        final int weeks => copy.programWeeks(weeks),
        null => copy.programOngoing,
      },
    ),
  ];
}

/// What a program needs, in a badge's words: the library's filter says
/// "None", which on its own beside a program says nothing.
String _needs(L copy, LibraryEquipment equipment) {
  return switch (equipment) {
    .none => copy.libraryNoEquipment,
    .home => copy.libraryEquipmentHome,
    .gym => copy.libraryEquipmentGym,
  };
}

/// A fact of a program at a glance: an icon and a few words on the quiet
/// fill chips wear, squared to the 8pt corner buttons have.
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const new({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: const .all(primaryButtonRadius),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: .min,
          spacing: 6,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            Flexible(
              child: Text(label, style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the user has done with a program, small: "Following now".
class _HistoryPill extends StatelessWidget {
  final String programKey;
  final String history;

  const new({required this.programKey, required this.history});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return DecoratedBox(
      key: AppKeys.libraryHistory(programKey),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: const .all(.circular(8)),
      ),
      child: Padding(
        padding: const .symmetric(horizontal: 6, vertical: 2),
        child: Text(history, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer)),
      ),
    );
  }
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
                    _HistoryPill(programKey: program.key, history: history),
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

    // each part of the plan under a heading with its own mark, so the page
    // reads as parts rather than one run of paragraphs
    Widget heading(String text, IconData icon) {
      return Padding(
        padding: const .only(top: 24, bottom: 8),
        child: Row(
          spacing: 8,
          children: [
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
            Expanded(child: Text(text, style: textTheme.titleSmall)),
          ],
        ),
      );
    }

    Widget claims(Iterable<LibraryClaim> claims) => _Claims(claims: claims.toList(), tag: tag);

    List<Widget> section(String title, IconData icon, ContentText? text, String on) {
      return switch (text) {
        null => const [],
        final ContentText text => [
          heading(title, icon),
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
                  // its own place to keep a scroll offset: without it, a
                  // program opened from "After this" opened where the one
                  // before it had been scrolled to
                  key: PageStorageKey(program.key),
                  padding: const .all(16),
                  children: [
                    if (_history(context, program.key) case final String history) ...[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _HistoryPill(programKey: program.key, history: history),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // what decides whether it fits, taken in at a glance
                    Wrap(
                      key: AppKeys.libraryFacts,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (icon, fact) in _factsOf(copy, program)) _Badge(icon: icon, label: fact),
                        if (program.audience case final LibraryAudience audience)
                          _Badge(icon: Icons.person_outline_rounded, label: _audienceLabel(copy, audience)),
                        if (program.equipment case final LibraryEquipment equipment)
                          _Badge(icon: Icons.fitness_center_rounded, label: _needs(copy, equipment)),
                      ],
                    ),
                    if (program.note case final ContentText note) ...[
                      const SizedBox(height: 16),
                      Text(note.of(tag), style: textTheme.bodyLarge),
                    ],
                    if (program.claimsAbout('program') case final about when about.isNotEmpty) ...[
                      heading(copy.libraryWhy, Icons.lightbulb_outline_rounded),
                      claims(about),
                    ],
                    if (program.safety.map(library.safety).nonNulls.toList() case final notes when notes.isNotEmpty)
                      _SafetyNotes(notes: notes, tag: tag),
                    ...section(copy.libraryWho, Icons.person_outline_rounded, program.who, 'who'),
                    ...section(copy.libraryWeek, Icons.calendar_view_week_rounded, program.week, 'week'),
                    ...section(copy.programGrowth, Icons.trending_up_rounded, program.grows, 'grows'),
                    if (rules.isNotEmpty) claims(rules),
                    if (program.deload case final Deload deload) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _Badge(icon: Icons.trending_down_rounded, label: copy.libraryDeload(deload.every)),
                      ),
                      claims(program.claimsAbout('deload')),
                    ],
                    ...section(copy.libraryMisses, Icons.replay_rounded, program.misses, 'misses'),
                    if (program.phases.isNotEmpty) ...[
                      heading(copy.libraryPhases, Icons.timeline_rounded),
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
                    heading(copy.programSessions, Icons.list_alt_rounded),
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
                      heading(copy.libraryNext, Icons.east_rounded),
                      for (final each in next)
                        // the go-easy row's shape, inset and ink (#488)
                        ListTile(
                          key: AppKeys.libraryNext(each.key),
                          contentPadding: GoEasyRow.padding,
                          shape: GoEasyRow.shape,
                          hoverColor: Colors.transparent,
                          leading: const Icon(Icons.auto_stories_outlined),
                          title: Text(each.name.of(tag)),
                          subtitle: Text(_facts(copy, each)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => widget.onLibraryProgram(each.key),
                        ),
                      claims(program.claimsAbout('next')),
                    ],
                    if (sources.isNotEmpty) ...[
                      heading(copy.librarySources, Icons.menu_book_outlined),
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
    final exercises = Exercises.of(context);
    final resolve = exercises.lookupByKey;
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
      // where each lift starts, from the user's own sets of it: the program's
      // goals show from day one, and its page says and edits them
      final seeded = await programs.seedBases(
        started,
        setsOf: (id) async => switch (exercises.lookup(id)) {
          final Exercise exercise => [
            for (final act in await exercises.getExerciseHistory(exercise, pageSize: 10)) ...act,
          ],
          null => const <ExerciseSet>[],
        },
      );
      if (seeded.isNotEmpty && context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              copy.programSeededFromHistory(
                seeded
                    .map((base) => (base, exercises.lookup(base.exerciseId)))
                    .map(
                      (pair) => switch (pair) {
                        (final base, final Exercise exercise) =>
                          '${exercise.name} ${GrowthMeasure.of(context, exercise, started.rules[base.exerciseId]).format(base.value)}',
                        (_, null) => null,
                      },
                    )
                    .nonNulls
                    .join(', '),
              ),
            ),
          ),
        );
      }
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

    // the one place Start stays, disabled: its absence would leave the user
    // guessing, and the reason under it says what to do (docs/style.md)
    if (!templates.allowsNewTemplates(sessions)) {
      return Column(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          PrimaryButton.wide(
            key: AppKeys.libraryStart,
            onPressed: null,
            child: Center(heightFactor: 1, child: Text(copy.programStartIt)),
          ),
          Text(
            key: AppKeys.libraryNoRoom,
            copy.libraryNoRoom(sessions - templates.templateRoom),
            textAlign: .center,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
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

/// A phase: its name and sessions on the left, how long it runs as a badge
/// on the right.
class _PhaseLine extends StatelessWidget {
  final String? name;
  final String length;
  final List<String> sessions;

  const new({required this.name, required this.length, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Padding(
      padding: const .only(bottom: 10),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 2,
              children: switch (name) {
                final String name => [
                  Text(name, style: textTheme.bodyLarge),
                  Text(sessions.join(', '), style: muted),
                ],
                null => [Text(sessions.join(', '), style: textTheme.bodyLarge)],
              },
            ),
          ),
          _Badge(icon: Icons.date_range_rounded, label: length),
        ],
      ),
    );
  }
}

/// A session of a library program: its exercises, each with its sets, rest,
/// and what it can be swapped for, and the research about any of it. An
/// exercise reads across the card: what it is on the left, what to do on the
/// right.
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

    Widget exercise(WorkoutExercise exercise) {
      final (:sets, :then) = _sets(copy, exercise);
      return Padding(
        padding: const .symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // the aims as wide as they need, up to a little under half the
            // card; the name takes the rest
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  crossAxisAlignment: .start,
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          Text(exercise.exercise.name, style: textTheme.bodyLarge),
                          if (exercise.superset != null &&
                              exercises.where((each) => each.superset == exercise.superset).length > 1)
                            Text(
                              copy.librarySuperset,
                              style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                            ),
                          if (goEasyMarks(context, exercise.exercise) case final marks when marks.isNotEmpty)
                            GoEasyMarker(marks: marks, exercise: exercise.exercise, candidates: Exercises.of(context)),
                          if (exercise.pattern case final String pattern)
                            Text(copy.libraryOrAny(PatternFilter(pattern).label(copy)), style: muted),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
                      child: Column(
                        crossAxisAlignment: .end,
                        spacing: 2,
                        children: [
                          Text(
                            sets,
                            textAlign: .end,
                            style: textTheme.bodyMedium?.copyWith(fontFeatures: const [.tabularFigures()]),
                          ),
                          for (final each in then) Text(each, textAlign: .end, style: muted),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            _Claims(claims: exerciseClaims(exercise.id).toList(), tag: tag),
          ],
        ),
      );
    }

    return Container(
      key: AppKeys.librarySession(session.id),
      margin: const .only(bottom: 8),
      padding: const .fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        border: Border.all(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(child: Text(session.name.of(tag), style: textTheme.titleMedium)),
              if (test) _Badge(icon: Icons.speed_rounded, label: copy.libraryTest),
            ],
          ),
          if (session.note case final ContentText note)
            Padding(
              padding: const .only(top: 4),
              child: Text(note.of(tag), style: muted),
            ),
          _Claims(claims: claims, tag: tag),
          const SizedBox(height: 4),
          for (final (index, each) in exercises.indexed) ...[
            if (index > 0) Divider(height: 1, thickness: .5, color: dividerColor),
            exercise(each),
          ],
        ],
      ),
    );
  }
}

/// An exercise's sets, the main ones apart from what follows them: "3 × 8–12",
/// or each set's own aim where they differ, then the lighter sets, the reps in
/// all and the rest, each its own line.
({String sets, List<String> then}) _sets(L copy, WorkoutExercise exercise) {
  final sets = exercise.toList();
  final main = sets.where((set) => set.target?.supplemental != true).toList();
  final lighter = sets.length - main.length;
  final aims = main.map((set) => _aim(copy, set.target)).toList();
  final first = aims.firstOrNull ?? '';

  return (
    sets: switch (aims.every((aim) => aim == first)) {
      true => copy.librarySets(main.length, first),
      false => aims.join(', '),
    },
    then: [
      if (lighter > 0) copy.libraryLighterSets(lighter),
      if (exercise.totalReps case final TargetRange total)
        copy.libraryTotalReps(switch (total) {
          TargetRange(isExact: true, :final min) => '${min.round()}',
          TargetRange(:final min, max: null) => '${min.round()}+',
          TargetRange(:final min, :final num max) => '${min.round()}–${max.round()}',
        }),
      if (exercise.rest case final int rest when rest > 0) copy.libraryRest(_clock(copy, rest)),
    ],
  );
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
