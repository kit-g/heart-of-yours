part of 'workout.dart';

/// A session joining a running program, and leaving it (#489): picked on the
/// program's page, or one tap from a template sitting in its folder.

extension on Templates {
  /// The folder [program]'s sessions are filed in, when they are: where a
  /// template that may join it is looked for first.
  String? programFolderOf(Program program) {
    return sessionsOf(program).map((session) => session.folderId).nonNulls.firstOrNull;
  }

  /// The user's templates that could join [program], those in its folder
  /// first: every one but its own sessions. One that is another program's
  /// session is among them, to be shown and not picked.
  List<Template> candidatesFor(Program program) {
    final folder = programFolderOf(program);
    final others = where((template) => !program.sessions.contains(template.id)).toList();
    return [
      ...others.where((template) => folder != null && template.folderId == folder),
      ...others.where((template) => folder == null || template.folderId != folder),
    ];
  }
}

/// Opens the picker over [program]'s page, and adds what is picked.
Future<void> _pickSession(BuildContext context, Program program) async {
  final copy = L.of(context);
  final ThemeData(:colorScheme) = Theme.of(context);
  final picked = await showBrandedDialog<Template>(
    context,
    title: Text(copy.programAddSession, textAlign: .center),
    icon: Icon(Icons.playlist_add_rounded, color: colorScheme.onPrimaryContainer),
    content: _SessionPicker(program: program),
  );
  if (picked != null && context.mounted) await _joinProgram(context, program, picked);
}

/// Adds [session] to [program], and gives its lifts their starting weights as
/// starting a program does: from the user's own sets, said in the notice, and
/// changed on the program's page. One with nothing to go on takes its weight
/// from its first session. Undo takes back all of it.
Future<void> _joinProgram(BuildContext context, Program program, Template session) async {
  final copy = L.of(context);
  final programs = Programs.of(context);
  final exercises = Exercises.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final before = programs.lookup(program.id!) ?? program;

  final joined = await programs.join(before, session);
  final seeded = await programs.seedBases(
    joined,
    setsOf: (id) async => switch (exercises.lookup(id)) {
      final Exercise exercise => [
        for (final act in await exercises.getExerciseHistory(exercise, pageSize: 10)) ...act,
      ],
      null => const <ExerciseSet>[],
    },
  );
  final name = _sessionName(copy, session);
  // the page under the picker may have been rebuilt by the join: the
  // messenger is held from before it, and only the units need the context
  final lifts = [
    if (context.mounted)
      for (final base in seeded)
        if (exercises.lookup(base.exerciseId) case final Exercise exercise)
          '${exercise.name} ${GrowthMeasure.of(context, exercise, joined.rules[base.exerciseId]).format(base.value)}',
  ];
  messenger
    ..clearSnackBars()
    ..snack(
      switch (lifts) {
        [] => copy.programSessionAdded(name, program.name),
        _ => copy.programSessionAddedSeeded(name, program.name, lifts.join(', ')),
      },
      action: SnackBarAction(
        label: copy.undo,
        onPressed: () async {
          for (final base in seeded) {
            await programs.deleteBase(base);
          }
          final current = programs.lookup(program.id!);
          if (current == null) return;
          final left = await programs.leave(current, session);
          // the rules and phases it brought, back as they were
          if (left.rules.length != before.rules.length || before.phases.isNotEmpty) {
            await programs.update(left.copyWith(rules: before.rules, phases: before.phases));
          }
        },
      ),
    );
}

/// Takes [session] out of [program], leaving it a plain template. Undo puts
/// it back as it was, joined when it first joined.
Future<void> _leaveProgram(BuildContext context, Program program, Template session) async {
  final copy = L.of(context);
  final programs = Programs.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final current = programs.lookup(program.id!) ?? program;
  final joined = current.joined[session.id];

  await programs.leave(current, session);
  messenger
    ..clearSnackBars()
    ..snack(
      copy.programSessionRemoved(_sessionName(copy, session), program.name),
      action: SnackBarAction(
        label: copy.undo,
        onPressed: () async {
          if (programs.lookup(program.id!) case final Program program) {
            await programs.join(program, session, at: joined);
          }
        },
      ),
    );
}

/// The user's templates to pick a session from, the program's folder first.
/// Another program's session is greyed, with whose it is: a template is one
/// program's session at most.
class _SessionPicker extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final programs = Programs.of(context);
    final candidates = Templates.watch(context).candidatesFor(program);
    final muted = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    Program? owner(Template template) => switch (template.programId) {
      final String id => programs.lookup(id),
      null => null,
    };

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: .min,
        spacing: 2,
        children: [
          for (final template in candidates)
            switch (owner(template)) {
              final Program other => ListTile(
                key: AppKeys.programSessionCandidate(template.id),
                shape: _shape,
                minTileHeight: 44,
                contentPadding: const .symmetric(horizontal: 12),
                enabled: false,
                title: Text(_sessionName(copy, template), maxLines: 1, overflow: .ellipsis),
                subtitle: Text(copy.programAddSessionTaken(other.name), maxLines: 1, overflow: .ellipsis),
              ),
              null => ListTile(
                key: AppKeys.programSessionCandidate(template.id),
                shape: _shape,
                minTileHeight: 44,
                contentPadding: const .symmetric(horizontal: 12),
                title: Text(_sessionName(copy, template), maxLines: 1, overflow: .ellipsis),
                subtitle: switch (template.map((exercise) => exercise.exercise.name).join(', ')) {
                  '' => null,
                  final names => Text(names, maxLines: 1, overflow: .ellipsis, style: muted),
                },
                onTap: () => Navigator.of(context, rootNavigator: true).pop(template),
              ),
            },
        ],
      ),
    );
  }
}
