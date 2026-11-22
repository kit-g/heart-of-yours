part of 'workout_detail.dart';

/// Live records (#160) over the active workout: a quiet note the moment a
/// ticked working set beats a previous best, and the record pills under the
/// sets that hold one, as a past workout's page has them. And live goal notes
/// (#625), under the same switch: the tick that carries a goal over one of
/// its rungs says so in the same note, with a burst of the Done page's
/// confetti — small for a rung on the way, full for the goal's last.
///
/// The records are [liveRecordMarks]: the fold the Done page runs on the
/// finished workout, over the same sets, so what shows here is what that page
/// will say. The goals are [goalCrossings], which is what the Done page lists,
/// over priors read the way it reads them. Unticking or editing a set
/// re-folds, and a record or rung it no longer holds goes from the note.
///
/// Off, the sheet is what it was before the feature: no pills, no note, and
/// nothing read. Never answered, it folds only to find the moment to ask —
/// the first ticked set that would have been a record or reached a goal —
/// and puts the offer under that set. Nothing about goals is read for someone
/// without one.
class _LiveRecordsScope extends StatefulWidget {
  final Widget child;

  const new({required this.child});

  @override
  State<_LiveRecordsScope> createState() => _LiveRecordsScopeState();
}

/// One note: the records a set just beat, the goal rungs a tick just
/// reached, or both.
typedef _LiveNote = ({String? setId, Exercise? exercise, List<RecordKind> kinds, List<GoalAchievement> goals});

/// A goal's celebration: [serial] tells one burst from the next, [full] a
/// goal's last rung from one on the way.
typedef _Burst = ({int serial, bool full});

class _LiveRecordsScopeState extends State<_LiveRecordsScope> {
  static const _feature = Feature.liveRecords;

  /// How long the note stays: long enough to read two short lines.
  static const _noteFor = Duration(milliseconds: 3500);

  final _note = ValueNotifier<_LiveNote?>(null);
  Timer? _noteTimer;

  final _burst = ValueNotifier<_Burst?>(null);
  Timer? _burstTimer;

  /// Counts bursts, so each is a new one rather than the last one replayed.
  var _bursts = 0;

  /// The marks as of the last build, and the exercises read by then: a mark
  /// is news only when it arrives on an exercise already read. One arriving
  /// with its exercise's read — a workout restored after a restart — was
  /// there all along.
  RecordMarks _marks = const {};
  Set<ExerciseId> _read = const {};

  /// The same for goals: the rungs crossed as of the last build, and the
  /// goals whose priors had been read by then.
  Set<GoalCrossingKey> _crossed = const {};
  Set<String?> _goalsRead = const {};

  /// The working sets ticked as of the last build, each with what it
  /// measured: a goal crossing is news only on a build where one of them
  /// changed. A goal edited, retargeted or synced under a workout, or a store
  /// read landing, moves a crossing without a tick, and says nothing.
  Map<String, Object> _ticked = const {};

