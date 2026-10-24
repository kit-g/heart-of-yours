part of 'workout_detail.dart';

/// Live records (#160) over the active workout: a quiet note the moment a
/// ticked working set beats a previous best, and the record pills under the
/// sets that hold one, as a past workout's page has them.
///
/// The records are [liveRecordMarks]: the fold the Done page runs on the
/// finished workout, over the same sets, so what shows here is what that page
/// will say. Unticking or editing a set re-folds, and a record it no longer
/// holds goes, note and pill both.
///
/// Off, the sheet is what it was before the feature: no pills, no note, and
/// nothing read. Never answered, it folds only to find the moment to ask —
/// the first ticked set that would have been a record — and puts the offer
/// under that set.
class _LiveRecordsScope extends StatefulWidget {
  final Widget child;

  const new({required this.child});

  @override
  State<_LiveRecordsScope> createState() => _LiveRecordsScopeState();
}

typedef _LiveNote = ({String setId, Exercise exercise, List<RecordKind> kinds});

class _LiveRecordsScopeState extends State<_LiveRecordsScope> {
  static const _feature = Feature.liveRecords;

  /// How long the note stays: long enough to read two short lines.
  static const _noteFor = Duration(milliseconds: 3500);

  final _note = ValueNotifier<_LiveNote?>(null);
  Timer? _noteTimer;

  /// The marks as of the last build, and the exercises read by then: a mark
  /// is news only when it arrives on an exercise already read. One arriving
  /// with its exercise's read — a workout restored after a restart — was
  /// there all along.
  RecordMarks _marks = const {};
  Set<ExerciseId> _read = const {};

  @override
  void dispose() {
    _noteTimer?.cancel();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = Preferences.watch(context);
    final live = LiveRecords.watch(context);
    // every tick, untick, edit and retype notifies, and each is a re-fold
    final workouts = Workouts.watch(context);
    final on = preferences.isOn(_feature);
    final offering = !on && preferences.shouldOffer(_feature);
    final anchored = offering || preferences.owesDeclineNotice(_feature);

    switch ((on || offering, workouts.userId, workouts.activeWorkout)) {
      case (true, final String userId, final Workout workout):
        live.prime(userId, workout);
        _track(workout, liveRecordMarks(workout, live.prior), live, on: on);
      case _:
        _marks = const {};
        _read = const {};
        if (_note.value != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _withdraw();
          });
        }
    }

    // the same shape whatever the answer, so turning it on from the offer
    // keeps the sheet's scroll where it was
    return RecordMarksScope(
      marks: on ? _marks : const {},
      firstSetId: null,
      child: _LiveRecordAnchor(
        setId: anchored ? live.offeredUnder : null,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              // under the sheet's 40pt header
              top: 48,
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
                          duration: const Duration(milliseconds: 220),
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
                            final _LiveNote note => _LiveRecordNote(
                              key: ValueKey(note),
                              exercise: note.exercise,
                              kinds: note.kinds,
                            ),
                            null => const SizedBox.shrink(),
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Takes in this build's [marks]: what is news is noted (or, unanswered,
  /// offered), and a note whose record went is withdrawn.
  void _track(Workout workout, RecordMarks marks, LiveRecords live, {required bool on}) {
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
    if (!_same(marks, _marks)) _marks = marks;
    _read = live.prior.keys.toSet();

    final note = _note.value;
    if (fresh.isEmpty && note == null) return;
    // after the frame: a note, a buzz and an offer are not things a build does
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (fresh.lastOrNull case final _LiveNote news) {
        if (on) {
          _show(news);
        } else {
          live.offerUnder(news.setId);
        }
      } else if (note != null && identical(_note.value, note)) {
        final standing = note.kinds.where((kind) => marks[note.setId]?.contains(kind) ?? false).toList();
        if (standing.isEmpty) {
          _withdraw();
        } else if (standing.length < note.kinds.length) {
          _note.value = (setId: note.setId, exercise: note.exercise, kinds: standing);
        }
      }
    });
  }

  void _show(_LiveNote note) {
    HapticFeedback.lightImpact();
    _note.value = note;
    _noteTimer?.cancel();
    _noteTimer = Timer(_noteFor, _withdraw);
  }

  void _withdraw() {
    _noteTimer?.cancel();
    _noteTimer = null;
    _note.value = null;
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
        title: l.liveRecordsOfferTitle,
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

/// The note itself: "New record", and the exercise with the records the set
/// beat. Quiet — the accent only on the trophy and the heading — and said to a
/// screen reader as it arrives.
class _LiveRecordNote extends StatelessWidget {
  final Exercise exercise;
  final List<RecordKind> kinds;

  const new({super.key, required this.exercise, required this.kinds});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    final heading = l.recordsAchievedHeading(kinds.length);
    final line = l.liveRecordLine(exercise.name, kinds.map((kind) => recordKindLabel(context, kind)).join(', '));

    return Semantics(
      key: WorkoutDetailKeys.liveRecordNote,
      liveRegion: true,
      container: true,
      label: '$heading. $line',
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
          child: Row(
            mainAxisSize: .min,
            spacing: 10,
            children: [
              Icon(Icons.emoji_events_rounded, size: 20, color: colorScheme.tertiary),
              Flexible(
                child: Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(heading, style: textTheme.titleSmall?.copyWith(color: colorScheme.tertiary)),
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
          ),
        ),
      ),
    );
  }
}
