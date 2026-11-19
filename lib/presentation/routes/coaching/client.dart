part of 'coaching.dart';

/// One client on a phone (#559): who they are, why they may need a word, and
/// what they did, newest first. On a wide page the same view sits beside the
/// roster instead ([_ClientView]).
class ClientPage extends StatelessWidget {
  final String connectionId;

  /// Opens one of the client's workouts, target beside done.
  final ValueChanged<String> onOpenWorkout;

  /// Opens the client's copy of their program.
  final ValueChanged<String> onOpenProgram;

  /// Opens the conversation with them.
  final ValueChanged<String> onMessage;

  /// Opens the coach's notes on them.
  final ValueChanged<String> onNotes;

  /// Opens a workout to log for them (#560).
  final void Function(String connectionId, PastWorkout past) onLog;

  const new({
    super.key,
    required this.connectionId,
    required this.onOpenWorkout,
    required this.onOpenProgram,
    required this.onMessage,
    required this.onNotes,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final client = Roster.watch(context).client(connectionId);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (client) {
          final ClientSummary client => _clientName(l, client),
          null => '',
        }),
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: _ClientView(
            connectionId: connectionId,
            onOpenWorkout: onOpenWorkout,
            onOpenProgram: onOpenProgram,
            onMessage: onMessage,
            onNotes: onNotes,
            onLog: onLog,
          ),
        ),
      ),
    );
  }
}

/// A workout or a skip, in one list by when it happened.
sealed class _Entry {
  DateTime get at;
}

class _Trained implements _Entry {
  final Workout workout;

  const new(this.workout);

  @override
  DateTime get at => workout.start;
}

class _Skipped implements _Entry {
  final TrainingSkip skip;

  const new(this.skip);

  @override
  DateTime get at => skip.at;
}

class _ClientView extends StatefulWidget {
  final String connectionId;
  final ValueChanged<String> onOpenWorkout;
  final ValueChanged<String> onOpenProgram;
  final ValueChanged<String> onMessage;
  final ValueChanged<String> onNotes;
  final void Function(String connectionId, PastWorkout past) onLog;

  /// The pane beside the roster names the client itself; a page has its
  /// title for that.
  final Widget? leading;

  const new({
    super.key,
    required this.connectionId,
    required this.onOpenWorkout,
    required this.onOpenProgram,
    required this.onMessage,
    required this.onNotes,
    required this.onLog,
    this.leading,
  });

  @override
  State<_ClientView> createState() => _ClientViewState();
}

