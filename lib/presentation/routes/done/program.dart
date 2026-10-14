part of 'done.dart';

/// A program's block beside the records (#351): where the session left the
/// program, what its rules moved (#350), each with a quiet "Keep" that takes
/// that one move back, and what is next. Absent for a workout of no program,
/// and with Programs off: the page is then as it always was.
class _ProgramBlock extends StatefulWidget {
  final Workout workout;

  /// What the program's rules made of the session, resolved once the finish
  /// has written it. Asked on every build, so it hands back the one future it
  /// holds rather than starting another.
  final Future<List<GrowthMove>> Function() callback;

  const new({required this.workout, required this.callback});

  @override
  State<_ProgramBlock> createState() => _ProgramBlockState();
}

class _ProgramBlockState extends State<_ProgramBlock> {
  /// The moves taken back with "Keep", which stay on the page, said as kept.
  final _kept = ValueNotifier<Set<GrowthMove>>(const {});

  @override
  void dispose() {
    _kept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programs = Programs.watch(context);
    final program = switch (widget.workout.programId) {
      final String id => programs.lookup(id),
      null => null,
    };
    if (program == null || !Preferences.watch(context).isOn(.programs)) return const SizedBox.shrink();

    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final quiet = textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    final position = programs.position(program, now: DateTime.now(), firstWeekday: firstWeekdayOf(context));
    final next = switch (position.next) {
      final String id => Templates.of(context).lookup(id),
      null => null,
    };
    final week = switch (program.weeks) {
      final int weeks => copy.programWeekOf(position.week, weeks),
      null => copy.programWeek(position.week),
    };

    return Padding(
      padding: const .fromLTRB(16, 24, 16, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Column(
          key: AppKeys.doneProgram,
          spacing: 4,
          children: [
            Text(program.name, style: textTheme.titleMedium, textAlign: .center),
            Text(
              [
                week,
                if (position.target case final int target) copy.programThisWeek(position.thisWeek, target),
              ].join(' · '),
              style: quiet,
              textAlign: .center,
            ),
            FutureBuilder<List<GrowthMove>>(
              // asked again as Programs changes: the answer is held there, the
              // same future once there is one
              future: widget.callback(),
              builder: (context, snapshot) {
                return ValueListenableBuilder<Set<GrowthMove>>(
                  valueListenable: _kept,
                  builder: (context, kept, _) {
                    return Column(
                      children: [
                        for (final move in snapshot.data ?? const <GrowthMove>[])
                          _MoveRow(
                            move: move,
                            workout: widget.workout,
                            rule: program.rules[move.exerciseId],
                            kept: kept.contains(move),
                            onKeep: () => _keep(programs, move),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            if (next != null && !position.finished)
              Text(
                copy.doneProgramNext(
                  switch (next.name) {
                    final String name when name.isNotEmpty => name,
                    _ => copy.template,
                  },
                ),
                style: quiet,
                textAlign: .center,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _keep(Programs programs, GrowthMove move) async {
    _kept.value = {..._kept.value, move};
    await programs.keep(move);
  }
}

/// One move in words, and its "Keep" until it is taken.
class _MoveRow extends StatelessWidget {
  final GrowthMove move;

  /// The session it was made of, which holds the exercise as it was done.
  final Workout workout;
  final GrowthRule? rule;
  final bool kept;
  final VoidCallback onKeep;

  const new({
    required this.move,
    required this.workout,
    required this.rule,
    required this.kept,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final exercises = Exercises.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final exercise =
        workout.map((each) => each.exercise).where((each) => each.id == move.exerciseId).firstOrNull ??
        exercises.lookup(move.exerciseId);
    if (exercise == null) return const SizedBox.shrink();

    final measure = GrowthMeasure.of(context, exercise, rule);
    String nameOf(String id) => exercises.lookup(id)?.name ?? id;

    final line = switch (move.step) {
      Grow(:final value) when move.isTest => copy.doneProgramTested(exercise.name, measure.format(value)),
      Grow(:final value) => switch (move.before) {
        final num before => copy.doneProgramMoved(exercise.name, measure.format(before), measure.format(value)),
        null => copy.doneProgramTested(exercise.name, measure.format(value)),
      },
      Cut(:final value) => copy.doneProgramCut(exercise.name, measure.format(value)),
      Missed(:final streak) => copy.doneProgramMissed(exercise.name, streak, move.cutAfter ?? streak),
      Advance(:final to) => copy.doneProgramAdvanced(exercise.name, nameOf(to)),
      Hold() => null,
    };
    if (line == null) return const SizedBox.shrink();

    // what "Keep" keeps: the base before, or the rung; a first training max
    // had nothing before it, and taking it back is an undo
    final keeps = switch ((move.step, move.before)) {
      (Advance(), _) => exercise.name,
      (_, final num before) => measure.format(before),
      (_, null) => null,
    };
    final undoable = move.base != null || move.action != null;

    return Padding(
      padding: const .only(top: 8),
      child: Column(
        children: [
          Text(
            line,
            style: textTheme.bodyMedium?.copyWith(
              color: switch (kept) {
                true => colorScheme.outline,
                false => colorScheme.onSurface,
              },
              decoration: switch (kept) {
                true => TextDecoration.lineThrough,
                false => null,
              },
            ),
            textAlign: .center,
          ),
          if (undoable)
            switch (kept) {
              true => Text(
                copy.doneProgramKept(keeps ?? exercise.name),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              false => TextButton(
                // a quiet button, but a whole finger's worth of one
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onKeep,
                child: Text(
                  switch (keeps) {
                    final String keeps => copy.doneProgramKeep(keeps),
                    null => copy.undo,
                  },
                ),
              ),
            },
        ],
      ),
    );
  }
}
