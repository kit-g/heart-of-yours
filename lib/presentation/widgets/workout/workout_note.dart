part of 'workout_detail.dart';

/// The note on the whole workout (#235), under its title in the active
/// workout and in the history editor: tap to edit it, × to clear it. Absent
/// while there is no note; the workout's ⋯ menu adds one.
class WorkoutNote extends StatelessWidget {
  final String note;
  final Future<void> Function(String?) onChanged;

  const new({super.key, required this.note, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Align(
      alignment: .centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: readableWidth),
        child: Padding(
          padding: const .fromLTRB(8, 4, 8, 4),
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: .circular(8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: l.editWorkoutNote,
                    child: InkWell(
                      key: WorkoutDetailKeys.workoutNote,
                      onTap: () => editWorkoutNote(context, note, onChanged),
                      borderRadius: .circular(8),
                      // one line of text and its padding fall short of 48pt
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const .all(12),
                          child: Text(
                            note,
                            maxLines: 4,
                            overflow: .ellipsis,
                            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.removeWorkoutNote,
                  iconSize: 18,
                  onPressed: () => _saveWorkoutNote(context, null, onChanged),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the editor on the workout's note, [initial] when it has one, and
/// hands what was saved to [onChanged]: null for a note emptied out. Cancel
/// changes nothing.
Future<void> editWorkoutNote(BuildContext context, String? initial, Future<void> Function(String?) onChanged) async {
  final l = L.of(context);
  final note = await showBrandedDialog<String>(
    context,
    title: Text(l.workoutNote),
    content: _NoteEditor(initial: initial, limit: Workout.maxNoteLength, label: l.workoutNote),
  );
  if (note == null || !context.mounted) return;
  await _saveWorkoutNote(context, note.isEmpty ? null : note, onChanged);
}

Future<void> _saveWorkoutNote(BuildContext context, String? note, Future<void> Function(String?) onChanged) async {
  try {
    await onChanged(note);
  } catch (_) {
    if (context.mounted) _noteError(context);
  }
}
