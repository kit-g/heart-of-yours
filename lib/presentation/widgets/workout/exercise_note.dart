part of 'workout_detail.dart';

// One entry limit for session notes and pins; existing longer notes remain readable.
const _noteLimit = 150;

class _ExerciseNote extends StatefulWidget {
  final WorkoutExercise exercise;
  final Future<void> Function(WorkoutExercise, String?)? onChanged;
  final VoidCallback onEdit;

  const new({required this.exercise, this.onChanged, required this.onEdit});

  @override
  State<_ExerciseNote> createState() => _ExerciseNoteState();
}

class _ExerciseNoteState extends State<_ExerciseNote> {
  final _busy = ValueNotifier(false);

  @override
  void dispose() {
    _busy.dispose();
    super.dispose();
  }

  Future<void> _pin() async {
    if (_busy.value) return;
    final exercises = Exercises.of(context);
    final exercise = widget.exercise;
    final pinned = exercises.noteFor(exercise.exercise.id) != null;
    var note = exercise.note;
    if (!pinned && note != null && note.length > _noteLimit) {
      note = await showBrandedDialog<String>(
        context,
        title: Text(L.of(context).exerciseNote),
        content: _NoteEditor(initial: note),
      );
      if (!mounted || note == null || note.isEmpty) return;
    }
    _busy.value = true;
    try {
      await exercises.setNote(exercise.exercise.id, pinned ? null : note);
    } catch (_) {
      if (mounted) _noteError(context);
    } finally {
      if (mounted) _busy.value = false;
    }
  }

  Future<bool> _clear() async {
    if (_busy.value) return false;
    _busy.value = true;
    try {
      await widget.onChanged?.call(widget.exercise, null);
    } catch (_) {
      if (mounted) _noteError(context);
    } finally {
      if (mounted) _busy.value = false;
    }
    // The owner's update removes the note; no independent dismissed state.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final exercise = widget.exercise;
    final exercises = Exercises.watch(context);
    final pinned = exercises.noteFor(exercise.exercise.id) != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: readableWidth),
      child: Dismissible(
        key: ValueKey('note-${exercise.id}'),
        direction: switch (widget.onChanged) {
          null => .none,
          _ => .endToStart,
        },
        confirmDismiss: (_) => _clear(),
        background: ColoredBox(
          color: scheme.errorContainer,
          child: Align(
            alignment: .centerRight,
            child: Padding(
              padding: const .all(12),
              child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ),
          ),
        ),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: .circular(8),
          child: Row(
            crossAxisAlignment: .center,
            children: [
              Expanded(
                child: Semantics(
                  button: widget.onChanged != null,
                  label: l.editExerciseNote,
                  child: InkWell(
                    onTap: switch (widget.onChanged) {
                      null => null,
                      _ => widget.onEdit,
                    },
                    borderRadius: .circular(8),
                    child: Padding(
                      padding: const .all(12),
                      child: Text(
                        exercise.note ?? '',
                        maxLines: 2,
                        overflow: .ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.onChanged != null) ...[
                if (exercises.canPinNote)
                  ValueListenableBuilder<bool>(
                    valueListenable: _busy,
                    builder: (_, busy, _) => IconButton(
                      tooltip: pinned ? l.unpinExerciseNote : l.pinExerciseNote,
                      iconSize: 18,
                      icon: switch (busy) {
                        true => const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        false => switch (pinned) {
                          true => Transform.rotate(
                            angle: -pi / 4,
                            child: const Icon(Icons.push_pin),
                          ),
                          false => const Icon(Icons.push_pin_outlined),
                        },
                      },
                      onPressed: _pin,
                    ),
                  ),
                IconButton(
                  tooltip: l.removeExerciseNote,
                  iconSize: 18,
                  onPressed: _clear,
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditor extends StatefulWidget {
  final String? initial;

  const new({this.initial});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Form(
      key: _form,
      child: Column(
        mainAxisSize: .min,
        spacing: 16,
        children: [
          Semantics(
            label: l.exerciseNote,
            textField: true,
            child: TextFormField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              maxLength: _noteLimit,
              maxLengthEnforcement: .enforced,
              textCapitalization: .sentences,
              // Input enforcement does not shorten an existing synced note.
              validator: (text) => switch ((text ?? '').trim().length > _noteLimit) {
                true => l.exerciseNoteLimit(_noteLimit),
                false => null,
              },
            ),
          ),
          DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodyMedium,
            child: OverflowBar(
              alignment: .end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.cancel),
                ),
                PrimaryButton.shrunk(
                  onPressed: () {
                    if (_form.currentState!.validate()) Navigator.of(context).pop(_controller.text.trim());
                  },
                  child: Text(l.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _noteError(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(L.of(context).exerciseNoteSaveFailed),
    ),
  );
}
