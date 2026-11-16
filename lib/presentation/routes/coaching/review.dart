part of 'coaching.dart';

/// "Did they do what I asked?" (#559): a client's workout, their note above
/// it, and per exercise what the plan asked beside what they did, with what
/// was lighter, skipped or added said in words.
class WorkoutReviewPage extends StatefulWidget {
  final String connectionId;
  final String workoutId;

  /// Opens the conversation with the client, where the next message is
  /// about what was picked here.
  final VoidCallback? onMessage;

  const new({super.key, required this.connectionId, required this.workoutId, this.onMessage});

  @override
  State<WorkoutReviewPage> createState() => _WorkoutReviewPageState();
}

class _WorkoutReviewPageState extends State<WorkoutReviewPage> {
  late Future<WorkoutReview> _review;

  @override
  void initState() {
    super.initState();
    // read after this build: reading the roster notifies what the page is built from
    _review = Future(_read);
  }

  Future<WorkoutReview> _read() async {
    final roster = Roster.of(context);
    // opened from a link, before Clients ever read the roster
    if (roster.client(widget.connectionId) == null) await roster.load();
    return switch (roster.client(widget.connectionId)) {
      final ClientSummary client => roster.review(client.studentId, widget.workoutId),
      null => throw StateError('no such client'),
    };
  }

  /// Tries again after a failure; the reading is the page's state, so a
  /// notifier would only mirror the future.
  final _attempt = ValueNotifier(0);

  @override
  void dispose() {
    _attempt.dispose();
    super.dispose();
  }

