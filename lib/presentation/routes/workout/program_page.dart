part of 'workout.dart';

/// A program behind its band (#347): where the user stands, the steers, the
/// sessions in order, and how each exercise grows where a rule says it does.
///
/// Every steer is history, not state, so none of them asks first: each lands
/// at once with an Undo beside it, which deletes the step it took.
class ProgramPage extends StatelessWidget {
  final String programId;
  final VoidCallback onEdit;

  /// Opens the template editor on the session [Templates.editable] holds.
  final VoidCallback onEditSession;
  final VoidCallback onOpenActiveWorkout;

  /// Leaves the page once the program is deleted.
  final VoidCallback onGone;

  const new({
    super.key,
    required this.programId,
    required this.onEdit,
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
    final position = programs.position(program, now: DateTime.now(), firstWeekday: _firstWeekday(context));
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
                      _Steers(program: program, position: position),
                    ],
                    const SizedBox(height: 24),
                    Text(copy.programSessions, style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final session in sessions)
                      _SessionTile(
                        session: session,
                        state: switch (session.id) {
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
                    _Growth(program: program),
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
  int _dayOrder(BuildContext context, int day) => (day - _firstWeekday(context)) % 7;

  Future<void> _start(BuildContext context, Template session) async {
    final started = await startWorkoutOverActive(
      context,
      () => Workouts.of(context).startWorkout(source: .program, template: session.toWorkout(), applyPinnedNotes: true),
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

/// Repeat, pause or resume, and back to an earlier week. Repeat sits first and
/// looks like the others: running a week again is a choice, never a failure.
///
/// One step at a time: while one is on its way the buttons rest, or a second
/// tap of Repeat would record a second repeat — which reads as a week back.
class _Steers extends StatefulWidget {
  final Program program;
  final ProgramPosition position;

  const new({required this.program, required this.position});

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

  Future<void> _steer(BuildContext context, ProgramActionKind kind, {int? week}) async {
    if (_busy.value) return;
    final copy = L.of(context);
    final programs = Programs.of(context);
    final messenger = ScaffoldMessenger.of(context);
    Analytics.of(context).programSteered(action: kind);

    _busy.value = true;
    try {
      final action = await programs.act(widget.program, kind, week: week);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (kind) {
            .repeat => copy.programRepeated,
            .pause => copy.programPausedNotice,
            .resume => copy.programResumed,
            .replay => copy.programReplayed(week ?? 1),
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
  final Template session;
  final _SessionState state;
  final VoidCallback onTap;

  const new({required this.session, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final name = _sessionName(copy, session);
    final exercises = session.map((exercise) => exercise.exercise.name).join(', ');

    return Semantics(
      label: switch (state) {
        .done => copy.programSessionDone(name),
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
            .next => Icons.play_circle_outline_rounded,
            .ahead => Icons.circle_outlined,
          },
          color: switch (state) {
            .done => colorScheme.outline,
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
    );
  }
}

/// How each exercise grows (#350 sets the rules): its rule in a sentence, and
/// where its base has been. Absent while no exercise has either, which is a
/// program made from a folder until the user gives it rules.
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
    final ids = {...program.rules.keys, ...bases.map((base) => base.exerciseId)};
    if (ids.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const .only(top: 24),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Text(copy.programGrowth, style: textTheme.titleSmall),
          for (final id in ids)
            if (exercises.lookup(id) case final Exercise exercise)
              _GrowthRow(
                exercise: exercise,
                rule: program.rules[id],
                history: [
                  for (final base in bases)
                    if (base.exerciseId == id) base.value,
                ],
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
        ],
      ),
    );
  }
}

class _GrowthRow extends StatelessWidget {
  final Exercise exercise;
  final GrowthRule? rule;
  final List<num> history;
  final TextStyle? style;

  const new({required this.exercise, required this.rule, required this.history, required this.style});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final measure = _Measure.of(context, exercise, rule);
    final line = switch (rule) {
      null || NoGrowth() => copy.ruleAsWritten,
      AddWeight(:final step) => copy.ruleAddWeight(measure.format(step)),
      RangeThenWeight(:final step) => copy.ruleRangeThenWeight(measure.format(step)),
      Longer(:final step) => copy.ruleLonger(measure.format(step)),
      ShareOfMax(:final step) => copy.ruleShareOfMax(measure.format(step)),
    };

    return Column(
      crossAxisAlignment: .start,
      spacing: 2,
      children: [
        Text(exercise.name, style: Theme.of(context).textTheme.titleSmall),
        Text(line, style: style),
        if (history.isNotEmpty) Text(history.map(measure.format).join(' → '), style: style),
      ],
    );
  }
}

/// What a rule's numbers measure on [exercise], and how they read: a weight
/// in the user's unit, a time in seconds, or a distance in theirs — a carry's
/// in metres or yards, as its sets show it.
class _Measure {
  final String Function(num) format;

  const new(this.format);

  factory of(BuildContext context, Exercise exercise, GrowthRule? rule) {
    final copy = L.of(context);
    final preferences = Preferences.of(context);
    final override = Exercises.of(context).unitFor(exercise.id);
    final unit = override ?? preferences.weightUnit;

    String weight(num value) {
      final label = switch (unit) {
        .imperial => copy.lbs,
        .metric => copy.kg,
      };
      return '${preferences.weight(value, unit: unit)} $label';
    }

    String distance(num value) {
      final label = switch (override ?? preferences.distanceUnit) {
        .imperial => copy.milesPlural,
        .metric => copy.km,
      };
      return '${preferences.distance(value, unit: override)} $label';
    }

    String carried(num value) {
      final label = switch (override ?? preferences.distanceUnit) {
        .imperial => copy.yardsShort,
        .metric => copy.metresShort,
      };
      return '${preferences.shortDistance(value, unit: override)} $label';
    }

    String seconds(num value) => '${value.round()} ${copy.sec}';

    return switch (rule) {
      Longer() => switch (exercise.category) {
        .cardio => _Measure(distance),
        .weightedDistance => _Measure(carried),
        .duration ||
        .weightedDuration ||
        .barbell ||
        .dumbbell ||
        .machine ||
        .weightedBodyWeight ||
        .assistedBodyWeight ||
        .repsOnly => _Measure(seconds),
      },
      null || NoGrowth() || AddWeight() || RangeThenWeight() || ShareOfMax() => _Measure(weight),
    };
  }
}
