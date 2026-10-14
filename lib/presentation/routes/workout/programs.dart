part of 'workout.dart';

/// What a session is called on screen: its template's name, or the word for a
/// template while it has none.
String _sessionName(L copy, Template template) {
  return switch (template.name) {
    final String name when name.isNotEmpty => name,
    _ => copy.template,
  };
}

extension on Templates {
  /// [program]'s sessions in its order. One whose template this device has not
  /// read yet is left out rather than shown as a blank.
  List<Template> sessionsOf(Program program) {
    final byId = {for (final template in this) template.id: template};
    return program.sessions.map((id) => byId[id]).nonNulls.toList();
  }

  /// The folders a program can be made from (#348): ones holding templates,
  /// none of which already belongs to a program. A template is one program's
  /// session at most, so a second program from the same folder would quietly
  /// take the first one's sessions.
  List<TemplateFolder> get programFolders {
    return folders.where((folder) {
      final inside = templatesIn(folder);
      return inside.isNotEmpty && inside.every((template) => template.programId == null);
    }).toList();
  }
}

/// Programs on the Workout tab (#347): a band per program being followed, the
/// ones stopped beneath them, and the way to make one from a folder.
///
/// Off, unanswered or declined, it is nothing at all: the tab is the 1.13 tab
/// (#345). On with nothing to show and no folder to make one from, it is
/// nothing too, rather than a header over an apology.
class _ProgramsSection extends StatelessWidget {
  final void Function(Program) onOpen;
  final void Function(TemplateFolder) onFromFolder;
  final void Function(Template) onStart;