class _ClientViewState extends State<_ClientView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant _ClientView old) {
    super.didUpdateWidget(old);
    // after this build: reading notifies the roster this view is built from
    if (old.connectionId != widget.connectionId) WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final roster = Roster.of(context);
    // the row they were opened from may be stale, and opened from a link
    // the roster may never have been read
    final programs = ClientPrograms.of(context);
    // every client's at once, read the first time any is opened, where
    // notes can be sealed at all
    final notes = CoachNotes.of(context);
    if (DeviceKeys.of(context).supported && notes.status == .idle) unawaited(notes.load());
    final messages = Messages.of(context);
    var client = roster.client(widget.connectionId);
    if (client == null) {
      await roster.load();
      client = roster.client(widget.connectionId);
    }
    // opened from a link, someone no longer coached is only on the other list
    if (client == null && roster.formerStatus == .idle) {
      await roster.loadFormer();
      client = roster.client(widget.connectionId);
    }
    switch (client) {
      // no longer coached: their training isn't the coach's to read, only
      // the coach's own notes and what the two of them wrote
      case final ClientSummary client when _former(client):
        if (messages.status == .idle) await messages.load();
      case final ClientSummary client:
        await (roster.load(), roster.loadRecord(client.studentId), programs.loadManaged(client.studentId)).wait;
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final roster = Roster.watch(context);
    final client = roster.client(widget.connectionId);
    if (client == null) {
      return switch (roster.status) {
        .idle || .loading => const Center(child: CircularProgressIndicator.adaptive()),
        .failed => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.coachingRosterFailed,
          action: OutlinedButton(onPressed: _load, child: Text(l.retry)),
        ),
        .loaded => _Empty(icon: Icons.person_off_outlined, title: l.coachingClientGone),
      };
    }
    if (_former(client)) {
      return _FormerView(
        client: client,
        leading: widget.leading,
        onMessage: widget.onMessage,
        onNotes: widget.onNotes,
      );
    }
    final id = client.studentId;
    final workouts = roster.workoutsOf(id);
    final more = roster.hasMoreOf(id);
    // a skip older than the oldest workout read waits for that page
    final entries = <_Entry>[
      ...workouts.map(_Trained.new),
      ...roster
          .skipsOf(id)
          .where((skip) => !more || workouts.isEmpty || !skip.at.isBefore(workouts.last.start))
          .map(_Skipped.new),
    ]..sort((a, b) => b.at.compareTo(a.at));
    final status = roster.recordStatus(id);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400) roster.moreRecord(id);
        return false;
      },
      child: RefreshIndicator.adaptive(
        onRefresh: () => roster.loadRecord(id),
        child: ListView(
          padding: const .only(bottom: 24),
          children: [
            ?widget.leading,
            // a page names them in its title
            _ClientHeader(client: client, named: widget.leading != null),
            // their one conversation with the coach (#556), in Messages
            _MessagesTile(client: client, onTap: () => widget.onMessage(client.connectionId)),
            // the coach's own notes on them, which they never see (#556):
            // not where this device has nowhere to keep the keys
            if (DeviceKeys.of(context).supported)
              _NotesTile(connectionId: client.connectionId, onTap: () => widget.onNotes(client.connectionId)),
            // a session they trained together, logged as theirs (#560): while
            // they are a client, which a former one, on a page of their own,
            // is not
            _LogForTile(client: client, onLog: (past) => widget.onLog(client.connectionId, past)),
            // what they follow, and every copy the coach sent them, waiting
            // or not: the ones both of them edit (#558)
            for (final (id, name, waiting) in _programsOf(client, ClientPrograms.watch(context).managed(id)))
              ListTile(
                key: switch (id == client.programId) {
                  true => AppKeys.coachingClientProgram,
                  false => AppKeys.coachingClientCopy(id),
                },
                leading: const Icon(Icons.event_repeat_rounded),
                title: Text(name, maxLines: 1, overflow: .ellipsis),
                subtitle: switch (waiting) {
                  true => Text(l.coachingCopyWaiting),
                  false => null,
                },
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => widget.onOpenProgram(id),
              ),
            Padding(
              padding: const .fromLTRB(16, 16, 16, 4),
              child: Text(l.coachingClientWorkouts, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...switch ((status, entries)) {
              (.idle || .loading, []) => [
                const Padding(
                  padding: .all(24),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              ],
              (.failed, []) => [
                _Empty(
                  icon: Icons.cloud_off_rounded,
                  title: l.coachingClientRecordFailed,
                  action: OutlinedButton(onPressed: () => roster.loadRecord(id), child: Text(l.retry)),
                ),
              ],
              (_, []) => [
                _Empty(
                  icon: Icons.event_note_outlined,
                  title: l.coachingClientNothingYet,
                  body: l.coachingClientNothingYetBody,
                ),
              ],
              _ => [
                for (final entry in entries)
                  switch (entry) {
                    _Trained(:final workout) => _WorkoutTile(
                      workout: workout,
                      onTap: () => widget.onOpenWorkout(workout.id),
                    ),
                    _Skipped(:final skip) => ListTile(
                      key: AppKeys.coachingClientSkip,
                      leading: const Icon(Icons.redo_rounded),
                      title: Text(l.coachingClientSkipped),
                      subtitle: Text(DateFormat.MMMEd(l.localeName).format(skip.at.toLocal())),
                    ),
                  },
                if (more)
                  const Padding(
                    padding: .all(16),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// Who the client is to the coach: their photo and name, their program and
/// week, the last seven days, and why they may need a word.
class _ClientHeader extends StatelessWidget {
  final ClientSummary client;

  /// Whether to say who they are, where nothing above does.
  final bool named;

  /// No longer coached: said in place of their program, week and reasons.
  final bool former;

  const new({required this.client, this.named = false, this.former = false});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final reasons = _reasonsInWords(l, client);
    return Padding(
      // the right edge is the look button's, which someone gone has none of
      padding: .fromLTRB(16, 16, former ? 16 : 8, 0),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          Avatar(remote: client.avatar, radius: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              spacing: 6,
              children: [
                if (named) Text(_clientName(l, client), style: textTheme.titleLarge),
                ...switch (former) {
                  true => [
                    Text(
                      l.coachingClientFormer,
                      key: AppKeys.coachingClientFormer,
                      style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                  false => [
                    Text(_programLine(l, client), style: textTheme.bodyLarge),
                    _WeekDots(client: client),
                    if (reasons.isNotEmpty)
                      Text(reasons.join(' · '), style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary)),
                  ],
                },
              ],
            ),
          ),
          if (!former && _lookClears(client)) _MarkReviewed(client: client),
        ],
      ),
    );
  }
}

/// Someone the coach no longer coaches (#556): who they were, that they've
/// gone, and the way to what the coach still holds of them, their own notes
/// and the conversation. Nothing of their training is read: it's no longer
/// the coach's to see.
class _FormerView extends StatelessWidget {
  final ClientSummary client;
  final Widget? leading;
  final ValueChanged<String> onMessage;
  final ValueChanged<String> onNotes;

  const new({required this.client, required this.leading, required this.onMessage, required this.onNotes});

  @override
  Widget build(BuildContext context) {
    final notes = DeviceKeys.of(context).supported;
    return RefreshIndicator.adaptive(
      onRefresh: () => Future.wait([
        if (notes) CoachNotes.of(context).load(),
        Messages.of(context).load(),
      ]),
      child: ListView(
        padding: const .only(bottom: 24),
        children: [
          ?leading,
          _ClientHeader(client: client, named: leading != null, former: true),
          // an ended connection takes no new message: only one to read back
          if (_holdsConversation(context, client.connectionId))
            _MessagesTile(client: client, onTap: () => onMessage(client.connectionId)),
          if (notes) _NotesTile(connectionId: client.connectionId, onTap: () => onNotes(client.connectionId)),
        ],
      ),
    );
  }
}

/// Whether the conversation with [connectionId]'s person still holds a
/// message to read.
bool _holdsConversation(BuildContext context, String connectionId) {
  return Messages.watch(context).threadOf(connectionId)?.lastAt != null;
}

/// Whether a former client's page has anything to open: the coach's notes,
/// where keys can be kept, or a conversation to read back.
bool _formerOpens(BuildContext context, String connectionId) {
  return DeviceKeys.of(context).supported || _holdsConversation(context, connectionId);
}

/// The client's one conversation with the coach (#556), in Messages.
class _MessagesTile extends StatelessWidget {
  final ClientSummary client;
  final VoidCallback onTap;

  const new({required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListTile(
      key: AppKeys.coachingClientMessages,
      leading: const Icon(Icons.forum_outlined),
      title: Text(
        switch (client.name?.trim()) {
          final String name when name.isNotEmpty => l.messagesWith(name),
          _ => l.coachingMessages,
        },
        maxLines: 1,
        overflow: .ellipsis,
      ),
      trailing: switch (Messages.watch(context).threadOf(client.connectionId)?.unread ?? 0) {
        0 => const Icon(Icons.chevron_right_rounded),
        final int count => Badge(label: Text('$count', semanticsLabel: l.messagesUnread(count))),
      },
      onTap: onTap,
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const new({required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final note = switch (workout.note?.trim()) {
      final String note when note.isNotEmpty => note,
      _ => null,
    };
    final when = DateFormat.MMMEd(l.localeName).add_jm().format(workout.start.toLocal());
    return ListTile(
      key: AppKeys.coachingClientWorkout(workout.id),
      onTap: onTap,
      leading: const Icon(Icons.check_circle_outline_rounded),
      title: Text(workoutTitle(l, workout), maxLines: 1, overflow: .ellipsis),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text('$when · ${l.coachingClientExercises(workout.length)}'),
          if (note != null)
            Text(
              note,
              maxLines: 2,
              overflow: .ellipsis,
              style: textTheme.bodyMedium?.copyWith(fontStyle: .italic, color: colorScheme.onSurface),
            ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// The program [client] follows, then the coach's other copies of theirs,
/// each with whether it waits for them to start it.
List<(String id, String name, bool waiting)> _programsOf(ClientSummary client, List<Program> managed) {
  final following = switch (client) {
    ClientSummary(programId: final String id, programName: final String name) => (id, name, false),
    _ => null,
  };
  return [
    ?following,
    for (final copy in managed)
      if (copy.id case final String id when id != following?.$1) (id, copy.name, copy.waitingSince != null),
  ];
}

/// The way to the coach's notes on a client: the latest, or that only the
/// coach reads them.
class _NotesTile extends StatelessWidget {
  final String connectionId;
  final VoidCallback onTap;

  const new({required this.connectionId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final latest = CoachNotes.watch(context).on(connectionId).firstOrNull;
    return ListTile(
      key: AppKeys.coachingClientNotes,
      leading: const Icon(Icons.sticky_note_2_outlined),
      title: Text(l.coachingNotes),
      subtitle: Text(
        switch (latest?.text?.trim()) {
          final String text when text.isNotEmpty => text,
          _ => l.coachingNotesOnlyYou,
        },
        maxLines: 1,
        overflow: .ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// What is open beside the roster: a client, and one of their workouts over
/// them when that is what was opened, from Activity or the client's own list,
/// by the tap that opened it.
typedef _Opened = ({String connectionId, String? workoutId, int tap});

/// A client beside the roster (#685): their view, with what opens from it
/// opening in the pane too, so the roster stays where it was. A workout
/// opened from Activity lands over its client's view, and Back goes there.
class _ClientPane extends StatefulWidget {
  final _Opened opened;
  final ValueChanged<String> onOpenProgram;
  final ValueChanged<String> onMessage;
  final ValueChanged<String> onNotes;
  final void Function(String connectionId, PastWorkout past) onLog;
  final VoidCallback onClose;

  const new({
    super.key,
    required this.opened,
    required this.onOpenProgram,
    required this.onMessage,
    required this.onNotes,
    required this.onLog,
    required this.onClose,
  });

  @override
  State<_ClientPane> createState() => _ClientPaneState();
}

class _ClientPaneState extends State<_ClientPane> {
  final _navigator = GlobalKey<NavigatorState>();

  Route<void> _review(String workoutId) {
    final connectionId = widget.opened.connectionId;
    return MaterialPageRoute(
      builder: (_) => WorkoutReviewPage(
        key: ValueKey(workoutId),
        connectionId: connectionId,
        workoutId: workoutId,
        onMessage: () => widget.onMessage(connectionId),
      ),
    );
  }

  /// The client's own view, at the bottom of the pane: built once, reading
  /// the pane's widget and words as they are now each time it builds.
  Route<void> _client() {
    return MaterialPageRoute(
      builder: (context) => Material(
        child: _ClientView(
          key: AppKeys.coachingClientPane,
          connectionId: widget.opened.connectionId,
          onOpenWorkout: (workoutId) => _navigator.currentState?.push(_review(workoutId)),
          onOpenProgram: (programId) => widget.onOpenProgram(programId),
          onMessage: (id) => widget.onMessage(id),
          onNotes: (id) => widget.onNotes(id),
          onLog: (id, past) => widget.onLog(id, past),
          leading: Align(
            alignment: .centerRight,
            child: IconButton(
              key: AppKeys.coachingClientClose,
              tooltip: L.of(context).coachingClientClose,
              onPressed: () => widget.onClose(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back on Android steps back inside the pane before it leaves the page
    return NavigatorPopHandler(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateInitialRoutes: (_, _) => [
          _client(),
          if (widget.opened.workoutId case final String workoutId) _review(workoutId),
        ],
      ),
    );
  }
}
