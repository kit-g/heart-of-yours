part of 'coaching.dart';

/// A client's copy of a program, which both of them edit (#558): its
/// sessions, a save of the coach's that didn't land with both versions to
/// pick from, and every change either of them made, each one that can be put
/// back.
class ClientProgramPage extends StatefulWidget {
  final String connectionId;
  final String programId;

  /// Opens the template editor on the session [ClientPrograms] is drafting.
  final void Function({required bool isNew}) onEditSession;

  const new({super.key, required this.connectionId, required this.programId, required this.onEditSession});

  @override
  State<ClientProgramPage> createState() => _ClientProgramPageState();
}

class _ClientProgramPageState extends State<ClientProgramPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final roster = Roster.of(context);
    final programs = ClientPrograms.of(context);
    if (roster.client(widget.connectionId) == null) await roster.load();
    if (roster.client(widget.connectionId) case final ClientSummary client) {
      await programs.open(client.studentId, widget.programId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final programs = ClientPrograms.watch(context);
    final client = Roster.watch(context).client(widget.connectionId);
    final view = programs.view(widget.programId);
    return Scaffold(
      appBar: AppBar(title: Text(view?.program.name ?? '')),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: switch ((programs.status(widget.programId), view, client)) {
            (_, final CoachProgramView view, final ClientSummary client) => RefreshIndicator.adaptive(
              onRefresh: _load,
              child: _CopyView(view: view, client: client, onEditSession: widget.onEditSession),
            ),
            (.failed, _, _) => _Empty(
              icon: Icons.cloud_off_rounded,
              title: l.coachingCopyFailed,
              action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
            ),
            _ => const Center(child: CircularProgressIndicator.adaptive()),
          },
        ),
      ),
    );
  }
}

class _CopyView extends StatelessWidget {
  final CoachProgramView view;
  final ClientSummary client;
  final void Function({required bool isNew}) onEditSession;

  const new({required this.view, required this.client, required this.onEditSession});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = ClientPrograms.watch(context);
    final program = view.program;
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final week = switch (view.position['week']) {
      final int week => week,
      _ => 1,
    };
    final changes = programs.changes(program.id!);
    // their own program they show, and only the coach's copy is the coach's to change
    final mayChange = programs.mayChange(program.id!);

    void edit(Template? session) {
      programs.editSession(client.studentId, program.id!, session: session);
      onEditSession(isNew: session == null);
    }

    return ListView(
      padding: const .only(bottom: 32),
      children: [
        Padding(
          padding: const .fromLTRB(16, 8, 16, 0),
          child: Text(switch (program.weeks) {
            final int weeks => l.coachingClientWeek(program.name, week, weeks),
            null => l.coachingClientWeekOpen(program.name, week),
          }, style: muted),
        ),
        // a copy that stopped being the coach's says why in its card
        if (!mayChange && programs.conflict(program.id!)?.refused != true)
          Padding(
            padding: const .fromLTRB(16, 12, 16, 0),
            child: Text(l.coachingCopyReadOnly, style: textTheme.bodyMedium),
          ),
        if (programs.conflict(program.id!) case final ProgramConflict conflict)
          ProgramConflictCard(
            conflict: conflict,
            name: _clientName(l, client),
            onKeepTheirs: () => programs.dropMine(conflict.programId),
            onKeepMine: () => programs.keepMine(client.studentId, conflict.programId),
          ),
        Padding(
          padding: const .fromLTRB(16, 16, 16, 4),
          child: Text(l.programSessions, style: textTheme.titleMedium),
        ),
        for (final session in view.sessions)
          ListTile(
            key: AppKeys.coachingCopySession(session.id),
            title: Text(session.name ?? '', maxLines: 1, overflow: .ellipsis),
            subtitle: Text(
              session.map((exercise) => exercise.exercise.name).join(', '),
              maxLines: 1,
              overflow: .ellipsis,
            ),
            onTap: switch (mayChange) {
              true => () => edit(session),
              false => null,
            },
            trailing: switch (mayChange) {
              true => Builder(
                builder: (context) => IconButton(
                  key: AppKeys.coachingCopySessionMenu(session.id),
                  tooltip: l.coachingCopyMenu,
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => _sessionMenu(context, session),
                ),
              ),
              false => null,
            },
          ),
        if (mayChange)
          ListTile(
            key: AppKeys.coachingCopyAddSession,
            leading: Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
            title: Text(l.programAddSession, style: TextStyle(color: colorScheme.primary)),
            onTap: () => edit(null),
          ),
        Padding(
          padding: const .fromLTRB(16, 24, 16, 4),
          child: Text(l.coachingCopyHistory, style: textTheme.titleMedium),
        ),
        if (changes.isEmpty)
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: Text(l.coachingCopyNoHistory, style: muted),
          ),
        for (final change in changes) _ChangeTile(change: change, client: client, mayPutBack: mayChange),
      ],
    );
  }

  Future<void> _sessionMenu(BuildContext context, Template session) async {
    final l = L.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    final position = switch ((box, overlay)) {
      (final RenderBox box, final RenderBox overlay) => RelativeRect.fromRect(
        box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
        Offset.zero & overlay.size,
      ),
      _ => RelativeRect.fill,
    };
    final remove = await showMenu<bool>(
      context: context,
      position: position,
      items: [PopupMenuItem(value: true, child: Text(l.coachingCopyRemoveSession))],
    );
    if (remove != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // no asking first: the removal is in the history, and puts back
      await ClientPrograms.of(context).deleteSession(client.studentId, view.program.id!, session.id);
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      messenger.snack(l.coachingCopyRemoveFailed);
    }
  }
}

/// One change to the copy: who, what, when, and the way to put it back.
class _ChangeTile extends StatelessWidget {
  final ProgramChange change;
  final ClientSummary client;
  final bool mayPutBack;

  const new({required this.change, required this.client, required this.mayPutBack});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final who = switch (change.actorId) {
      final String id when id == client.studentId => _clientName(l, client),
      _ => l.coachingCopyYou,
    };
    final what = describeProgramChange(l, change, who: who);
    final when = DateFormat.MMMEd(l.localeName).add_jm().format(change.at.toLocal());
    return ListTile(
      key: AppKeys.coachingCopyChange(change.id),
      title: Text(what),
      subtitle: Text([when, if (change.stale) l.coachingCopyOldApp].join(' · ')),
      trailing: switch (mayPutBack) {
        true => TextButton(
          key: AppKeys.coachingCopyPutBack(change.id),
          // the theme's compact text button is under the tap-target minimum
          style: TextButton.styleFrom(minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension)),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await ClientPrograms.of(context).revert(client.studentId, change.programId, change);
            } catch (error, stacktrace) {
              reportToSentry(error, stacktrace: stacktrace);
              messenger.snack(l.coachingCopyPutBackFailed);
            }
          },
          child: Text(l.coachingCopyPutBack),
        ),
        false => null,
      },
    );
  }
}