  @override
  void dispose() {
    _noteTimer?.cancel();
    _burstTimer?.cancel();
    _note.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final live = LiveRecords.watch(context);
    final liveGoals = LiveGoals.watch(context);
    final goals = Goals.watch(context);
    // every tick, untick, edit and retype notifies, and each is a re-fold
    final workouts = Workouts.watch(context);
    final on = preferences.isOn(_feature);
    final offering = !on && preferences.shouldOffer(_feature);
    final anchored = offering || preferences.owesDeclineNotice(_feature);

    switch ((on || offering, workouts.userId, workouts.activeWorkout)) {
      case (true, final String userId, final Workout workout):
        live.prime(userId, workout);
        // nothing read, and nothing folded, for someone without a goal
        final judge = goals.isEmpty ? null : goalJudge(context);
        final aimed = judge?.goals ?? const <Goal>[];
        if (judge != null && aimed.isNotEmpty) {
          liveGoals.prime(
            workout,
            aimed,
            (goal) => judge.read(goal, workout),
            revision: (workouts.historyRevision, workout.start, preferences.firstWeekday),
          );
        }
        _track(
          workout,
          liveRecordMarks(workout, live.prior),
          switch (judge) {
            final GoalJudge judge => goalCrossings(aimed, liveGoals.priorOf, workout, fold: judge.fold),
            null => const [],
          },
          live,
          read: {
            for (final goal in aimed)
              if (liveGoals.hasRead(goal)) goal.id,
          },
          on: on,
        );
      case _:
        _marks = const {};
        _read = const {};
        _crossed = const {};
        _goalsRead = const {};
        _ticked = const {};
        if (_note.value != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _withdraw();
          });
        }
    }

    final still = lessMotion(context);

    // the same shape whatever the answer, so turning it on from the offer
    // keeps the sheet's scroll where it was
    return RecordMarksScope(
      marks: on ? _marks : const {},
      firstSetId: null,
      child: _LiveRecordAnchor(
        setId: anchored ? live.offeredUnder : null,
        child: ValueListenableBuilder<double?>(
          // a push's note over the sheet (#724): this one goes under it
          valueListenable: pushNoteBottom,
          builder: (context, pushBottom, _) => _stacked(below: _belowPushNote(pushBottom), still: still),
        ),
      ),
    );
  }

  /// How far down the push note reaches into this sheet, 0 for not at all.
  double _belowPushNote(double? pushBottom) {
    final box = context.findRenderObject();
    if (pushBottom == null || box is! RenderBox || !box.hasSize) return 0;
    return max(0, box.globalToLocal(Offset(0, pushBottom)).dy + 8 - _noteTop);
  }

  /// Under the sheet's 40pt header.
  static const _noteTop = 48.0;

  Widget _stacked({required double below, required bool still}) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: _noteTop + below,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Align(
              alignment: .topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: readableWidth),
                child: ValueListenableBuilder<_LiveNote?>(
                  valueListenable: _note,
                  builder: (context, note, _) {
                    return AnimatedSwitcher(
                      // with less motion asked for, the note is simply there
                      duration: still ? Duration.zero : const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, -.3), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: switch (note) {
                        final _LiveNote note => _LiveNoteCard(key: ValueKey(note), note: note),
                        null => const SizedBox.shrink(),
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          // from the note's middle, over everything and in nobody's way
          top: 72 + below,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: ValueListenableBuilder<_Burst?>(
              valueListenable: _burst,
              builder: (context, burst, _) {
                return switch (burst) {
                  (:final serial, :final full) => Center(
                    key: WorkoutDetailKeys.liveGoalBurst,
                    child: Confetti(
                      key: ValueKey(serial),
                      particleCount: full ? 48 : 14,
                      duration: _burstFor(full: full).inSeconds,
                    ),
                  ),
                  null => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ),
      ],
    );
  }

  /// How long a burst plays: brief, and briefer for a rung on the way.
  static Duration _burstFor({required bool full}) => Duration(seconds: full ? 3 : 2);

  /// Takes in this build's [marks] and [crossings]: what is news is noted (or,
  /// unanswered, offered), and whatever a note says that no longer stands is
  /// taken back. [read] is the goals whose priors have landed.
  void _track(
    Workout workout,
    RecordMarks marks,
    List<GoalAchievement> crossings,
    LiveRecords live, {
    required Set<String?> read,
    required bool on,
  }) {
    final exerciseOf = {
      for (final entry in workout)
        for (final set in entry) set.id: entry.exercise,
    };
    final fresh = [
      for (final MapEntry(key: setId, value: kinds) in marks.entries)
        if (exerciseOf[setId] case final Exercise exercise when _read.contains(exercise.id))
          if (kinds.any((kind) => !(_marks[setId]?.contains(kind) ?? false)))
            (setId: setId, exercise: exercise, kinds: kinds),
    ];
    final ticked = {
      for (final set in workout.expand((entry) => entry))
        if (isWorkingSet(set)) set.id: (set.weight, set.reps, set.duration, set.distance, set.setType),
    };
    // the sets this build ticked or changed, the last of them the one a goal's
    // offer sits under
    final touched = [
      for (final MapEntry(key: setId, :value) in ticked.entries)
        if (_ticked[setId] != value) setId,
    ];
    final crossed = {for (final crossing in crossings) crossingKey(crossing)};
    final reached = [
      if (touched.isNotEmpty)
        for (final crossing in crossings)
          if (_goalsRead.contains(crossing.goal.id) && !_crossed.contains(crossingKey(crossing))) crossing,
    ];
    if (!_same(marks, _marks)) _marks = marks;
    _read = live.prior.keys.toSet();
    _crossed = crossed;
    _goalsRead = read;
    _ticked = ticked;

    final note = _note.value;
    if (fresh.isEmpty && reached.isEmpty && note == null) return;
    // after the frame: a note, a buzz and an offer are not things a build does
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final record = fresh.lastOrNull;
      if (record != null || reached.isNotEmpty) {
        switch ((on, record)) {
          case (true, _):
            _show((
              setId: record?.setId,
              exercise: record?.exercise,
              kinds: record?.kinds ?? const [],
              goals: reached,
            ));
          case (false, (:final setId, exercise: _, kinds: _)?):
            live.offerUnder(setId);
          case (false, null):
            if (touched.lastOrNull case final String setId) live.offerUnder(setId, forGoal: true);
        }
      } else if (note != null && identical(_note.value, note)) {
        final kinds = note.kinds.where((kind) => marks[note.setId]?.contains(kind) ?? false).toList();
        final goals = note.goals.where((crossing) => crossed.contains(crossingKey(crossing))).toList();
        if (kinds.isEmpty && goals.isEmpty) {
          _withdraw();
        } else if (kinds.length < note.kinds.length || goals.length < note.goals.length) {
          _note.value = (setId: note.setId, exercise: note.exercise, kinds: kinds, goals: goals);
        }
      }
    });
  }

  void _show(_LiveNote note) {
    if (note.goals.isEmpty) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
      _celebrate(full: note.goals.any(isFinalRung));
    }
    _note.value = note;
    _noteTimer?.cancel();
    _noteTimer = Timer(_noteFor, _withdraw);
  }

  /// One burst at a time: two goals on one tick are one burst, the bigger,
  /// and a new one replaces whatever is still falling. With less motion asked
  /// for (#595) there is none — the note alone says it.
  void _celebrate({required bool full}) {
    if (lessMotion(context)) return;
    _burst.value = (serial: ++_bursts, full: full);
    _burstTimer?.cancel();
    _burstTimer = Timer(_burstFor(full: full), () => _burst.value = null);
  }

  void _withdraw() {
    _noteTimer?.cancel();
    _noteTimer = null;
    _note.value = null;
    _burstTimer?.cancel();
    _burstTimer = null;
    _burst.value = null;
  }

  static bool _same(RecordMarks a, RecordMarks b) {
    return a.length == b.length && a.entries.every((entry) => listEquals(entry.value, b[entry.key]));
  }
}

