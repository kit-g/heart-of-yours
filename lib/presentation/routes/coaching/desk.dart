part of 'coaching.dart';

/// What sits beside a client on a tablet (#693): the conversation with them,
/// their program, or the coach's notes on them.
enum _Beside { messages, program, notes }

/// How wide the column beside a client is, where it fits beside them.
const _besideColumnWidth = 350.0;

/// Where the column beside a client fits beside them rather than under: room
/// for it and a client's column that still reads, measured on the pane.
const _besideColumnAt = 760.0;

/// What a client's view leaves to the column beside it on a tablet (#693).
class _Desk {
  /// Whether their program sits in their column too, as a summary: on a
  /// landscape page, where the column beside it may show something else.
  final bool programInColumn;

  /// Shows [tab] beside the client.
  final ValueChanged<_Beside> show;

  const new({required this.programInColumn, required this.show});
}

/// What is open beside the roster: a client, and one of their workouts over
/// them when that is what was opened, from Activity or the client's own list,
/// by the tap that opened it.
typedef _Opened = ({String connectionId, String? workoutId, int tap});

/// Whether the column beside a client fits beside them, for the routes of
/// the pane's own navigator, which are built under it.
class _DeskShape extends InheritedWidget {
  final bool wide;

  const new({required this.wide, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_DeskShape>()?.wide ?? true;

  @override
  bool updateShouldNotify(_DeskShape old) => wide != old.wide;
}

/// A client beside the roster (#685, #693), as the coaching design's desk has
/// them: their column, and beside it, the conversation, their program or the
/// coach's notes, so none of those is a page over them.
///
/// Where the page is too narrow for a third column, the same switch sits
/// under the client instead. A workout opened from their list, or from
/// Activity, lands over their column, and Back goes there.
class _ClientPane extends StatefulWidget {
  final _Opened opened;

  /// Opens a copy of their program that they don't follow, as a page.
  final ValueChanged<String> onOpenProgram;

  /// Opens the template editor on a session of their program.
  final void Function(String programId, {required bool isNew}) onEditSession;
  final void Function(String connectionId, PastWorkout past) onLog;
  final VoidCallback onClose;

  const new({
    super.key,
    required this.opened,
    required this.onOpenProgram,
    required this.onEditSession,
    required this.onLog,
    required this.onClose,
  });

  @override
  State<_ClientPane> createState() => _ClientPaneState();
}

class _ClientPaneState extends State<_ClientPane> {
  final _navigator = GlobalKey<NavigatorState>();

  /// What is beside the client, kept through a turn of the device.
  final _beside = ValueNotifier(_Beside.messages);

  /// Whether the column beside the client fit beside them at the last build.
  var _wide = true;

  @override
  void dispose() {
    _beside.dispose();
    super.dispose();
  }

  void _show(_Beside tab) {
    _beside.value = tab;
    // under the client, a workout open over them covers it
    if (!_wide) _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  void _openWorkout(String workoutId) => _navigator.currentState?.push(_review(workoutId));

  Route<void> _review(String workoutId) {
    return MaterialPageRoute(
      builder: (_) => WorkoutReviewPage(
        key: ValueKey(workoutId),
        connectionId: widget.opened.connectionId,
        workoutId: workoutId,
        onMessage: () => _show(.messages),
      ),
    );
  }

  Widget _besidePane() {
    return _BesidePane(
      connectionId: widget.opened.connectionId,
      tab: _beside,
      onOpenWorkout: _openWorkout,
      onOpenProgram: widget.onOpenProgram,
      onEditSession: widget.onEditSession,
    );
  }

  /// The client's own view, at the bottom of the pane's navigator: built
  /// once, reading the pane's widget and shape as they are each time it
  /// builds.
  Route<void> _client() {
    return MaterialPageRoute(
      builder: (context) {
        final wide = _DeskShape.of(context);
        final view = Align(
          alignment: .topCenter,
          // a column as on a page, not the pane's whole width
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: readableWidth),
            child: _ClientView(
              key: AppKeys.coachingClientPane,
              connectionId: widget.opened.connectionId,
              // under a workout opened from Activity it was never seen
              looks: widget.opened.workoutId == null,
              onOpenWorkout: _openWorkout,
              onOpenProgram: widget.onOpenProgram,
              onMessage: (_) => _show(.messages),
              onNotes: (_) => _show(.notes),
              onLog: widget.onLog,
              desk: _Desk(programInColumn: wide, show: _show),
              leading: Align(
                alignment: .centerRight,
                child: IconButton(
                  key: AppKeys.coachingClientClose,
                  tooltip: L.of(context).coachingClientClose,
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ),
        );
        return Material(
          child: switch (wide) {
            true => view,
            // upright: the client over what is beside them
            false => Column(
              crossAxisAlignment: .stretch,
              children: [
                Expanded(flex: 5, child: view),
                const Divider(height: 1),
                Expanded(flex: 6, child: _besidePane()),
              ],
            ),
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back on Android steps back inside the pane before it leaves the page
    final navigator = NavigatorPopHandler(
      onPopWithResult: (_) => _navigator.currentState?.maybePop(),
      child: Navigator(
        key: _navigator,
        onGenerateInitialRoutes: (_, _) => [
          _client(),
          if (widget.opened.workoutId case final String workoutId) _review(workoutId),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = _wide = constraints.maxWidth >= _besideColumnAt;
        return _DeskShape(
          wide: wide,
          child: switch (wide) {
            true => Row(
              crossAxisAlignment: .stretch,
              children: [
                Expanded(child: navigator),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: _besideColumnWidth,
                  child: Material(child: _besidePane()),
                ),
              ],
            ),
            false => navigator,
          },
        );
      },
    );
  }
}

/// The conversation with a client, their program, or the coach's notes on
/// them, one at a time, beside or under them (#693).
class _BesidePane extends StatelessWidget {
  final String connectionId;
  final ValueNotifier<_Beside> tab;
  final ValueChanged<String> onOpenWorkout;
  final ValueChanged<String> onOpenProgram;
  final void Function(String programId, {required bool isNew}) onEditSession;

  const new({
    required this.connectionId,
    required this.tab,
    required this.onOpenWorkout,
    required this.onOpenProgram,
    required this.onEditSession,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final client = Roster.watch(context).client(connectionId);
    final former = switch (client) {
      final ClientSummary client => _former(client),
      null => false,
    };
    final tabs = <_Beside, Widget>{
      // an ended connection takes no new message: only one to read back
      if (!former || _holdsConversation(context, connectionId))
        .messages: Text(l.coachingMessages, key: AppKeys.coachingBesideTab('messages')),
      // no longer coached, their program isn't the coach's to read
      if (!former) .program: Text(l.coachingClientProgram, key: AppKeys.coachingBesideTab('program')),
      // where this device has somewhere to keep the keys
      if (DeviceKeys.of(context).supported) .notes: Text(l.coachingNotes, key: AppKeys.coachingBesideTab('notes')),
    };
    if (tabs.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: tab,
      builder: (context, picked, _) {
        final shown = switch (tabs.containsKey(picked)) {
          true => picked,
          false => tabs.keys.first,
        };
        return Column(
          key: AppKeys.coachingBeside,
          crossAxisAlignment: .stretch,
          children: [
            Padding(
              padding: const .fromLTRB(12, 12, 4, 8),
              child: Row(
                spacing: 4,
                children: [
                  Expanded(
                    child: switch (tabs.length) {
                      1 => const SizedBox.shrink(),
                      _ => Semantics(
                        label: l.coachingClientBeside,
                        container: true,
                        // larger type shrinks the three words to the
                        // column rather than run them off its edge
                        child: FittedBox(
                          fit: .scaleDown,
                          child: SettingSwitcher<_Beside>(
                            value: shown,
                            onValueChanged: (each) => tab.value = each ?? shown,
                            children: tabs,
                          ),
                        ),
                      ),
                    },
                  ),
                  // what the tab's page has in its app bar, in a spot that
                  // keeps its size, so the switch stays put between tabs
                  SizedBox.square(
                    dimension: kMinInteractiveDimension,
                    child: switch (shown) {
                      .messages => ThreadMenu(connectionId: connectionId),
                      .notes => _NewNoteButton(connectionId: connectionId),
                      .program => null,
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (shown) {
                .messages => ThreadView(
                  key: ValueKey(connectionId),
                  connectionId: connectionId,
                  onOpenWorkout: (client: onOpenWorkout, own: null),
                ),
                .program => _BesideProgram(
                  connectionId: connectionId,
                  onOpenProgram: onOpenProgram,
                  onEditSession: onEditSession,
                ),
                .notes => _NotesList(connectionId: connectionId),
              },
            ),
          ],
        );
      },
    );
  }
}

/// The program a client follows, in full, under any other copy the coach
/// sent them (#693).
class _BesideProgram extends StatelessWidget {
  final String connectionId;
  final ValueChanged<String> onOpenProgram;
  final void Function(String programId, {required bool isNew}) onEditSession;

  const new({required this.connectionId, required this.onOpenProgram, required this.onEditSession});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final client = Roster.watch(context).client(connectionId);
    if (client == null) return const SizedBox.shrink();
    final copies = [
      for (final (id, name, waiting) in _programsOf(client, ClientPrograms.watch(context).managed(client.studentId)))
        if (id != client.programId)
          _ProgramCard(
            key: AppKeys.coachingClientCopy(id),
            client: client,
            name: name,
            following: false,
            waiting: waiting,
            onTap: () => onOpenProgram(id),
          ),
    ];
    return switch (client.programId) {
      final String id => Column(
        crossAxisAlignment: .stretch,
        children: [
          ...copies,
          Expanded(
            child: _ClientProgramBody(
              key: ValueKey(id),
              connectionId: connectionId,
              programId: id,
              onEditSession: ({required isNew}) => onEditSession(id, isNew: isNew),
            ),
          ),
        ],
      ),
      null when copies.isEmpty => _Empty(icon: Icons.event_repeat_rounded, title: l.coachingClientNoProgram),
      null => ListView(children: copies),
    };
  }
}

/// A client's newest workout in full (#693): their note, and per exercise
/// what was asked beside what they did, which is what the coach opens them
/// for.
class _LatestWorkout extends StatefulWidget {
  final ClientSummary client;
  final Workout workout;

  /// Opens the workout on its own, set by set.
  final VoidCallback onOpen;

  /// Turns the conversation beside it to this workout.
  final VoidCallback? onReply;

  const new({super.key, required this.client, required this.workout, required this.onOpen, this.onReply});

  @override
  State<_LatestWorkout> createState() => _LatestWorkoutState();
}

class _LatestWorkoutState extends State<_LatestWorkout> {
  late Future<WorkoutReview> _review = _read();

  Future<WorkoutReview> _read() => Roster.of(context).review(widget.client.studentId, widget.workout.id);

  @override
  void didUpdateWidget(covariant _LatestWorkout old) {
    super.didUpdateWidget(old);
    if (old.workout.id != widget.workout.id) _review = _read();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final workout = widget.workout;
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final when = DateFormat.MMMEd(l.localeName).add_jm().format(workout.start.toLocal());
    final note = switch (workout.note?.trim()) {
      final String note when note.isNotEmpty => note,
      _ => null,
    };
    return Padding(
      padding: const .fromLTRB(16, 16, 16, 4),
      child: Card(
        margin: .zero,
        clipBehavior: .antiAlias,
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            InkWell(
              key: AppKeys.coachingClientWorkout(workout.id),
              onTap: widget.onOpen,
              child: Padding(
                padding: const .fromLTRB(16, 12, 8, 12),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        spacing: 2,
                        children: [
                          Text(
                            workoutTitle(l, workout),
                            style: textTheme.titleMedium,
                            maxLines: 2,
                            overflow: .ellipsis,
                          ),
                          Text(when, style: muted),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            if (note != null)
              Padding(
                padding: const .fromLTRB(16, 0, 16, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: .circular(8),
                  ),
                  child: Padding(
                    padding: const .symmetric(horizontal: 12, vertical: 8),
                    child: Text(note, style: textTheme.bodyMedium?.copyWith(fontStyle: .italic)),
                  ),
                ),
              ),
            FutureBuilder(
              future: _review,
              builder: (context, snapshot) => switch (snapshot) {
                AsyncSnapshot(hasData: true, :final data?) => _ReviewTable(review: data),
                AsyncSnapshot(hasError: true) => Padding(
                  padding: const .fromLTRB(16, 0, 16, 8),
                  child: Text(l.coachingReviewFailed, style: muted),
                ),
                _ => const Padding(
                  padding: .all(16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                ),
              },
            ),
            if (widget.onReply case final reply?)
              Padding(
                padding: const .fromLTRB(16, 8, 16, 16),
                child: Align(
                  alignment: .centerLeft,
                  child: PrimaryButton.shrunk(
                    key: AppKeys.coachingReplyAbout,
                    backgroundColor: colorScheme.secondaryContainer,
                    onPressed: reply,
                    child: Row(
                      mainAxisSize: .min,
                      spacing: 8,
                      children: [
                        Icon(Icons.forum_outlined, size: 18, color: colorScheme.onSecondaryContainer),
                        Flexible(
                          child: Text(
                            l.coachingReplyAbout,
                            maxLines: 1,
                            overflow: .ellipsis,
                            style: TextStyle(color: colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A workout as a table, one row per exercise: what was asked, what was
/// done, and what differed, in words.
class _ReviewTable extends StatelessWidget {
  final WorkoutReview review;

  const new({required this.review});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final compare = review.hasPlan;
    final label = textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final border = BoxDecoration(
      border: Border(top: BorderSide(color: dividerColor.withValues(alpha: .4))),
    );
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          if (!compare)
            Padding(
              padding: const .only(bottom: 8),
              child: Text(l.coachingReviewNoPlan, style: muted),
            ),
          if (review.lighterWeek)
            Padding(
              padding: const .only(bottom: 8),
              child: Text(l.coachingReviewLighterWeek, style: muted),
            ),
          if (compare)
            ExcludeSemantics(
              child: Padding(
                padding: const .only(bottom: 4),
                child: Row(
                  spacing: 8,
                  children: [
                    const Expanded(flex: 5, child: SizedBox()),
                    Expanded(flex: 4, child: Text(l.coachingReviewAsked, style: label)),
                    Expanded(flex: 5, child: Text(l.coachingReviewDone, style: label)),
                  ],
                ),
              ),
            ),
          for (final exercise in review.exercises)
            DecoratedBox(
              decoration: border,
              child: Padding(
                padding: const .symmetric(vertical: 8),
                child: _ReviewRow(exercise: exercise, compare: compare),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final ReviewedExercise exercise;
  final bool compare;

  const new({required this.exercise, required this.compare});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final exercises = Exercises.of(context);
    final known = exercise.exercise ?? exercises.lookup(exercise.exerciseId);
    final formats = RecordFormats(
      l: l,
      prefs: Preferences.of(context),
      unit: exercises.unitFor(exercise.exerciseId),
      category: known?.category,
    );
    final asked = switch (exercise) {
      ReviewedExercise(planned: false) => l.coachingReviewNotPlanned,
      ReviewedExercise(:final sets) =>
        sets.map((set) => set.planned).nonNulls.map((each) => setInWords(l, formats, each)).join(', '),
    };
    final done = switch (exercise) {
      ReviewedExercise(skipped: true) => l.coachingReviewSkipped,
      ReviewedExercise(:final sets) =>
        sets
            .map((set) => set.done)
            .nonNulls
            .map(
              (done) => setInWords(
                l,
                formats,
                (weight: done.weight, reps: done.reps, duration: done.duration, distance: done.distance),
              ),
            )
            .join(', '),
    };
    // each way it differed once, in the order the sets went
    final differed = switch (compare && !exercise.skipped) {
      true => {
        for (final set in exercise.sets)
          ?switch (set.outcome) {
            .lighter => l.coachingReviewLighter,
            .fewer => l.coachingReviewFewer,
            .shorter => l.coachingReviewShorter,
            .skipped => l.coachingReviewSkipped,
            .added => l.coachingReviewAdded,
            .asked || null => null,
          },
      }.join(' · '),
      false => '',
    };
    final body = textTheme.bodyMedium;
    return Row(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        Expanded(flex: 5, child: Text(known?.name ?? exercise.exerciseId, style: body)),
        if (compare)
          Expanded(
            flex: 4,
            child: Text(asked, style: body?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: .start,
            spacing: 2,
            children: [
              Text(done, style: body),
              if (differed.isNotEmpty) Text(differed, style: body?.copyWith(color: colorScheme.tertiary)),
            ],
          ),
        ),
      ],
    );
  }
}
