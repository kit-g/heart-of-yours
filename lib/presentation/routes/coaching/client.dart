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
          final ClientSummary client => clientName(l, client),
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

  /// Whether opening this view is the coach looking at the client (#686):
  /// not when it is built under a workout opened from Activity.
  final bool looks;

  /// On a tablet, what this view leaves to the column beside it (#693).
  final _Desk? desk;

  const new({
    super.key,
    required this.connectionId,
    required this.onOpenWorkout,
    required this.onOpenProgram,
    required this.onMessage,
    required this.onNotes,
    required this.onLog,
    this.leading,
    this.looks = true,
    this.desk,
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

  /// Clears what a look clears for the client as the roster now has them.
  Future<void> _look(Roster roster) async {
    final client = roster.client(widget.connectionId);
    if (client == null || _former(client) || !_lookClears(client)) return;
    try {
      await roster.markReviewed(client);
    } catch (error, stacktrace) {
      // the row stays set apart, and the next open asks again
      reportToSentry(error, stacktrace: stacktrace);
    }
  }

  /// Reads the copies of a client whose row says they changed one, and keeps
  /// on this device when they last did, per copy, for its card (#745).
  Future<void> _keepChanges(Roster roster, ClientPrograms programs) async {
    final client = roster.client(widget.connectionId);
    if (client == null || !client.reasons.contains(ClientReason.changed.name)) return;
    final preferences = Preferences.of(context);
    final ids = [for (final (id, _, _) in _programsOf(client, programs.managed(client.studentId))) id];
    await programs.readChanges(client.studentId, ids);
    for (final id in ids) {
      if (programs.changedBy(client.studentId, id) case final DateTime at) await preferences.setProgramChanged(id, at);
    }
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
        // what they changed, kept for the cards until each is opened (#745):
        // read while the row still says so, before the look below clears it
        if (mounted) await _keepChanges(roster, programs);
        // opening them is looking at them (#686): what a look clears goes,
        // decided on the row as just read, once what they did is on screen.
        // Not from under a workout opened over them, which they never saw
        if (widget.looks && mounted) await _look(roster);
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
        // beside them on a tablet
        tiles: widget.desk == null,
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
    final desk = widget.desk;
    // on a tablet the newest workout is in full at the top (#693)
    final latest = switch (desk) {
      _Desk() => entries.whereType<_Trained>().firstOrNull?.workout,
      null => null,
    };
    // skips since the latest workout stay above it, newest first; the rest
    // is earlier
    final (newer, earlier) = switch (latest) {
      final Workout latest => (
        entries.takeWhile((entry) => entry is! _Trained).toList(),
        entries.skipWhile((entry) => entry is! _Trained).skip(1).toList(),
      ),
      null => (const <_Entry>[], entries),
    };

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
            // what the coach does with them, then what there is of them,
            // each under its heading (#686)
            _ClientActions(
              client: client,
              // beside them on a tablet
              onMessage: switch (desk) {
                _Desk() => null,
                null => () => widget.onMessage(client.connectionId),
              },
              // a session they trained together, logged as theirs (#560)
              onLog: (past) => widget.onLog(client.connectionId, past),
            ),
            // what they follow, and every copy the coach sent them, waiting
            // or not: the ones both of them edit (#558)
            // upright on a tablet, it is only beside them
            if (_programsOf(client, ClientPrograms.watch(context).managed(id)) case final programs
                when programs.isNotEmpty && (desk == null || _DeskShape.of(context))) ...[
              _Heading(l.coachingClientProgram),
              for (final (id, name, waiting) in programs)
                _ProgramCard(
                  key: switch (id == client.programId) {
                    true => AppKeys.coachingClientProgram,
                    false => AppKeys.coachingClientCopy(id),
                  },
                  client: client,
                  id: id,
                  name: name,
                  following: id == client.programId,
                  waiting: waiting,
                  // the one they follow is beside them in full; a copy
                  // they don't opens on its own
                  onTap: switch (desk) {
                    final _Desk desk when id == client.programId => () => desk.show(.program),
                    _ => () => widget.onOpenProgram(id),
                  },
                ),
            ],
            // the coach's own notes on them, which they never see (#556):
            // not where this device has nowhere to keep the keys, and beside
            // them on a tablet
            if (DeviceKeys.of(context).supported && desk == null) ...[
              _Heading(l.coachingYourNotes),
              _NotesTile(
                connectionId: client.connectionId,
                headed: true,
                onTap: () => widget.onNotes(client.connectionId),
              ),
            ],
            for (final entry in newer)
              if (entry case _Skipped(:final skip)) _SkipTile(skip: skip),
            if (latest case final Workout latest)
              _LatestWorkout(
                key: AppKeys.coachingLatestWorkout,
                client: client,
                workout: latest,
                onOpen: () => widget.onOpenWorkout(latest.id),
                onReply: switch (desk) {
                  final _Desk desk => () {
                    Messages.of(context).writeAbout(client.connectionId, MessageSubject(.workout, latest.id));
                    desk.show(.messages);
                  },
                  null => null,
                },
              ),
            switch (latest) {
              Workout() when earlier.isNotEmpty => _Heading(l.coachingClientEarlier),
              Workout() => const SizedBox.shrink(),
              null => _Heading(l.coachingClientWorkouts),
            },
            ...switch ((status, earlier)) {
              // the latest alone: nothing earlier to say is missing
              (_, []) when latest != null => const <Widget>[],
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
                for (final entry in earlier)
                  switch (entry) {
                    _Trained(:final workout) => _WorkoutTile(
                      workout: workout,
                      onTap: () => widget.onOpenWorkout(workout.id),
                    ),
                    _Skipped(:final skip) => _SkipTile(skip: skip),
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
      padding: const .fromLTRB(16, 16, 4, 0),
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
                if (named) Text(clientName(l, client), style: textTheme.titleLarge),
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
          // the coach's own name for them, current or former (#753)
          IconButton(
            key: AppKeys.coachingClientRename,
            tooltip: l.coachingClientRename,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, client),
          ),
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

  /// The ways to the conversation and the notes: not where they are beside
  /// this view already (#693).
  final bool tiles;

  const new({
    required this.client,
    required this.leading,
    required this.onMessage,
    required this.onNotes,
    this.tiles = true,
  });

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
          if (tiles && _holdsConversation(context, client.connectionId))
            _MessagesTile(client: client, onTap: () => onMessage(client.connectionId)),
          if (tiles && notes) _NotesTile(connectionId: client.connectionId, onTap: () => onNotes(client.connectionId)),
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

/// A day the client set aside with Not today.
class _SkipTile extends StatelessWidget {
  final TrainingSkip skip;

  const new({required this.skip});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListTile(
      key: AppKeys.coachingClientSkip,
      leading: const Icon(Icons.redo_rounded),
      title: Text(l.coachingClientSkipped),
      subtitle: Text(DateFormat.MMMEd(l.localeName).format(skip.at.toLocal())),
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

  /// Under a Notes heading, which already names it: the latest note alone.
  final bool headed;

  const new({required this.connectionId, required this.onTap, this.headed = false});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final latest = CoachNotes.watch(context).on(connectionId).firstOrNull;
    final text = Text(
      switch (latest?.text?.trim()) {
        final String text when text.isNotEmpty => text,
        _ => l.coachingNotesOnlyYou,
      },
      maxLines: switch (headed) {
        true => 2,
        false => 1,
      },
      overflow: .ellipsis,
    );
    return ListTile(
      key: AppKeys.coachingClientNotes,
      leading: const Icon(Icons.sticky_note_2_outlined),
      title: switch (headed) {
        true => text,
        false => Text(l.coachingNotes),
      },
      subtitle: switch (headed) {
        true => null,
        false => text,
      },
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// A section's heading on the coach's pages about a client (#686).
class _Heading extends StatelessWidget {
  final String text;

  const new(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

/// What the coach does with a client, as buttons under who they are:
/// write to them, and log a session they trained together (#686).
class _ClientActions extends StatelessWidget {
  final ClientSummary client;

  /// Opens the conversation; none where it is beside them already (#693).
  final VoidCallback? onMessage;
  final ValueChanged<PastWorkout> onLog;

  const new({required this.client, required this.onLog, this.onMessage});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final unread = Messages.watch(context).threadOf(client.connectionId)?.unread ?? 0;
    final message = PrimaryButton.shrunk(
      key: AppKeys.coachingClientMessages,
      onPressed: onMessage,
      // the house 32pt look, and a full tap target
      hitHeight: kMinInteractiveDimension,
      child: Row(
        mainAxisSize: .min,
        spacing: 8,
        children: [
          const Icon(Icons.forum_outlined, size: 18),
          // a long name gives way rather than overflow
          Flexible(
            child: Text(
              switch (client.name?.trim()) {
                final String name when name.isNotEmpty => l.messagesWith(name),
                _ => l.coachingMessages,
              },
              maxLines: 1,
              overflow: .ellipsis,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const .fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // the Messages tab's own badge: one count, one look
          if (onMessage != null) UnreadBadge(count: unread, child: message),
          _LogForButton(client: client, onLog: onLog),
        ],
      ),
    );
  }
}

/// The program a client follows, or a copy the coach sent them, as a card:
/// its name, and for the one they follow, where in it they are (#686).
class _ProgramCard extends StatelessWidget {
  final ClientSummary client;
  final String id;
  final String name;

  /// The one they follow, rather than a copy waiting or put aside.
  final bool following;
  final bool waiting;
  final VoidCallback onTap;

  const new({
    super.key,
    required this.client,
    required this.id,
    required this.name,
    required this.following,
    required this.waiting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final progress = switch (client) {
      // weeks behind them: the week they are in is still to train
      ClientSummary(programWeek: final int week, programWeeks: final int weeks) when following && weeks > 0 =>
        ((week - 1) / weeks).clamp(0.0, 1.0),
      _ => null,
    };
    // what they changed since the coach last opened it here (#745)
    final preferences = Preferences.watch(context);
    final changed = switch ((preferences.programChanged(id), preferences.programSeen(id))) {
      (final DateTime at, final DateTime seen) when !at.isAfter(seen) => null,
      (final DateTime at, _) => at,
      _ => null,
    };
    return Padding(
      padding: const .symmetric(horizontal: 16, vertical: 4),
      child: Card(
        margin: .zero,
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const .all(16),
            child: Row(
              spacing: 16,
              children: [
                Tooltip(message: l.coachingClientProgram, child: const Icon(Icons.event_repeat_rounded)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 8,
                    children: [
                      Text(
                        switch (following) {
                          true => _programLine(l, client),
                          false => name,
                        },
                        style: textTheme.bodyLarge,
                        maxLines: 2,
                        overflow: .ellipsis,
                      ),
                      if (waiting)
                        Text(
                          l.coachingCopyWaiting,
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      if (changed case final DateTime at)
                        Row(
                          key: AppKeys.coachingCopyChanged(id),
                          spacing: 6,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 18, color: colorScheme.tertiary),
                            Expanded(
                              child: Text(
                                l.coachingCopyChangedByThem(
                                  DateFormat.MMMEd(l.localeName).add_jm().format(at.toLocal()),
                                ),
                                style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary),
                              ),
                            ),
                          ],
                        ),
                      if (progress case final double progress)
                        LinearProgressIndicator(value: progress, borderRadius: const .all(.circular(4))),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
