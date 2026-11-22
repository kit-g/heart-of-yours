part of 'coaching.dart';

/// A coach's notes on one client (#556): an injury, what they said about
/// work, what to try next. Only the coach reads them, on any of their
/// devices, and the client never learns they exist.
class ClientNotesPage extends StatefulWidget {
  final String connectionId;

  const new({super.key, required this.connectionId});

  @override
  State<ClientNotesPage> createState() => _ClientNotesPageState();
}

class _ClientNotesPageState extends State<ClientNotesPage> {
  @override
  void initState() {
    super.initState();
    // read each time it opens: another device of the coach's may have
    // written. One on its way, from the client's page, is the same read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CoachNotes.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final client = Roster.watch(context).client(widget.connectionId);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (client) {
          final ClientSummary client => l.coachingNotesOn(_clientName(l, client)),
          null => l.coachingNotes,
        }),
        actions: [
          _NewNoteButton(connectionId: widget.connectionId),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: _NotesList(connectionId: widget.connectionId),
        ),
      ),
    );
  }
}

/// Writes a new note on [connectionId]'s client.
class _NewNoteButton extends StatelessWidget {
  final String connectionId;

  const new({required this.connectionId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: AppKeys.coachingNoteNew,
      tooltip: L.of(context).coachingNoteNew,
      onPressed: () => _showNoteEditor(context, connectionId: connectionId),
      icon: const Icon(Icons.add_rounded),
    );
  }
}

/// The coach's notes on one client, newest first: a page's body on a phone,
/// a tab beside the client on a tablet (#693).
class _NotesList extends StatelessWidget {
  final String connectionId;