/// The set the feature's one offer, and the notice after a no, sit under.
class _LiveRecordAnchor extends InheritedWidget {
  final String? setId;

  const new({required this.setId, required super.child});

  static String? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LiveRecordAnchor>()?.setId;

  @override
  bool updateShouldNotify(_LiveRecordAnchor old) => setId != old.setId;
}

/// Under a set row: the offer of live records, or the one notice after a no —
/// when this is the set they are anchored to. Nothing anywhere else.
class _LiveRecordOffer extends StatelessWidget {
  final String setId;

  const new({required this.setId});

  @override
  Widget build(BuildContext context) {
    if (_LiveRecordAnchor.of(context) != setId) return const SizedBox.shrink();
    const feature = Feature.liveRecords;
    final preferences = Preferences.watch(context);
    final l = L.of(context);

    final Widget? child = switch (preferences) {
      _ when preferences.owesDeclineNotice(feature) => FeatureDeclinedNotice(
        onDismiss: () => preferences.acknowledgeDeclineNotice(feature),
      ),
      _ when preferences.shouldOffer(feature) => FeatureOffer(
        key: WorkoutDetailKeys.liveRecordsOffer,
        acceptKey: WorkoutDetailKeys.liveRecordsAccept,
        declineKey: WorkoutDetailKeys.liveRecordsDecline,
        icon: feature.icon,
        title: LiveRecords.watch(context).offeredForGoal ? l.liveGoalsOfferTitle : l.liveRecordsOfferTitle,
        body: l.liveRecordsOfferBody,
        onAnswer: (yes) => preferences.answerOffer(feature, yes: yes),
        onShown: () => preferences.markOffered(feature),
      ),
      _ => null,
    };

    return switch (child) {
      final Widget child => Padding(padding: const .fromLTRB(16, 4, 16, 8), child: child),
      null => const SizedBox.shrink(),
    };
  }
}

