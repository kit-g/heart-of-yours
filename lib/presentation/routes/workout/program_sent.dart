part of 'workout.dart';

/// A program a coach sent (#557). A copy that arrives while the user follows
/// something else waits for them to start it, since it replaces what they are
/// on; one that arrives while they follow nothing simply runs.

/// Who sent [program], as its page and its card say it. Named even with Your
/// coach off: a program the user didn't make, waiting on them, has to say
/// where it came from.
String? _sentBy(BuildContext context, Program program) {
  return switch (program.coachName?.trim()) {
    final String name when name.isNotEmpty => L.of(context).programFromCoach(name),
    _ => null,
  };
}

/// Starts [program], asking first when it would stop the user following
/// something: the programs it replaces are named, and kept with their
/// history. Its lifts start from the user's own sets, as a library program's
/// do.
Future<void> _startSent(BuildContext context, Program program) async {
  final copy = L.of(context);
  final ThemeData(:colorScheme) = Theme.of(context);
  final programs = Programs.of(context);
  final exercises = Exercises.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final replacing = programs.following.where((each) => each.id != program.id).toList();

  if (replacing.isNotEmpty) {
    final sure = await showBrandedDialog<bool>(
      context,
      title: Text(copy.programStartSentTitle(program.name), textAlign: .center),
      content: Text(
        switch (replacing) {
          [final only] => copy.programStartSentBody(only.name),
          _ => copy.programStartSentBodyMany(replacing.length),
        },
        textAlign: .center,
      ),
      actions: [
        Builder(
          builder: (context) {
            void answer({required bool sure}) => Navigator.of(context, rootNavigator: true).pop(sure);
            return Column(
              spacing: 8,
              children: [
                PrimaryButton.wide(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  onPressed: () => answer(sure: false),
                  child: Center(child: Text(copy.programNotYet)),
                ),
                PrimaryButton.wide(
                  key: AppKeys.programStartSentConfirm,
                  onPressed: () => answer(sure: true),
                  child: Center(child: Text(copy.programStartIt)),
                ),
              ],
            );
          },
        ),
      ],
    );
    if (sure != true) return;
  }

  final Program started;
  try {
    started = await programs.start(program, replacing: replacing);
  } catch (error, stacktrace) {
    reportToSentry(error, stacktrace: stacktrace);
    messenger.snack(copy.programStartSentFailed);
    return;
  }
  messenger.snack(copy.programStartedSent(started.name));
  await programs.seedBases(
    started,
    setsOf: (id) async => switch (exercises.lookup(id)) {
      final Exercise exercise => [for (final act in await exercises.getExerciseHistory(exercise, pageSize: 10)) ...act],
      null => const <ExerciseSet>[],
    },
  );
}

/// A coach's copy waiting to be started: on the Workout tab, with its name,
/// and on its own page, without.
class _WaitingCard extends StatelessWidget {
  final Program program;

  /// Opens the program's page; null on the page itself.
  final VoidCallback? onOpen;

  const new({required this.program, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final copy = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final muted = textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer);
    final lines = [?_sentBy(context, program), copy.programWaiting];
    return Card(
      key: AppKeys.programWaiting(program.id!),
      margin: const .only(bottom: 12),
      color: colorScheme.secondaryContainer,
      clipBehavior: .antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const .fromLTRB(16, 12, 12, 12),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    if (onOpen != null)
                      Text(
                        program.name,
                        style: textTheme.titleMedium?.copyWith(color: colorScheme.onSecondaryContainer),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                    Text(lines.join(' · '), style: muted),
                  ],
                ),
              ),
              PrimaryButton.shrunk(
                key: AppKeys.programStartSent(program.id!),
                onPressed: () => _startSent(context, program),
                child: Text(copy.programStartIt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
