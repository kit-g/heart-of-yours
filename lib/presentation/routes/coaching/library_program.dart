part of 'coaching.dart';

/// How wide a library program's page grows: sessions are a column of names,
/// and past this they only drift from their buttons.
const _libraryProgramWidth = 640.0;

/// What the menu on a library program's page does.
enum _ProgramAction { edit, delete }

/// One of a coach's library programs (#557): what it is, its sessions in
/// order, who has a copy and of which version, and sending it to more.
///
/// Its sessions are edited in the template editor, its own fields in the
/// program form: the same screens the coach's own programs use, on the
/// library's copy.
class CoachProgramPage extends StatefulWidget {
  final String programId;

  /// Opens the form on the program's own fields.
  final VoidCallback onEdit;

  /// Opens the template editor on the session [CoachLibrary.editable] holds.
  final void Function({required bool isNew}) onEditSession;

  /// Leaves the page once the program is deleted.
  final VoidCallback onGone;

  const new({
    super.key,
    required this.programId,
    required this.onEdit,
    required this.onEditSession,
    required this.onGone,
  });

  @override
  State<CoachProgramPage> createState() => _CoachProgramPageState();
}

class _CoachProgramPageState extends State<CoachProgramPage> {
  final _status = ValueNotifier(CoachingStatus.idle);
  final _holders = ValueNotifier<(CoachingStatus, List<CoachProgramHolder>)>((.idle, const []));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _open();
      _readHolders();
      // the names of the clients it may go to, and who holds it
      final roster = Roster.of(context);
      if (roster.status == .idle) roster.load();
    });
  }

  @override
  void dispose() {
    _status.dispose();
    _holders.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _status.value = .loading;
    try {
      await CoachLibrary.of(context).open(widget.programId);
      if (mounted) _status.value = .loaded;
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      if (mounted) _status.value = .failed;
    }
  }

  Future<void> _readHolders() async {
    _holders.value = (.loading, _holders.value.$2);
    try {
      final holders = await CoachLibrary.of(context).holders(widget.programId);
      if (mounted) _holders.value = (.loaded, holders);
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      if (mounted) _holders.value = (.failed, _holders.value.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final program = CoachLibrary.watch(context).lookup(widget.programId);
    return ValueListenableBuilder(
      valueListenable: _status,
      builder: (context, status, _) => switch ((program, status)) {
        (final CoachLibraryProgram program, _) => _page(context, program),
        (null, .failed) => Scaffold(
          appBar: AppBar(),
          body: _Empty(
            icon: Icons.cloud_off_rounded,
            title: l.coachingProgramOpenFailed,
            action: OutlinedButton(onPressed: _open, child: Text(l.retry)),
          ),
        ),
        (null, _) => Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator.adaptive()),
        ),
      },
    );
  }

  Widget _page(BuildContext context, CoachLibraryProgram program) {
    final l = L.of(context);
    final library = CoachLibrary.watch(context);
    final unsaved = library.unsaved(program.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(program.program.name),
        actions: [
          // a program with nothing in it, or not yet on the server, has
          // nothing to send: what went would be an older version
          if (program.sessions.isNotEmpty && !unsaved)
            IconButton(
              key: AppKeys.coachingSendProgram,
              tooltip: l.coachingProgramSend,
              onPressed: () => _send(context, program),
              icon: const Icon(Icons.send_rounded),
            ),
          PopupMenuButton<_ProgramAction>(
            key: AppKeys.coachingProgramMenu,
            tooltip: l.coachingProgramOptions,
            onSelected: (action) {
              switch (action) {
                case .edit:
                  widget.onEdit();
                case .delete:
                  _delete(context, program);
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<_ProgramAction>>[
              PopupMenuItem(value: .edit, child: Text(l.editProgram)),
              PopupMenuItem(key: AppKeys.coachingDeleteProgram, value: .delete, child: Text(l.programDelete)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: .topCenter,
            child: SizedBox(
              width: min(constraints.maxWidth, _libraryProgramWidth),
              child: ReorderableListView(
                padding: const .only(bottom: 24),
                header: _Header(program: program, unsaved: unsaved),
                footer: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    Padding(
                      padding: const .fromLTRB(16, 8, 16, 24),
                      child: Align(
                        alignment: .centerLeft,
                        child: OutlinedButton.icon(
                          key: AppKeys.coachingAddSession,
                          onPressed: () {
                            library.editSession(program);
                            widget.onEditSession(isNew: true);
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: Text(l.programAddSession),
                        ),
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _holders,
                      builder: (context, holders, _) {
                        return _Holders(holders: holders, latest: program.version, onRetry: _readHolders);
                      },
                    ),
                  ],
                ),
                onReorderItem: (from, to) => library.moveSession(program, from, to),
                children: [
                  for (final session in program.sessions)
                    _SessionTile(
                      key: AppKeys.coachingLibrarySession(session.id),
                      session: session,
                      onTap: () {
                        library.editSession(program, session: session);
                        widget.onEditSession(isNew: false);
                      },
                      onRemove: () => _remove(context, program, session),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Takes [session] out, with an undo that puts the program back as it was.
  Future<void> _remove(BuildContext context, CoachLibraryProgram program, Template session) async {
    final l = L.of(context);
    final library = CoachLibrary.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await library.removeSession(program, session);
    messenger
      ..clearSnackBars()
      ..snack(
        l.programSessionRemoved(_sessionName(l, session), program.program.name),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () {
            if (library.lookup(program.id) case final CoachLibraryProgram now) {
              library.save(now.copyWith(sessions: program.sessions));
            }
          },
        ),
      );
  }

  Future<void> _delete(BuildContext context, CoachLibraryProgram program) async {
    final l = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final library = CoachLibrary.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showBrandedDialog<bool>(
      context,
      title: Text(l.programDeleteTitle(program.program.name), textAlign: .center),
      content: Text(l.coachingProgramDeleteBody, textAlign: .center),
      actions: [
        Builder(
          builder: (context) {
            void answer({required bool sure}) => Navigator.of(context, rootNavigator: true).pop(sure);
            return Column(
              spacing: 8,
              children: [
                PrimaryButton.wide(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  onPressed: () => answer(sure: false),
                  child: Center(child: Text(l.cancel)),
                ),
                PrimaryButton.wide(
                  key: AppKeys.coachingDeleteConfirm,
                  backgroundColor: colorScheme.errorContainer,
                  onPressed: () => answer(sure: true),
                  child: Center(
                    child: Text(l.delete, style: TextStyle(color: colorScheme.onErrorContainer)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
    if (sure != true) return;
    try {
      await library.delete(program.id);
      widget.onGone();
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      messenger.snack(l.coachingProgramDeleteFailed);
    }
  }

  /// Picks the clients, sends, and says how it went: who it reached, and
  /// each one it didn't, with why.
  Future<void> _send(BuildContext context, CoachLibraryProgram program) async {
    final l = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final library = CoachLibrary.of(context);
    final roster = Roster.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showBrandedDialog<Set<String>>(
      context,
      title: Text(l.coachingProgramSend, textAlign: .center),
      icon: Icon(Icons.send_rounded, color: colorScheme.onPrimaryContainer),
      content: _SendPicker(holders: _holders.value.$2),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      final deliveries = await library.send(program.id, picked);
      String name(String connectionId) {
        return switch (roster.clients.where((each) => each.connectionId == connectionId).firstOrNull) {
          final ClientSummary client => _clientName(l, client),
          null => l.coachingClientUnnamed,
        };
      }

      final reached = deliveries.where((each) => each.delivered).length;
      final lines = [
        if (reached > 0) l.coachingProgramSent(reached),
        for (final each in deliveries.where((each) => !each.delivered))
          l.coachingProgramNotSent(name(each.connectionId), switch (DeliveryRefusal.of(each.reason)) {
            .notCoaching => l.coachingRefusalNotCoaching,
            .programLimit => l.coachingRefusalProgramLimit,
            .unknownExercise => l.coachingRefusalUnknownExercise,
            null => l.coachingRefusalOther,
          }),
      ];
      messenger.snack(lines.join('\n'));
      if (mounted) _readHolders();
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      messenger.snack(l.coachingProgramSendFailed);
    }
  }
}

/// What a library program is, above its sessions: how often and how long,
/// its note, and a word when its last change hasn't reached the server.
class _Header extends StatelessWidget {
  final CoachLibraryProgram program;
  final bool unsaved;

  const new({required this.program, required this.unsaved});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final Program(:perWeek, :weeks, :note) = program.program;
    final facts = [
      if (perWeek case final int perWeek) l.coachingProgramPerWeek(perWeek),
      switch (weeks) {
        final int weeks => l.programWeeks(weeks),
        null => l.programOngoing,
      },
    ];
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        if (unsaved)
          Card(
            margin: const .fromLTRB(16, 8, 16, 0),
            color: colorScheme.errorContainer,
            child: Padding(
              padding: const .fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.coachingProgramUnsaved,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    key: AppKeys.coachingUnsavedRetry,
                    onPressed: () => CoachLibrary.of(context).retry(program.id),
                    child: Text(l.retry),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const .fromLTRB(16, 16, 16, 0),
          child: Text(facts.join(' · '), style: textTheme.bodyLarge),
        ),
        if (note case final String note when note.trim().isNotEmpty)
          Padding(
            padding: const .fromLTRB(16, 4, 16, 0),
            child: Text(note, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        Padding(
          padding: const .fromLTRB(16, 24, 16, 4),
          child: Text(l.programSessions, style: textTheme.titleSmall),
        ),
        if (program.sessions.isEmpty)
          Padding(
            padding: const .fromLTRB(16, 4, 16, 0),
            child: Text(
              l.coachingProgramNoSessions,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Template session;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const new({super.key, required this.session, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return ListTile(
      title: Text(_sessionName(l, session), maxLines: 1, overflow: .ellipsis),
      subtitle: switch (session.map((each) => each.exercise.name).join(', ')) {
        '' => null,
        final names => Text(
          names,
          maxLines: 2,
          overflow: .ellipsis,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      },
      onTap: onTap,
      trailing: IconButton(
        key: AppKeys.coachingRemoveSession(session.id),
        tooltip: l.programRemoveSession,
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
    );
  }
}

/// Who holds a copy, and whether theirs is the latest version.
class _Holders extends StatelessWidget {
  final (CoachingStatus, List<CoachProgramHolder>) holders;
  final int latest;
  final VoidCallback onRetry;

  const new({required this.holders, required this.latest, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final roster = Roster.watch(context);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    String name(CoachProgramHolder holder) {
      final client = roster.clients.where((each) => each.connectionId == holder.connectionId).firstOrNull;
      return switch ((holder.studentName?.trim(), client)) {
        (final String name, _) when name.isNotEmpty => name,
        (_, final ClientSummary client) => _clientName(l, client),
        _ => l.coachingClientUnnamed,
      };
    }

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(16, 8, 16, 4),
          child: Text(l.coachingProgramHolders, style: textTheme.titleSmall),
        ),
        ...switch (holders) {
          (.idle || .loading, []) => [
            const Padding(
              padding: .all(16),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ],
          (.failed, []) => [
            ListTile(
              title: Text(l.coachingProgramHoldersFailed, style: muted),
              trailing: TextButton(onPressed: onRetry, child: Text(l.retry)),
            ),
          ],
          (_, []) => [
            Padding(
              padding: const .symmetric(horizontal: 16),
              child: Text(l.coachingProgramNoHolders, style: muted),
            ),
          ],
          (_, final holders) => [
            for (final holder in holders)
              ListTile(
                key: AppKeys.coachingHolder(holder.connectionId),
                leading: Avatar(remote: holder.studentAvatar, radius: 20),
                title: Text(name(holder), maxLines: 1, overflow: .ellipsis),
                subtitle: Text(switch (holder.version) {
                  final version when version < latest => l.coachingProgramHolderBehind(version, latest),
                  final version => l.coachingProgramHolderVersion(version),
                }),
              ),
          ],
        },
      ],
    );
  }
}

/// The coach's clients to send a program to. One who holds it already is
/// greyed, with which version: sending again would answer their copy.
class _SendPicker extends StatefulWidget {
  final List<CoachProgramHolder> holders;

  const new({required this.holders});

  @override
  State<_SendPicker> createState() => _SendPickerState();
}

class _SendPickerState extends State<_SendPicker> {
  final _picked = ValueNotifier(<String>{});

  @override
  void dispose() {
    _picked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final roster = Roster.watch(context);
    final clients = roster.clients.where((each) => each.status != 'severed').toList();
    final held = {for (final holder in widget.holders) holder.connectionId: holder.version};
    return switch ((roster.status, clients)) {
      (.idle || .loading, []) => const Padding(
        padding: .all(24),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      (.failed, []) => Column(
        mainAxisSize: .min,
        children: [
          Text(l.coachingRosterFailed, textAlign: .center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: roster.load, child: Text(l.retry)),
        ],
      ),
      (_, []) => Text(l.coachingProgramNoClients, textAlign: .center),
      _ => ValueListenableBuilder(
        valueListenable: _picked,
        builder: (context, picked, _) => Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    for (final client in clients)
                      CheckboxListTile(
                        key: AppKeys.coachingSendTo(client.connectionId),
                        contentPadding: const .symmetric(horizontal: 4),
                        secondary: Avatar(remote: client.avatar, radius: 18),
                        title: Text(_clientName(l, client), maxLines: 1, overflow: .ellipsis),
                        subtitle: switch (held[client.connectionId]) {
                          final int version => Text(l.coachingProgramHasIt(version)),
                          null => null,
                        },
                        value: held.containsKey(client.connectionId) || picked.contains(client.connectionId),
                        onChanged: switch (held.containsKey(client.connectionId)) {
                          true => null,
                          false => (on) => _picked.value = switch (on) {
                            true => {...picked, client.connectionId},
                            _ => {...picked}..remove(client.connectionId),
                          },
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton.wide(
              key: AppKeys.coachingSendConfirm,
              onPressed: switch (picked) {
                Set(isEmpty: true) => null,
                _ => () => Navigator.of(context, rootNavigator: true).pop(picked),
              },
              child: Center(
                child: Text(switch (picked.length) {
                  0 => l.coachingProgramSend,
                  final count => l.coachingProgramSendTo(count),
                }),
              ),
            ),
          ],
        ),
      ),
    };
  }
}

String _sessionName(L l, Template session) {
  return switch (session.name?.trim()) {
    final String name when name.isNotEmpty => name,
    _ => l.template,
  };
}