/// The note itself: "New record" with the exercise and the records the set
/// beat, "Goal reached" with each rung a tick just reached, or both, one under
/// the other. Quiet — the accent only on the glyphs and the headings — and
/// said to a screen reader as it arrives.
class _LiveNoteCard extends StatelessWidget {
  final _LiveNote note;

  const new({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final l = L.of(context);
    final sections = [
      if (note case (exercise: final Exercise exercise, :final kinds, setId: _, goals: _) when kinds.isNotEmpty)
        (
          icon: Icons.emoji_events_rounded,
          color: colorScheme.tertiary,
          heading: l.recordsAchievedHeading(kinds.length),
          lines: [l.liveRecordLine(exercise.name, kinds.map((kind) => recordKindLabel(context, kind)).join(', '))],
        ),
      if (note.goals case final goals when goals.isNotEmpty)
        (
          icon: Icons.flag_rounded,
          color: colorScheme.primary,
          heading: l.goalsAchievedHeading(goals.length),
          lines: [for (final crossing in goals) _goalLine(context, crossing)],
        ),
    ];

    return Semantics(
      key: WorkoutDetailKeys.liveRecordNote,
      liveRegion: true,
      container: true,
      label: [
        for (final (icon: _, color: _, :heading, :lines) in sections) [heading, ...lines].join('. '),
      ].join('. '),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          border: .all(color: colorScheme.outlineVariant, width: .5),
          borderRadius: const .all(.circular(12)),
          boxShadow: [
            BoxShadow(color: colorScheme.shadow.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 14, vertical: 10),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              for (final (:icon, :color, :heading, :lines) in sections)
                _LiveNoteSection(icon: icon, color: color, heading: heading, lines: lines),
            ],
          ),
        ),
      ),
    );
  }

  /// A rung as the Done page states it: the goal, and the target in the
  /// user's own units.
  static String _goalLine(BuildContext context, GoalAchievement crossing) {
    final (:goal, :stage) = crossing;
    final exercises = Exercises.of(context);
    final scale = goalScale(goal, exercises);
    final target = goalTargetLabel(context, goal, stage.target, settings: Preferences.of(context), scale: scale);
    return L.of(context).goalAchievedTarget(goalTitle(context, goal, goalExercise(goal, exercises)), target);
  }
}

class _LiveNoteSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String heading;
  final List<String> lines;

  const new({required this.icon, required this.color, required this.heading, required this.lines});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Row(
      mainAxisSize: .min,
      spacing: 10,
      children: [
        Icon(icon, size: 20, color: color),
        Flexible(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              Text(heading, style: textTheme.titleSmall?.copyWith(color: color)),
              for (final line in lines)
                Text(
                  line,
                  maxLines: 2,
                  overflow: .ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
