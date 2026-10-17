part of 'workout.dart';

/// A program behind its band (#347): where the user stands, the steers, the
/// sessions in order, and how each exercise grows where a rule says it does.
///
/// Every steer is history, not state, so none of them asks first: each lands
/// at once with an Undo beside it, which deletes the step it took.
class ProgramPage extends StatelessWidget {
  final String programId;
  final VoidCallback onEdit;

  /// Opens the library program [Program.source] names, with its research.
  final void Function(String key) onAbout;

  /// Opens the template editor on the session [Templates.editable] holds.
  final VoidCallback onEditSession;
  final VoidCallback onOpenActiveWorkout;

  /// Leaves the page once the program is deleted.
  final VoidCallback onGone;

  const new({
    super.key,
    required this.programId,
    required this.onEdit,
    required this.onAbout,
    required this.onEditSession,
    required this.onOpenActiveWorkout,
    required this.onGone,
  });

  @override
  Widget build(BuildContext context) {
    final programs = Programs.watch(context);
    final program = programs.lookup(programId);
    // deleted, here or on another device, while the page is open
    if (program == null) return Scaffold(appBar: AppBar());

    return _ProgramsOnly(child: _page(context, programs, program));
  }

  Widget _page(BuildContext context, Programs programs, Program program) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final sessions = Templates.watch(context).sessionsOf(program);
    final position = programs.position(
      program,
      now: DateTime.now(),
      firstWeekday: firstWeekdayOf(context, listen: true),
    );
    final skipped = programs.skippedIn(program, position);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Scaffold(
      appBar: AppBar(
        title: Text(program.name),
        actions: [
          IconButton(tooltip: copy.editProgram, onPressed: onEdit, icon: const Icon(Icons.edit_rounded)),
          PopupMenuButton<VoidCallback>(
            tooltip: copy.moreOptions,
            icon: const Icon(Icons.more_horiz),
            constraints: const BoxConstraints.tightFor(width: 224),
            onSelected: (action) => action(),
            itemBuilder: (_) {
              return [
                // the user's list, not this program's: reachable from any
                // program while the map is published (#396)
                if (GoEasy.of(context).content?.title case final ContentText title)
                  PopupMenuItem<VoidCallback>(
                    value: () => showGoEasySheet(context),
                    child: _MenuRow(icon: Icons.spa_outlined, label: title.of(languageTag())),
                  ),
                PopupMenuItem<VoidCallback>(
                  value: () => programs.archive(program, archived: !program.archived),
                  child: _MenuRow(
                    icon: program.archived ? Icons.play_arrow_rounded : Icons.archive_outlined,
                    label: program.archived ? copy.programFollowAgain : copy.programStopFollowing,
                  ),
                ),
                PopupMenuItem<VoidCallback>(
                  value: () => _delete(context, program),
                  child: _MenuRow(icon: Icons.delete, label: copy.programDelete, color: colorScheme.error),
                ),
              ];
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: .topCenter,
              child: SizedBox(
                width: min(constraints.maxWidth, readableWidth),
                child: ListView(
                  padding: const .all(16),
                  children: [
                    Text(_status(copy, program, position), style: textTheme.titleLarge),
                    if (_standing(context, program, position) case final String line) ...[
                      const SizedBox(height: 4),
                      Text(line, style: muted),
                    ],
                    if (!program.archived) ...[
                      const SizedBox(height: 12),
                      _Steers(
                        program: program,
                        position: position,
                        upNext: sessions.where((session) => session.id == position.next).firstOrNull,
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(copy.programSessions, style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final (index, session) in sessions.indexed)
                      _SessionTile(
                        program: program,
                        session: session,
                        // the sessions as one sequence, joined like a log
                        rail: (above: index > 0, below: index < sessions.length - 1),
                        state: switch (session.id) {
                          final id when skipped.contains(id) => .skipped,
                          final id when position.done.contains(id) => .done,
                          final id when id == position.next => .next,
                          _ => .ahead,
                        },
                        onTap: () => _showStartTemplateDialog(
                          context,
                          session,
                          onEdit: () {
                            Templates.of(context).editable = session;
                            onEditSession();
                          },
                          onStart: () => _start(context, session),
                        ),
                      ),
                    ProgramConstraintRow(program: program),
                    if (!program.archived) _ProgramCalendarSlot(program: program),
                    _ProgramGoals(program: program, position: position, sessions: sessions),
                    _Growth(program: program),
                    // a copy of one of Heart's programs keeps its way back to
                    // the research, which stays in the library, never the copy
                    if (program.source case final String key)
                      _LibraryReader(
                        child: Builder(
                          builder: (context) {
                            return switch (ProgramLibrary.watch(context).lookup(key)) {
                              null => const SizedBox.shrink(),
                              LibraryProgram() => Padding(
                                padding: const .only(top: 16),
                                child: ListTile(
                                  key: AppKeys.programAbout,
                                  contentPadding: .zero,
                                  leading: const Icon(Icons.auto_stories_outlined),
                                  title: Text(copy.programAboutLibrary),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => onAbout(key),
                                ),
                              ),
                            };
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// This calendar week against the target, and the preferred days: the line
  /// under the week. Nothing while paused, which never counts against a week.
  String? _standing(BuildContext context, Program program, ProgramPosition position) {
    final copy = L.of(context);
    final locale = copy.localeName;
    final parts = [
      if ((program.perWeek, position.paused) case (final int target, false))
        copy.programThisWeek(position.thisWeek, target),
      if (program.days.isNotEmpty)
        (program.days.toList()..sort((a, b) => _dayOrder(context, a).compareTo(_dayOrder(context, b))))
            .map((day) => DateFormat.E(locale).format(DateTime(2024, 1, 7 + day % 7)))
            .join(', '),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// [day]'s place in the user's week, from their first day.
  int _dayOrder(BuildContext context, int day) => (day - firstWeekdayOf(context)) % 7;

  Future<void> _start(BuildContext context, Template session) async {
    final started = await startWorkoutOverActive(
      context,
      () =>
          Workouts.of(context)
              .startWorkout(source: .program, template: startingWorkout(context, session), applyPinnedNotes: true),
    );
    if (started) onOpenActiveWorkout();
  }

  /// Asks what happens to the sessions, and keeping them is the default: they
  /// become plain templates where they are. A dismissal deletes nothing.
  Future<void> _delete(BuildContext context, Program program) async {
    final copy = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final programs = Programs.of(context);
    final analytics = Analytics.of(context);

    final keep = await showBrandedDialog<bool>(
      context,
      title: Text(copy.programDeleteTitle(program.name), textAlign: .center),
      content: Text(copy.programDeleteBody, textAlign: .center),
      actions: [
        Builder(
          builder: (context) {
            void answer({bool? keep}) => Navigator.of(context, rootNavigator: true).pop(keep);
            return Column(
              spacing: 8,
              children: [
                PrimaryButton.wide(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  onPressed: answer,
                  child: Center(child: Text(copy.cancel)),
                ),
                PrimaryButton.wide(
                  backgroundColor: colorScheme.errorContainer,
                  onPressed: () => answer(keep: false),
                  child: Center(
                    child: Text(copy.programDeleteTemplates, style: TextStyle(color: colorScheme.onErrorContainer)),
                  ),
                ),
                PrimaryButton.wide(
                  onPressed: () => answer(keep: true),
                  child: Center(child: Text(copy.programKeepTemplates)),
                ),
              ],
            );
          },
        ),
      ],
    );
    if (keep == null) return;

    onGone();
    await programs.delete(program, keepTemplates: keep);
    analytics.programDeleted(keptTemplates: keep);
  }
}

/// A menu entry's icon and words.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const new({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme) = Theme.of(context);
    return Row(
      spacing: 8,
      children: [
        Icon(icon, size: 16, color: color),
        Flexible(
          child: Text(
            label,
            style: textTheme.titleSmall?.copyWith(color: color),
            maxLines: 1,
            overflow: .ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Repeat, pause or resume, a lighter week, and back to an earlier week.
/// Repeat sits first and looks like the others: running a week again is a
/// choice, never a failure.
///
/// One step at a time: while one is on its way the buttons rest, or a second
/// tap of Repeat would record a second repeat — which reads as a week back.
class _Steers extends StatefulWidget {
  final Program program;
  final ProgramPosition position;

  /// The session "Not today" (#312) sets aside; none once finished.
  final Template? upNext;

  const new({required this.program, required this.position, required this.upNext});

  @override
  State<_Steers> createState() => _SteersState();
}

class _SteersState extends State<_Steers> {
  final _busy = ValueNotifier(false);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:colorScheme) = Theme.of(context);
    final fill = colorScheme.surfaceContainerHighest;
    final position = widget.position;

    return ValueListenableBuilder<bool>(
      valueListenable: _busy,
      builder: (context, busy, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: .center,
          children: [
            // the steer a day asks for most: first, and only while something
            // is due
            if ((widget.upNext, position.paused, position.finished) case (final Template session, false, false))
              PrimaryButton.shrunk(
                key: AppKeys.programNotToday(widget.program.id),
                backgroundColor: fill,
                onPressed: () => _notToday(context, widget.program, session, fromBand: false),
                child: Text(copy.programNotToday),
              ),
            PrimaryButton.shrunk(
              backgroundColor: fill,
              onPressed: switch (busy) {
                true => null,
                false => () => _steer(context, .repeat),
              },
              child: Text(copy.programRepeat),
            ),
            if (!position.finished)
              PrimaryButton.shrunk(
                backgroundColor: fill,
                onPressed: switch (busy) {
                  true => null,
                  false => () => _steer(context, position.paused ? .resume : .pause),
                },
                child: Text(position.paused ? copy.programResume : copy.programPause),
              ),
            // a lighter cycle the user asks for (heart-api#229): this one, until
            // it closes; one the program schedules says so on the sheet
            if (!position.finished && !position.lighter)
              PrimaryButton.shrunk(
                backgroundColor: fill,
                onPressed: switch (busy) {
                  true => null,
                  false => () => _steer(context, .lighter),
                },
                child: Text(copy.programLighter),
              ),
            if (position.week > 1)
              PopupMenuButton<int>(
                tooltip: copy.programReplayTitle,
                enabled: !busy,
                constraints: const BoxConstraints.tightFor(width: 168),
                onSelected: (week) => _steer(context, .replay, week: week),
                itemBuilder: (_) {
                  return [
                    for (final week in List.generate(position.week - 1, (index) => index + 1))
                      PopupMenuItem<int>(value: week, child: Text(copy.programWeek(week))),
                  ];
                },
                child: Container(
                  margin: const .symmetric(vertical: 6),
                  padding: const .symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: fill, borderRadius: const .all(.circular(8))),
                  child: Text(copy.programReplay),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _steer(BuildContext context, _Steer steer, {int? week}) async {
    if (_busy.value) return;
    final copy = L.of(context);
    final programs = Programs.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final _Steer(:kind) = steer;
    Analytics.of(context).programSteered(action: kind);

    _busy.value = true;
    try {
      final action = await programs.act(widget.program, kind, week: week);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (steer) {
            .repeat => copy.programRepeated,
            .pause => copy.programPausedNotice,
            .resume => copy.programResumed,
            .replay => copy.programReplayed(week ?? 1),
            .lighter => copy.programLighterNotice,
          }),
          action: SnackBarAction(label: copy.undo, onPressed: () => programs.undo(action)),
        ),
      );
    } finally {
      if (mounted) _busy.value = false;
    }
  }
}

/// A session in the program's order, marked done, next or ahead in the open
/// cycle. Tapped, it opens the same sheet a template card does.
class _SessionTile extends StatelessWidget {
  final Program program;
  final Template session;
  final _SessionState state;
  final VoidCallback onTap;

  /// Whether the rail through the icons runs on above and below this one.
  final ({bool above, bool below}) rail;

  const new({
    required this.program,
    required this.session,
    required this.state,
    required this.onTap,
    required this.rail,
  });

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final name = _sessionName(copy, session);
    final exercises = session.map((exercise) => exercise.exercise.name).join(', ');
    // what in it is harder on something the user goes easy on (#396)
    final marked = [
      for (final exercise in session)
        if (goEasyMarks(context, exercise.exercise).isNotEmpty) exercise.exercise,
    ];

    final tile = CustomPaint(
      painter: _Rail(
        above: rail.above,
        below: rail.below,
        color: colorScheme.outlineVariant,
        rtl: Directionality.of(context) == .rtl,
      ),
      child: Semantics(
        label: switch (state) {
          .done => copy.programSessionDone(name),
          .skipped => copy.programSessionSkipped(name),
          .next => copy.programSessionNext(name),
          .ahead => name,
        },
        button: true,
        excludeSemantics: true,
        child: ListTile(
          contentPadding: .zero,
          onTap: onTap,
          leading: Icon(
            switch (state) {
              .done => Icons.check_circle_rounded,
              .skipped => Icons.redo_rounded,
              .next => Icons.play_circle_outline_rounded,
              .ahead => Icons.circle_outlined,
            },
            color: switch (state) {
              .done || .skipped => colorScheme.outline,
              .next => colorScheme.primary,
              .ahead => colorScheme.outlineVariant,
            },
          ),
          title: Text(name, maxLines: 1, overflow: .ellipsis),
          subtitle: switch (exercises.isEmpty) {
            true => null,
            false => Text(
              exercises,
              maxLines: 1,
              overflow: .ellipsis,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          },
        ),
      ),
    );

    // beside the tile, not in it: the tile reads as one button, and this one
    // has its own say
    return switch (marked) {
      [] => tile,
      _ => Row(
        children: [
          Expanded(child: tile),
          IconButton(
            key: AppKeys.goEasySessionMark,
            tooltip: copy.goEasySessionMarked(marked.length),
            icon: Icon(Icons.spa_outlined, color: colorScheme.onSurfaceVariant),
            onPressed: () => showKinderSwaps(context, marked, candidates: _kinderCandidates(context, program)),
          ),
        ],
      ),
    };
  }
}

/// The line joining the sessions' icons, as a log joins its commits: down the
/// middle of the leading icon, from the tile's top to the icon and from the
/// icon to its bottom, so it meets the next tile's at any height. Drawn behind
/// the tile; the icon sits in a gap of its own.
class _Rail extends CustomPainter {
  final bool above;
  final bool below;
  final Color color;

  /// Right to left: the leading icon, and so the rail, is on the right.
  final bool rtl;

  const new({required this.above, required this.below, required this.color, required this.rtl});

  /// The leading icon's size, at a ListTile's zero inset.
  static const _icon = 24.0;

  /// Clear space around the icon, so the line doesn't touch it.
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final x = switch (rtl) {
      false => _icon / 2,
      true => size.width - _icon / 2,
    };
    final middle = size.height / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    if (above) canvas.drawLine(Offset(x, 0), Offset(x, middle - _icon / 2 - _gap), paint);
    if (below) canvas.drawLine(Offset(x, middle + _icon / 2 + _gap), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_Rail old) {
    return above != old.above || below != old.below || color != old.color || rtl != old.rtl;
  }
}

/// How each exercise grows (#350 sets the rules): its rule in a sentence, and
/// where its base has been, under the program's lighter weeks if it keeps
/// any. Absent while it has none of these, which is a program made from a
/// folder until the user gives it rules.
/// What the program is heading for (#353): the goals it implies and the
/// user's own it grows, each with where it lands at this pace. Derived goals
/// are never stored: at the end, one not reached can be kept as a goal, and a
/// program whose goals were reached runs again from week 1, heavier — from
/// the maxes it grew. A goal on a movement pattern none of the sessions
/// train says so, before the program asks anything of the user.
class _ProgramGoals extends StatelessWidget {
  final Program program;
  final ProgramPosition position;
  final List<Template> sessions;

  const new({required this.program, required this.position, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final goals = Goals.watch(context);
    final programs = Programs.watch(context);
    final exercises = Exercises.watch(context);
    final id = program.id!;
    final bases = programs.basesOf(id);
    final sessionsDone = programs.sessionsDone(id);
    final feed = (program: program, position: position, bases: bases, sessionsDone: sessionsDone);

    final implied = impliedGoals(program, bases: bases, held: goals.all);
    final grown = [
      for (final goal in goals.all)
        if (goal.cadence == null && program.rules.containsKey(goal.exerciseId)) goal,
    ];
    final trained = {
      for (final session in sessions)
        for (final WorkoutExercise(:exercise) in session)
          ...(exercises.lookup(exercise.id) ?? exercise).movement.groups,
    };
    final untrained = {
      for (final goal in goals.all)
        if (goal.subject case PatternSubject(:final key) when !trained.contains(key)) key,
    };
    if (implied.isEmpty && grown.isEmpty && untrained.isEmpty) return const SizedBox.shrink();

    // the end judged by the bases, the way the forecast reads them
    bool reached(Goal goal) {
      final forecast = forecastOf(
        goal,
        current: null,
        program: program,
        position: position,
        bases: bases,
        sessionsDone: sessionsDone,
      );
      return forecast is ForecastReached;
    }

    final finished = position.finished;
    final lensSets = sharedLensSets(Stats.of(context).getLensSets);
    final workouts = context.select<Stats, WorkoutAggregation>((stats) => stats.workouts);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const .only(top: 24),
      child: Column(
        key: AppKeys.programGoals,
        crossAxisAlignment: .stretch,
        spacing: 8,
        children: [
          Text(copy.goals, style: textTheme.titleSmall),
          for (final key in untrained) Text(copy.programGoalNoPattern(patternLabel(key, copy)), style: muted),
          for (final each in implied) ...[
            GoalRow(
              key: AppKeys.goalRow(each.goal.id),
              goal: each.goal,
              workouts: workouts,
              lensSets: lensSets,
              feeds: [feed],
            ),
            if (finished && !reached(each.goal))
              Align(
                alignment: .centerLeft,
                child: PrimaryButton.shrunk(
                  key: AppKeys.programGoalKeep(each.goal.id),
                  onPressed: () => _keep(context, each),
                  child: Text(copy.programGoalKeep),
                ),
              ),
          ],
          for (final goal in grown)
            GoalRow(
              key: AppKeys.goalRow(goal.id),
              goal: goal,
              workouts: workouts,
              lensSets: lensSets,
              feeds: [feed],
            ),
          if (finished && [...implied.map((each) => each.goal), ...grown].any(reached))
            Align(
              alignment: .centerLeft,
              child: PrimaryButton.shrunk(
                key: AppKeys.programAgain,
                onPressed: () => _again(context),
                child: Text(copy.programAgainHeavier),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _keep(BuildContext context, ImpliedGoal implied) async {
    final copy = L.of(context);
    final analytics = Analytics.of(context);
    try {
      await Goals.of(context).create(implied.kept);
      analytics.programGoalKept();
      if (context.mounted) snack(context, copy.programGoalKept);
    } on GoalRejected catch (rejection) {
      if (!context.mounted) return;
      snack(
        context,
        switch (rejection.isAtCapacity) {
          true => copy.goalsAtCapacity,
          false => rejection.toString(),
        },
      );
    }
  }

  /// Week 1 again, from the bases the program grew: the same plan, heavier.
  Future<void> _again(BuildContext context) async {
    final analytics = Analytics.of(context);
    await Programs.of(context).act(program, .replay, week: 1);
    analytics.programAgain();
  }
}

class _Growth extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = Programs.watch(context);
    final exercises = Exercises.of(context);
    final bases = programs.basesOf(program.id!);
    // an occurrence with a rule or a base of its own (heart-api#256) reads as
    // itself: the exercise its session holds there, and which session
    final occurrences = {
      for (final session in Templates.watch(context).sessionsOf(program))
        for (final exercise in session) exercise.id: (exercise: exercise.exercise, session: session.name),
    };
    final keys = {...program.rules.keys, for (final base in bases) base.slot ?? base.exerciseId};
    final deload = program.deload;
    if (keys.isEmpty && deload == null) return const SizedBox.shrink();
    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toString());
    final style = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const .only(top: 24),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Text(copy.programGrowth, style: textTheme.titleSmall),
          // the program's own lighter weeks, scheduled whatever the exercise
          if (deload case Deload(:final every, :final load, :final volume))
            Text(copy.programDeload(every, percent.format(load), percent.format(volume)), style: style),
          for (final key in keys)
            if (occurrences[key] ?? (exercise: exercises.lookup(key), session: null) case (
              exercise: final Exercise exercise,
              :final session,
            ))
              _GrowthRow(
                exercise: exercise,
                session: session,
                rule: program.rules[key] ?? program.rules[exercise.id],
                history: [
                  for (final base in bases)
                    if ((base.slot ?? base.exerciseId) == key) base.value,
                ],
                style: style,
              ),
        ],
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  final Exercise exercise;

  /// The session of an occurrence with a rule of its own; null for the
  /// exercise's rule, wherever it comes.
  final String? session;
  final GrowthRule? rule;
  final List<num> history;
  final TextStyle? style;

  const new({
    required this.exercise,
    this.session,
    required this.rule,
    required this.history,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final measure = GrowthMeasure.of(context, exercise, rule);
    final line = switch (rule) {
      null || NoGrowth() => copy.ruleAsWritten,
      AddWeight(:final step) => copy.ruleAddWeight(measure.format(step)),
      Ladder(:final top) => copy.ruleLadder(top),
      RangeThenWeight(:final step) => copy.ruleRangeThenWeight(measure.format(step)),
      Longer(:final step) => copy.ruleLonger(measure.format(step)),
      ShareOfMax(:final step) => copy.ruleShareOfMax(measure.format(step)),
      Stages(:final stages, :final step) => copy.ruleStages(
        stages.map((stage) => stage.scheme).join(' → '),
        measure.format(step),
      ),
    };

    final percent = NumberFormat.percentPattern(Localizations.localeOf(context).toString());
    final misses = switch (rule) {
      AddWeight(:final miss) ||
      RangeThenWeight(:final miss) ||
      ShareOfMax(:final miss) when miss.cut > 0 => copy.ruleMisses(miss.after, percent.format(miss.cut)),
      Stages(:final miss) when miss.cut > 0 => copy.ruleStagesCut(percent.format(miss.cut)),
      _ => null,
    };

    return Column(
      crossAxisAlignment: .start,
      spacing: 2,
      children: [
        Text(switch (session) {
          final String session => copy.ruleOccurrence(exercise.name, session),
          null => exercise.name,
        }, style: Theme.of(context).textTheme.titleSmall),
        Text(line, style: style),
        if (rule?.amrap.isNotEmpty ?? false) Text(copy.ruleAmrap, style: style),
        if (misses != null) Text(misses, style: style),
        if (history.isNotEmpty) Text(history.map(measure.format).join(' → '), style: style),
      ],
    );
  }
}

/// What the page's steer buttons take. A ladder's advance is the program's
/// own step (#350), never one of these.
enum _Steer {
  repeat(.repeat),
  pause(.pause),
  resume(.resume),
  replay(.replay),
  lighter(.lighter);

  final ProgramActionKind kind;

  new(this.kind);
}

/// What a kinder swap may be inside [program]: the library, less what its
/// constraint (#355) is harder on.
Iterable<Exercise> _kinderCandidates(BuildContext context, Program program) {
  final exercises = Exercises.of(context);
  return switch (GoEasy.of(context).entryFor(program.constraint)) {
    final GoEasyEntry constraint => exercises.where((each) => !constraint.isHarderOn(each)),
    null => exercises,
  };
}