  const new({
    required this.onOpen,
    required this.onFromFolder,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (!Preferences.watch(context).isOn(.programs)) return const SliverToBoxAdapter();

    final programs = Programs.watch(context);
    final templates = Templates.watch(context);
    final following = programs.following.toList();
    final stopped = programs.all.where((program) => program.archived).toList();
    final folders = templates.programFolders;
    if (following.isEmpty && stopped.isEmpty && folders.isEmpty) return const SliverToBoxAdapter();

    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final now = DateTime.now();
    final firstWeekday = firstWeekdayOf(context);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const .symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(copy.programs, style: textTheme.headlineSmall),
                  if (folders.isNotEmpty) _FromFolderButton(folders: folders, onPick: onFromFolder),
                ],
              ),
            ),
            if (following.isEmpty && stopped.isEmpty)
              Padding(
                padding: const .only(bottom: 8),
                child: Text(
                  copy.programsEmpty,
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            if (following.isNotEmpty)
              // The bands measure the room this section got: a phone stacks
              // them, a tablet sets them side by side rather than stretching
              // one across 1100pt
              LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 8.0;
                  final width = constraints.maxWidth;
                  final columns = columnsFor(width, maxExtent: _bandMaxWidth);
                  final band = (width - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final (program, position) in [
                        for (final program in following)
                          (program, programs.position(program, now: now, firstWeekday: firstWeekday)),
                      ])
                        SizedBox(
                          width: band,
                          child: _ProgramBand(
                            program: program,
                            position: position,
                            sessions: templates.sessionsOf(program),
                            skipped: programs.skippedIn(program, position),
                            onOpen: () => onOpen(program),
                            onStart: onStart,
                          ),
                        ),
                    ],
                  );
                },
              ),
            for (final program in stopped) _StoppedProgram(program: program, onOpen: () => onOpen(program)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The widest a band gets before the section adds a column beside it.
const _bandMaxWidth = 520.0;

/// "From a folder": the folders a program can be made from, as a menu.
class _FromFolderButton extends StatelessWidget {
  final List<TemplateFolder> folders;
  final void Function(TemplateFolder) onPick;

  const new({required this.folders, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final copy = L.of(context);
    return PopupMenuButton<TemplateFolder>(
      key: AppKeys.programsFromFolder,
      tooltip: copy.programsFromFolder,
      onSelected: onPick,
      constraints: const BoxConstraints.tightFor(width: 224),
      itemBuilder: (_) {
        return [
          for (final folder in folders)
            PopupMenuItem<TemplateFolder>(
              value: folder,
              child: Row(
                spacing: 8,
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: colorScheme.outline),
                  Expanded(
                    child: Text(folder.name, style: textTheme.titleSmall, maxLines: 1, overflow: .ellipsis),
                  ),
                ],
              ),
            ),
        ];
      },
      // drawn like the "+ Template" button beside Templates below, which is
      // what it is the counterpart of
      child: Container(
        // the header row's own padding already insets it, as it does "+ Template"
        margin: const .symmetric(vertical: 6),
        padding: const .symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: const .all(.circular(8)),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 4,
          children: [
            Icon(Icons.event_repeat_rounded, size: 18, color: colorScheme.onSecondaryContainer),
            Text(
              copy.programsFromFolder,
              style: textTheme.labelLarge?.copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

/// One program as the Workout tab shows it: where you are, this cycle's
/// sessions, this week against the target, and the next session to start.
///
/// The week count encourages and never accuses: "1 of 3", and a paused
/// program shows no count at all, so being ill never reads as falling behind.
class _ProgramBand extends StatelessWidget {
  final Program program;
  final ProgramPosition position;
  final List<Template> sessions;

  /// The sessions this cycle counts done by "Not today" (#312).
  final Set<String> skipped;
  final VoidCallback onOpen;
  final void Function(Template) onStart;

  const new({
    required this.program,
    required this.position,
    required this.sessions,
    required this.skipped,
    required this.onOpen,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final ProgramPosition(:done, :next, :paused, :finished, :thisWeek) = position;
    final upNext = sessions.where((session) => session.id == next).firstOrNull;
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Material(
      key: AppKeys.programBand(program.id),
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: dividerColor, width: .5),
        borderRadius: const .all(.circular(12)),
      ),
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const .all(12),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(program.name, style: textTheme.titleMedium, maxLines: 1, overflow: .ellipsis),
                  ),
                  Text(_status(copy, program, position), style: muted),
                ],
              ),
              if (!finished && sessions.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final session in sessions)
                      _SessionChip(
                        name: _sessionName(copy, session),
                        state: switch (session.id) {
                          final id when skipped.contains(id) => .skipped,
                          final id when done.contains(id) => .done,
                          final id when id == next => .next,
                          _ => .ahead,
                        },
                      ),
                  ],
                ),
              if (!finished)
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: switch ((program.perWeek, paused)) {
                        (final int target, false) => Text(copy.programThisWeek(thisWeek, target), style: muted),
                        _ => const SizedBox.shrink(),
                      },
                    ),
                    // nothing is due while paused, so there is nothing to set aside
                    if ((upNext, paused) case (final Template session, false))
                      TextButton(
                        key: AppKeys.programNotToday(program.id),
                        onPressed: () => _notToday(context, program, session, fromBand: true),
                        child: Text(copy.programNotToday),
                      ),
                    // a paused program can still be started: a program workout
                    // resumes it, so the button is never a dead end
                    if (upNext case final Template session)
                      Flexible(
                        child: PrimaryButton.shrunk(
                          key: AppKeys.programStart(program.id),
                          onPressed: () => onStart(session),
                          child: Text(
                            copy.programStartSession(_sessionName(copy, session)),
                            maxLines: 1,
                            overflow: .ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where [program] stands, in a word or two: finished, paused, or its week.
String _status(L copy, Program program, ProgramPosition position) {
  return switch ((position, program.weeks)) {
    (ProgramPosition(finished: true), _) => copy.programFinished,
    (ProgramPosition(paused: true), _) => copy.programPaused,
    (ProgramPosition(:final week), final int weeks) => copy.programWeekOf(week, weeks),
    (ProgramPosition(:final week), null) => copy.programWeek(week),
  };
}

/// "Not today" (#312): sets [session] aside at once, with an Undo beside it.
/// One tap and done: no question, no reason asked for, nothing about a streak.
Future<void> _notToday(BuildContext context, Program program, Template session, {required bool fromBand}) async {
  final copy = L.of(context);
  final programs = Programs.of(context);
  final analytics = Analytics.of(context);
  final messenger = ScaffoldMessenger.of(context);

  analytics.programSkipped(fromBand: fromBand);
  final skip = await programs.skip(program, session: session.id);
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(copy.programSkipped(_sessionName(copy, session))),
        action: SnackBarAction(
          label: copy.undo,
          onPressed: () {
            analytics.programUnskipped();
            programs.unskip(skip);
          },
        ),
      ),
    );
}

enum _SessionState { done, skipped, next, ahead }

/// A session in a band's strip: done in this cycle, up next, or still ahead.
class _SessionChip extends StatelessWidget {
  final String name;
  final _SessionState state;

  /// What a session the cycle is past wears: a tick, or the arrow of one
  /// stepped over.
  static const _marks = {_SessionState.done: Icons.check_rounded, _SessionState.skipped: Icons.redo_rounded};

  const new({required this.name, required this.state});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.labelMedium;

    final (Color? fill, BorderSide side, Color ink) = switch (state) {
      .done || .skipped => (colorScheme.surfaceContainerHighest, BorderSide.none, colorScheme.onSurfaceVariant),
      .next => (null, BorderSide(color: colorScheme.primary, width: 1.5), colorScheme.onSurface),
      .ahead => (null, BorderSide(color: colorScheme.outlineVariant), colorScheme.onSurfaceVariant),
    };

    return Semantics(
      label: switch (state) {
        .done => copy.programSessionDone(name),
        .skipped => copy.programSessionSkipped(name),
        .next => copy.programSessionNext(name),
        .ahead => name,
      },
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: StadiumBorder(side: side),
          ),
          child: Padding(
            padding: const .symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: .min,
              spacing: 4,
              children: [
                if (_SessionChip._marks[state] case final IconData icon) Icon(icon, size: 14, color: ink),
                Flexible(
                  child: Text(
                    name,
                    style: style?.copyWith(color: ink),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A program the user stopped following: a line under the bands, so the way
/// back to it ("Follow again" on its page) is never lost.
class _StoppedProgram extends StatelessWidget {
  final Program program;
  final VoidCallback onOpen;

  const new({required this.program, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    return InkWell(
      onTap: onOpen,
      borderRadius: const .all(.circular(8)),
      child: Padding(
        padding: const .symmetric(horizontal: 4, vertical: 12),
        child: Row(
          spacing: 8,
          children: [
            Expanded(
              child: Text(program.name, style: muted, maxLines: 1, overflow: .ellipsis),
            ),
            Text(L.of(context).programStopped, style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
            Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

/// The Programs offer's slot, under the example templates (#345): the one ask,
/// the one notice after a no, or nothing.
///
/// Offered only where saying yes leads somewhere: a folder of templates a
/// program can be made from. A yes with nothing to make a program of would be a
/// switch with nothing behind it.
class _ProgramsOfferSlot extends StatelessWidget {
  static const _feature = Feature.programs;

  const new();

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final templates = Templates.watch(context);
    final copy = L.of(context);

    final Widget? child = switch (preferences) {
      _ when preferences.isOn(_feature) => null,
      _ when preferences.owesDeclineNotice(_feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(_feature),
      ),
      _ when preferences.shouldOffer(_feature) && templates.programFolders.isNotEmpty => FeatureOffer(
        key: AppKeys.programsOffer,
        acceptKey: AppKeys.programsAccept,
        declineKey: AppKeys.programsDecline,
        icon: Icons.event_repeat_rounded,
        title: copy.programs,
        body: copy.programsOfferBody,
        onAnswer: (yes) => preferences.answerOffer(_feature, yes: yes),
        onShown: () => preferences.markOffered(_feature),
      ),
      _ => null,
    };

    return SliverToBoxAdapter(
      child: switch (child) {
        Widget child => Padding(
          padding: const .fromLTRB(8, 8, 8, 16),
          child: child,
        ),
        null => const SizedBox.shrink(),
      },
    );
  }
}

/// A Programs page with the switch turned off under it (#345). Off is the app
/// as if Programs had never been built, which has no such page, so it leaves
/// for the tab it was opened from rather than stay on a page that should not
/// exist.
class _ProgramsOnly extends StatefulWidget {
  final Widget child;

  const new({required this.child});

  @override
  State<_ProgramsOnly> createState() => _ProgramsOnlyState();
}

class _ProgramsOnlyState extends State<_ProgramsOnly> {
  late final Preferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = Preferences.of(context)..addListener(_onPreferences);
  }

  @override
  void dispose() {
    _preferences.removeListener(_onPreferences);
    super.dispose();
  }

  void _onPreferences() {
    if (!mounted || _preferences.isOn(.programs)) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