  /// The conversation, with the next message about [subject] (#556).
  /// None for someone no longer coached: their conversation takes nothing.
  void Function(MessageSubject subject)? get _messageAbout {
    final open = widget.onMessage;
    final coached = switch (Roster.watch(context).client(widget.connectionId)?.status) {
      'active' || 'paused' => true,
      _ => false,
    };
    if (open == null || !coached) return null;
    return (subject) {
      Messages.of(context).writeAbout(widget.connectionId, subject);
      open();
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ValueListenableBuilder(
      valueListenable: _attempt,
      builder: (context, _, _) => FutureBuilder(
        future: _review,
        builder: (context, snapshot) {
          return Scaffold(
            key: AppKeys.coachingReview,
            appBar: AppBar(
              title: Text(switch (snapshot.data) {
                final WorkoutReview review => workoutTitle(l, review.workout),
                null => '',
              }),
              actions: [
                if ((snapshot.data, _messageAbout) case (final WorkoutReview review, final message?))
                  IconButton(
                    key: AppKeys.reviewMessage,
                    tooltip: l.messagesAboutThisWorkout,
                    onPressed: () => message(MessageSubject(.workout, review.workout.id)),
                    icon: const Icon(Icons.add_comment_outlined),
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: Align(
              alignment: .topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: readableWidth),
                child: switch (snapshot) {
                  AsyncSnapshot(hasData: true, :final data?) => _ReviewView(
                    review: data,
                    onMessageAbout: _messageAbout,
                  ),
                  AsyncSnapshot(hasError: true) => _Empty(
                    icon: Icons.cloud_off_rounded,
                    title: l.coachingReviewFailed,
                    action: OutlinedButton(
                      onPressed: () {
                        _review = _read();
                        _attempt.value++;
                      },
                      child: Text(l.retry),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator.adaptive()),
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReviewView extends StatelessWidget {
  final WorkoutReview review;
  final void Function(MessageSubject subject)? onMessageAbout;

  const new({required this.review, this.onMessageAbout});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final workout = review.workout;
    final note = switch (workout.note?.trim()) {
      final String note when note.isNotEmpty => note,
      _ => null,
    };
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final when = DateFormat.yMMMEd(l.localeName).add_jm().format(workout.start.toLocal());
    return ListView(
      padding: const .fromLTRB(16, 8, 16, 32),
      children: [
        Text(when, style: muted),
        if (note != null)
          Padding(
            padding: const .only(top: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: .circular(12),
              ),
              child: Padding(
                padding: const .all(12),
                child: Text(note, style: textTheme.bodyLarge?.copyWith(fontStyle: .italic)),
              ),
            ),
          ),
        if (!review.hasPlan)
          Padding(
            padding: const .only(top: 12),
            child: Text(l.coachingReviewNoPlan, style: muted),
          ),
        if (review.lighterWeek)
          Padding(
            padding: const .only(top: 12),
            child: Text(l.coachingReviewLighterWeek, style: muted),
          ),
        const SizedBox(height: 8),
        for (final (index, exercise) in review.exercises.indexed)
          _ReviewedExerciseCard(
            key: AppKeys.coachingReviewExercise(index),
            exercise: exercise,
            compare: review.hasPlan,
            onMessageAbout: onMessageAbout,
          ),
      ],
    );
  }
}

class _ReviewedExerciseCard extends StatelessWidget {
  final ReviewedExercise exercise;

  /// Whether there's a plan to put beside what was done.
  final bool compare;

  /// A message about one set of it: a long press on the set.
  final void Function(MessageSubject subject)? onMessageAbout;

  const new({super.key, required this.exercise, required this.compare, this.onMessageAbout});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final known = exercise.exercise ?? Exercises.of(context).lookup(exercise.exerciseId);
    final formats = RecordFormats(
      l: l,
      prefs: Preferences.of(context),
      unit: Exercises.of(context).unitFor(exercise.exerciseId),
      category: known?.category,
    );
    final summary = switch (exercise) {
      ReviewedExercise(planned: false) when compare => l.coachingReviewNotPlanned,
      ReviewedExercise(skipped: true) => l.coachingReviewSkipped,
      ReviewedExercise(:final sets) when compare && sets.every((set) => set.outcome == .asked) =>
        l.coachingReviewAsPlanned,
      _ => null,
    };
    final label = textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    return Card(
      margin: const .only(top: 12),
      child: Padding(
        padding: const .fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 6,
          children: [
            Row(
              spacing: 8,
              children: [
                Expanded(child: Text(known?.name ?? exercise.exerciseId, style: textTheme.titleMedium)),
                if (summary != null) Text(summary, style: textTheme.labelLarge?.copyWith(color: colorScheme.tertiary)),
              ],
            ),
            if (compare && !exercise.skipped)
              Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(child: Text(l.coachingReviewAsked, style: label)),
                  Expanded(child: Text(l.coachingReviewDone, style: label)),
                  const Expanded(child: SizedBox()),
                ],
              ),
            if (!exercise.skipped)
              for (final (index, set) in exercise.sets.indexed)
                _MessageableSet(
                  key: switch (set.done) {
                    final ExerciseSet done => AppKeys.reviewSet(done.id),
                    null => null,
                  },
                  onMessage: switch ((set.done, onMessageAbout)) {
                    (final ExerciseSet done, final message?) => () => message(MessageSubject(.exerciseSet, done.id)),
                    _ => null,
                  },
                  child: Row(
                    crossAxisAlignment: .start,
                    children: [
                      SizedBox(width: 28, child: Text('${index + 1}', style: label)),
                      if (compare)
                        Expanded(
                          child: Text(switch (set.planned) {
                            final PlannedNumbers asked => setInWords(l, formats, asked),
                            null => '—',
                          }),
                        ),
                      Expanded(
                        child: Text(switch (set.done) {
                          final ExerciseSet done => setInWords(
                            l,
                            formats,
                            (weight: done.weight, reps: done.reps, duration: done.duration, distance: done.distance),
                          ),
                          null => '—',
                        }),
                      ),
                      if (compare)
                        Expanded(
                          child: Text(
                            switch (set.outcome) {
                              .lighter => l.coachingReviewLighter,
                              .fewer => l.coachingReviewFewer,
                              .shorter => l.coachingReviewShorter,
                              .skipped => l.coachingReviewSkipped,
                              .added => l.coachingReviewAdded,
                              .asked || null => '',
                            },
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary),
                            textAlign: .end,
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// A set's row, which a long press, or a screen reader's action, turns into
/// a message about it (#556). Just the row where there's nobody to write to.
class _MessageableSet extends StatelessWidget {
  final VoidCallback? onMessage;
  final Widget child;

  const new({super.key, this.onMessage, required this.child});

  @override
  Widget build(BuildContext context) {
    final message = onMessage;
    if (message == null) return child;
    final label = L.of(context).messagesAboutThisSet;
    return Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: label): message},
      child: GestureDetector(
        behavior: .opaque,
        onLongPressStart: (details) => _menu(context, details.globalPosition, label, message),
        child: child,
      ),
    );
  }

  static Future<void> _menu(BuildContext context, Offset at, String label, VoidCallback message) async {
    final picked = await showMenu<bool>(
      context: context,
      position: menuAt(context, at),
      items: [PopupMenuItem(key: AppKeys.reviewSetMessage, value: true, child: Text(label))],
    );
    if (picked ?? false) message();
  }
}
