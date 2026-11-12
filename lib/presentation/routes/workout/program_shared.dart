part of 'workout.dart';

/// What the user calls the coach who sent [program]: their name, or the word
/// for them when the copy carries none.
String _coachOf(L copy, Program program) {
  return switch (program.coachName?.trim()) {
    final String name when name.isNotEmpty => name,
    _ => copy.yourCoach,
  };
}

/// What the coach changed in [program] since the user last looked: the
/// latest, how many more, and the way to say it was seen. Null once it was,
/// with Your coach off, or for a program nobody else edits, so a column
/// leaves no gap for it. Watches what it reads.
///
/// Never-looked counts the last week: what came before it is old news.
Widget? _coachChanges(BuildContext context, Program program) {
  final preferences = Preferences.watch(context);
  final id = program.id;
  if (id == null || program.coachId == null || !preferences.isOn(.yourCoach)) return null;
  final seen = preferences.programSeen(id) ?? DateTime.now().subtract(const Duration(days: 7));
  final changes = Programs.watch(context).coachChanges(id, after: seen);
  if (changes.isEmpty) return null;

  final copy = L.of(context);
  final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
  final latest = describeProgramChange(copy, changes.first, who: _coachOf(copy, program));
  return Row(
    key: AppKeys.programCoachChanges(id),
    children: [
      Icon(Icons.edit_note_rounded, size: 20, color: colorScheme.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          switch (changes.length) {
            1 => latest,
            final count => copy.programCoachChangesMore(latest, count - 1),
          },
          style: textTheme.bodyMedium,
        ),
      ),
      IconButton(
        key: AppKeys.programCoachChangesSeen(id),
        tooltip: copy.programCoachChangesSeen,
        icon: const Icon(Icons.close_rounded, size: 20),
        onPressed: () => preferences.setProgramSeen(id, DateTime.now()),
      ),
    ],
  );
}

/// A save of the user's to a coach's copy that the coach beat, with the
/// choice between the two. Nothing when there is none.
class _CoachConflict extends StatelessWidget {
  final Program program;

  const new({required this.program});

  @override
  Widget build(BuildContext context) {
    final programs = Programs.watch(context);
    final conflict = switch (program.id) {
      final String id => programs.conflict(id),
      null => null,
    };
    if (conflict == null) return const SizedBox.shrink();
    return ProgramConflictCard(
      conflict: conflict,
      margin: const .only(bottom: 12),
      name: _coachOf(L.of(context), program),
      onKeepTheirs: () => programs.dropMine(conflict.programId),
      onKeepMine: () => programs.keepMine(conflict.programId),
    );
  }
}

/// Reads [program] again, with its sessions, when the user pulls: what the
/// coach changed may not have come with a push.
Future<void> _pullShared(BuildContext context, Program program) async {
  final templates = Templates.of(context);
  if (program.id case final String id) {
    if (await Programs.of(context).pull(id) case final Program read) await templates.pull(read.sessions);
  }
}
