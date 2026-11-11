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

  const new({super.key, required this.connectionId, required this.onOpenWorkout, required this.onOpenProgram});

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
          child: _ClientView(connectionId: connectionId, onOpenWorkout: onOpenWorkout, onOpenProgram: onOpenProgram),
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

  /// The pane beside the roster names the client itself; a page has its
  /// title for that.
  final Widget? leading;

  const new({
    super.key,
    required this.connectionId,
    required this.onOpenWorkout,
    required this.onOpenProgram,
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
    if (old.connectionId != widget.connectionId) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final roster = Roster.of(context);
    // the row they were opened from may be stale, and opened from a link
    // the roster may never have been read
    final programs = ClientPrograms.of(context);
    if (roster.client(widget.connectionId) case final ClientSummary client) {
      await (roster.load(), roster.loadRecord(client.studentId), programs.loadManaged(client.studentId)).wait;
    } else {
      await roster.load();
      if (roster.client(widget.connectionId) case final ClientSummary client) {
        await (roster.loadRecord(client.studentId), programs.loadManaged(client.studentId)).wait;
      }
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
        _ => _Empty(icon: Icons.person_off_outlined, title: l.coachingClientGone),
      };
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

  const new({required this.client, this.named = false});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final reasons = _reasonsInWords(l, client);
    return Padding(
      padding: const .fromLTRB(16, 16, 8, 0),
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
                Text(_programLine(l, client), style: textTheme.bodyLarge),
                _WeekDots(client: client),
                if (reasons.isNotEmpty)
                  Text(reasons.join(' · '), style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary)),
              ],
            ),
          ),
          if (_lookClears(client)) _MarkReviewed(client: client),
        ],
      ),
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
      title: Text(_workoutTitle(l, workout), maxLines: 1, overflow: .ellipsis),
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

String _workoutTitle(L l, Workout workout) {
  return switch (workout.name?.trim()) {
    final String name when name.isNotEmpty => name,
    _ => l.coachingReviewUntitled,
  };
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
