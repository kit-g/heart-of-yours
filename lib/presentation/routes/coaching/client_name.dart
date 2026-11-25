part of 'coaching.dart';

/// Asks the coach for their own name for [client] (#753), which only they
/// read: given, or changed.
///
/// No way to take one back yet: an invitation's name reads as one the coach
/// gave too, so taking it back would answer the same name.
Future<void> _rename(BuildContext context, ClientSummary client) {
  final ThemeData(:colorScheme) = Theme.of(context);
  return showBrandedDialog(
    context,
    title: Text(L.of(context).coachingClientRename, textAlign: .center),
    icon: Icon(Icons.badge_outlined, color: colorScheme.onPrimaryContainer),
    // the form owns its controller and the save: the dialog outlives the pop
    // by its exit animation, as the folder name dialog's does
    content: _ClientNameForm(client: client),
  );
}

class _ClientNameForm extends StatefulWidget {
  final ClientSummary client;

  const new({required this.client});

  @override
  State<_ClientNameForm> createState() => _ClientNameFormState();
}

class _ClientNameFormState extends State<_ClientNameForm> {
  /// Their name as the coach gave it, to change; empty for one they go by.
  late final _controller = TextEditingController(
    text: switch (widget.client) {
      ClientSummary(namedByYou: true, :final name?) => name,
      _ => '',
    },
  );

  /// What went wrong with the last save, cleared as the name changes.
  final _failed = ValueNotifier<String?>(null);

  final _saving = ValueNotifier(false);

  @override
  void dispose() {
    _controller.dispose();
    _failed.dispose();
    _saving.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  Future<void> _save(String name) async {
    if (_saving.value) return;
    _saving.value = true;
    final coaching = Coaching.of(context);
    final roster = Roster.of(context);
    try {
      roster.renamed(await coaching.name(widget.client.connectionId, name));
      // only the dialog itself: nothing closes it while it saves, but a pop
      // here must never take the page under it
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) Navigator.of(context, rootNavigator: true).pop();
    } catch (error, stacktrace) {
      reportToSentry(error, stacktrace: stacktrace);
      if (!mounted) return;
      _saving.value = false;
      _failed.value = L.of(context).unknownError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    final l = L.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_controller, _failed, _saving]),
      builder: (context, _) {
        final saving = _saving.value;
        // while a save is out, neither Cancel, the barrier nor Back closes it
        return PopScope(
          canPop: !saving,
          child: Column(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              Padding(
                padding: const .symmetric(vertical: 8),
                child: TextField(
                  key: AppKeys.coachingClientNameField,
                  controller: _controller,
                  autofocus: true,
                  enabled: !saving,
                  // the server counts a name's length in code points
                  inputFormatters: [_atMost(_maxName)],
                  textCapitalization: .words,
                  decoration: InputDecoration(
                    hintText: l.coachingClientNameHint,
                    helperText: l.coachingClientNameOnlyYou,
                    helperMaxLines: 2,
                    errorText: _failed.value,
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => _failed.value = null,
                  onSubmitted: (_) {
                    // the keyboard's done key bypasses the disabled button
                    if (_name.isNotEmpty) _save(_name);
                  },
                ),
              ),
              PrimaryButton.wide(
                backgroundColor: colorScheme.surfaceContainerHighest,
                onPressed: switch (saving) {
                  true => null,
                  false => () => Navigator.of(context, rootNavigator: true).pop(),
                },
                child: Center(child: Text(l.cancel)),
              ),
              PrimaryButton.wide(
                key: AppKeys.coachingClientNameSave,
                onPressed: switch (_name.isNotEmpty && !saving) {
                  true => () => _save(_name),
                  false => null,
                },
                child: Center(child: Text(l.save, style: textTheme.bodyMedium)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The longest name the server takes for a person, in code points.
const _maxName = 100;

/// Keeps what is typed to [max] code points, as the server counts them: an
/// edit past it is not taken.
TextInputFormatter _atMost(int max) {
  return TextInputFormatter.withFunction((old, value) {
    return switch (value.text.runes.length <= max) {
      true => value,
      false => old,
    };
  });
}