  const new({required this.connectionId});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final notes = CoachNotes.watch(context);
    final written = notes.on(connectionId);
    return RefreshIndicator.adaptive(
      onRefresh: notes.load,
      child: switch ((notes.status, written)) {
        (.idle || .loading, []) => const Center(child: CircularProgressIndicator.adaptive()),
        (.failed, []) => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.coachingNotesFailed,
          action: OutlinedButton(onPressed: notes.load, child: Text(l.retry)),
        ),
        (_, []) => _Empty(
          icon: Icons.sticky_note_2_outlined,
          title: l.coachingNotesEmpty,
          body: l.coachingNotesEmptyBody,
          action: FilledButton.icon(
            key: AppKeys.coachingNoteFirst,
            onPressed: () => _showNoteEditor(context, connectionId: connectionId),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(l.coachingNoteNew),
          ),
        ),
        _ => ListView(
          padding: const .fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const .only(bottom: 12),
              child: Row(
                spacing: 8,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                  Expanded(
                    child: Text(
                      l.coachingNotesPrivate,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            for (final note in written) _NoteCard(connectionId: connectionId, note: note),
          ],
        ),
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String connectionId;
  final ClientNote note;

  const new({required this.connectionId, required this.note});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final edited = l.coachingNoteEdited(
      DateFormat.MMMd(l.localeName).add_jm().format(note.updatedAt.toLocal()),
    );
    final quiet = textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    return Card(
      key: AppKeys.coachingNote(note.id),
      margin: const .only(bottom: 12),
      clipBehavior: .antiAlias,
      child: InkWell(
        // a note that won't open here can't be edited here either
        onTap: switch (note.opened) {
          ReadNote(:final text) => () => _showNoteEditor(context, connectionId: connectionId, id: note.id, text: text),
          LockedNote() || RefusedNote() => null,
        },
        child: Padding(
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            spacing: 8,
            children: [
              switch (note.opened) {
                ReadNote(:final text) => Text(text, style: textTheme.bodyLarge),
                LockedNote() => _Unopened(icon: Icons.lock_clock_outlined, text: l.coachingNoteLocked),
                RefusedNote() => _Unopened(icon: Icons.error_outline_rounded, text: l.coachingNoteRefused),
              },
              Row(
                spacing: 6,
                children: [
                  Expanded(child: Text(edited, style: quiet)),
                  if (note.pending) ...[
                    Icon(Icons.cloud_upload_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                    Text(l.coachingNoteWaiting, style: quiet),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What a note that didn't open shows in place of its words.
class _Unopened extends StatelessWidget {
  final IconData icon;
  final String text;

  const new({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Row(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, fontStyle: .italic),
          ),
        ),
      ],
    );
  }
}

/// Writes a note on [connectionId]'s client: a new one, or the note [id]
/// with its [text], which can be deleted from here too.
Future<void> _showNoteEditor(BuildContext context, {required String connectionId, String? id, String text = ''}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (_) => _NoteEditor(connectionId: connectionId, id: id, text: text, notes: CoachNotes.of(context)),
  );
}

/// The most a note takes: far more than a note on a client needs, and well
/// inside what the server stores once sealed, whatever the alphabet.
const _noteLength = 2000;

class _NoteEditor extends StatefulWidget {
  final String connectionId;
  final String? id;
  final String text;

  /// Passed in: the sheet is a route of its own.
  final CoachNotes notes;

  const new({required this.connectionId, required this.text, required this.notes, this.id});

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  late final _controller = TextEditingController(text: widget.text);

  /// Why the last save or deletion failed, said here: the sheet covers the
  /// page's snackbars.
  final _failed = ValueNotifier<String?>(null);

  /// A save on its way: a second tap would write a second note.
  final _saving = ValueNotifier(false);

  @override
  void dispose() {
    _controller.dispose();
    _failed.dispose();
    _saving.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving.value) return;
    final l = L.of(context);
    final route = ModalRoute.of(context);
    _failed.value = null;
    _saving.value = true;
    try {
      await widget.notes.save(widget.connectionId, text, id: widget.id);
    } on KeyFailure catch (failure) {
      if (!mounted) return;
      _saving.value = false;
      _failed.value = switch (failure.code) {
        'note_too_long' => l.coachingNoteTooLong,
        _ => l.coachingNoteFailed,
      };
      return;
    } catch (_) {
      if (!mounted) return;
      _saving.value = false;
      _failed.value = l.coachingNoteFailed;
      return;
    }
    // closed meanwhile by the person: popping now would close what is under it
    if (mounted) popIfCurrent(route);
  }

  Future<void> _delete() async {
    final id = widget.id;
    if (id == null) return;
    final l = L.of(context);
    final navigator = Navigator.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final sure = await showBrandedDialog<bool>(
      context,
      title: Text(l.coachingNoteDeleteTitle),
      content: Text(l.coachingNoteDeleteBody),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          key: AppKeys.coachingNoteDeleteConfirm,
          style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: colorScheme.error),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(l.delete),
        ),
      ],
    );
    if (!(sure ?? false) || !mounted) return;
    _failed.value = null;
    try {
      await widget.notes.delete(id);
    } catch (_) {
      if (mounted) _failed.value = l.coachingNoteDeleteFailed;
      return;
    }
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return SafeArea(
      child: Padding(
        // above the keyboard
        padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          key: AppKeys.coachingNoteEditor,
          padding: const .fromLTRB(16, 24, 16, 8),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            spacing: 12,
            children: [
              Text(
                switch (widget.id) {
                  null => l.coachingNoteNew,
                  _ => l.coachingNoteEdit,
                },
                style: textTheme.titleMedium,
              ),
              TextField(
                key: AppKeys.coachingNoteText,
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 12,
                maxLength: _noteLength,
                textCapitalization: .sentences,
                decoration: InputDecoration(
                  hintText: l.coachingNoteHint,
                  helperText: l.coachingNotesPrivate,
                  helperMaxLines: 2,
                ),
              ),
              ValueListenableBuilder(
                valueListenable: _failed,
                builder: (context, failed, _) => switch (failed) {
                  final String failed => Text(
                    failed,
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                  null => const SizedBox.shrink(),
                },
              ),
              Row(
                children: [
                  if (widget.id != null)
                    TextButton.icon(
                      key: AppKeys.coachingNoteDelete,
                      style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l.coachingNoteDelete),
                    ),
                  const Spacer(),
                  // saved once there is something new to keep, and once
                  ListenableBuilder(
                    listenable: Listenable.merge([_controller, _saving]),
                    builder: (context, _) => switch ((_controller.text.trim(), _saving.value)) {
                      (_, true) => const SizedBox.square(
                        dimension: 48,
                        child: Center(child: CircularProgressIndicator.adaptive()),
                      ),
                      ('', false) => const SizedBox(height: 48),
                      (final String text, false) when text == widget.text.trim() => const SizedBox(height: 48),
                      (_, false) => PrimaryButton.shrunk(
                        key: AppKeys.coachingNoteSave,
                        onPressed: _save,
                        child: Text(l.save),
                      ),
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
