import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// A save to a copy two people edit that didn't land (#558), on either side:
/// the other person, [name], changed the same thing first, with a choice
/// between the two; it never arrived, to send again or drop; or it was
/// refused, to drop.
class ProgramConflictCard extends StatelessWidget {
  final ProgramConflict conflict;

  /// What the other person is called on this side.
  final String name;
  final VoidCallback onKeepTheirs;
  final VoidCallback onKeepMine;
  final EdgeInsetsGeometry margin;

  const new({
    super.key,
    required this.conflict,
    this.margin = const .fromLTRB(16, 12, 16, 0),
    required this.name,
    required this.onKeepTheirs,
    required this.onKeepMine,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final words = switch (conflict) {
      ProgramConflict(refused: true) => l.coachingCopyRefused(name),
      ProgramConflict(unsent: true) => l.coachingCopyUnsent,
      ProgramConflict(:final Template session) => l.coachingCopyConflictSession(name, session.name ?? ''),
      _ => l.coachingCopyConflictFields(name),
    };
    return Card(
      key: AppKeys.coachingCopyConflict,
      margin: margin,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const .fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Text(words, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onErrorContainer)),
            Row(
              mainAxisAlignment: .end,
              children: [
                TextButton(
                  key: AppKeys.coachingCopyKeepTheirs,
                  style: TextButton.styleFrom(foregroundColor: colorScheme.onErrorContainer),
                  onPressed: onKeepTheirs,
                  child: Text(switch (conflict) {
                    ProgramConflict(unsent: true) || ProgramConflict(refused: true) => l.coachingCopyDiscard,
                    _ => l.coachingCopyKeepTheirs,
                  }),
                ),
                // a refusal has nothing to send again
                if (!conflict.refused)
                  TextButton(
                    key: AppKeys.coachingCopyKeepMine,
                    style: TextButton.styleFrom(foregroundColor: colorScheme.onErrorContainer),
                    onPressed: onKeepMine,
                    child: Text(switch (conflict.unsent) {
                      true => l.retry,
                      false => l.coachingCopyKeepMine,
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What [change] did to a copy, said with [who] as the one who did it.
String describeProgramChange(L l, ProgramChange change, {required String who}) {
  final session = switch ((change.after ?? change.before)?['name']) {
    final String name when name.trim().isNotEmpty => name.trim(),
    _ => '',
  };
  return switch (change) {
    ProgramChange(sessionId: null) => l.coachingCopyChangedProgram(who),
    ProgramChange(before: null) => l.coachingCopyAddedSession(who, session),
    ProgramChange(after: null) => l.coachingCopyRemovedSession(who, session),
    _ => l.coachingCopyChangedSession(who, session),
  };
}
