part of 'messages.dart';

/// What a conversation offers as a whole (#556): deleting it, reporting the
/// other person, and blocking them while a connection stands to block.
/// Absent until the thread is known.
class ThreadMenu extends StatelessWidget {
  final String connectionId;

  const new({super.key, required this.connectionId});

  @override
  Widget build(BuildContext context) {
    final thread = Messages.watch(context).threadOf(connectionId);
    if (thread == null) return const SizedBox.shrink();
    return IconButton(
      key: AppKeys.threadMenu,
      tooltip: L.of(context).messagesOptions,
      icon: Icon(switch (Theme.of(context).platform) {
        .iOS || .macOS => Icons.more_horiz_rounded,
        _ => Icons.more_vert_rounded,
      }),
      onPressed: () => _open(context, thread),
    );
  }

  Future<void> _open(BuildContext context, Thread thread) async {
    final l = L.of(context);
    final connection = _connectionOf(context, connectionId);
    final picked = await showMenu<_ThreadAction>(
      context: context,
      position: menuUnder(context),
      items: [
        PopupMenuItem(
          key: AppKeys.threadDelete,
          value: .delete,
          child: _Item(icon: Icons.delete_outline_rounded, label: l.messagesDelete),
        ),
        PopupMenuItem(
          key: AppKeys.threadReport,
          value: .report,
          child: _Item(icon: Icons.flag_outlined, label: l.messagesReport),
        ),
        if (_blockable(connection))
          PopupMenuItem(
            key: AppKeys.threadBlock,
            value: .block,
            child: _Item(icon: Icons.block_rounded, label: l.messagesBlock),
          ),
      ],
    );
    if (!context.mounted) return;
    final name = threadName(context, thread, connectionId: connectionId);
    switch (picked) {
      case .delete:
        await _delete(context, thread, name);
      case .report:
        await showReportSheet(context, thread, name: name);
      case .block:
        if (connection != null) await _block(context, connection, name);
      case null:
        break;
    }
  }

  /// Deleting takes every message from both people at once, so it is asked.
  static Future<void> _delete(BuildContext context, Thread thread, String name) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final messages = Messages.of(context);
    final sure = await _confirm(
      context,
      title: l.messagesDeleteTitle,
      body: l.messagesDeleteBody(name),
      confirm: l.delete,
      key: AppKeys.threadDeleteConfirm,
    );
    if (!sure) return;
    try {
      await messages.clear(thread.id);
    } catch (_) {
      messenger.snack(l.messagesDeleteFailed);
    }
  }

  static Future<void> _block(BuildContext context, Connection connection, String name) async {
    final l = L.of(context);
    final sure = await _confirm(
      context,
      title: l.messagesBlockTitle(name),
      body: l.messagesBlockBody,
      confirm: l.messagesBlock,
      key: AppKeys.threadBlockConfirm,
    );
    if (!sure || !context.mounted) return;
    await _blockNow(context, connection, name);
  }
}

/// What the conversation's menu offers.
enum _ThreadAction { delete, report, block }

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;

  const new({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 12,
      children: [
        Icon(icon),
        Flexible(child: Text(label)),
      ],
    );
  }
}

/// The connection a conversation belongs to, as this device last read it.
Connection? _connectionOf(BuildContext context, String? connectionId, {bool listen = false}) {
  if (connectionId == null) return null;
  final coaching = switch (listen) {
    true => Coaching.watch(context),
    false => Coaching.of(context),
  };
  return coaching.all.where((each) => each.connectionId == connectionId).firstOrNull;
}

/// A connection still standing, which a block would end.
bool _blockable(Connection? connection) {
  return switch (connection?.status) {
    ConnectionStatus.pending || ConnectionStatus.active || ConnectionStatus.paused => true,
    _ => false,
  };
}

/// A conversation that takes nothing more: its connection ended, or a block
/// stands between the two.
bool _ended(Connection? connection) {
  return switch (connection?.status) {
    ConnectionStatus.blocked || ConnectionStatus.severed || ConnectionStatus.declined => true,
    _ => false,
  };
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required Key key,
}) async {
  final l = L.of(context);
  final colorScheme = Theme.of(context).colorScheme;
  final sure = await showBrandedDialog<bool>(
    context,
    title: Text(title),
    content: Text(body),
    actions: [
      TextButton(
        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
        child: Text(l.cancel),
      ),
      TextButton(
        key: key,
        style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: colorScheme.error),
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        child: Text(confirm),
      ),
    ],
  );
  return sure ?? false;
}

Future<void> _blockNow(BuildContext context, Connection connection, String name) async {
  final l = L.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final coaching = Coaching.of(context);
  try {
    await coaching.block(connection);
    messenger.snack(l.messagesBlocked(name));
  } catch (_) {
    messenger.snack(l.messagesBlockFailed(name));
  }
}

/// Reports the other person of [thread] (#556): why, with their messages
/// this device opened unless left out, and a block in the same breath.
/// [message] reports that one message rather than the recent ones.
Future<void> showReportSheet(BuildContext context, Thread thread, {required String name, Message? message}) {
  final messages = Messages.of(context);
  final theirs = switch (message) {
    final Message one => [one],
    // the most a report takes is far more than a reviewer reads
    null => [
      for (final each in messages.thread(thread.id).messages)
        if (!each.mine && each.opened is Opened) each,
    ].reversed.take(_reportedAtMost).toList().reversed.toList(),
  };
  final connection = _connectionOf(context, thread.connectionId);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: dialogWidth),
    builder: (_) => _ReportSheet(
      thread: thread,
      name: name,
      theirs: theirs,
      one: message != null,
      connection: switch (_blockable(connection)) {
        true => connection,
        false => null,
      },
      messages: messages,
      coaching: Coaching.of(context),
      messenger: ScaffoldMessenger.of(context),
    ),
  );
}

const _reportedAtMost = 20;

class _ReportSheet extends StatefulWidget {
  final Thread thread;
  final String name;
  final List<Message> theirs;

  /// One message picked out, rather than their recent ones.
  final bool one;

  /// The connection a block would end, when one stands.
  final Connection? connection;

  /// Passed in: the sheet is a route of its own.
  final Messages messages;
  final Coaching coaching;
  final ScaffoldMessengerState messenger;

  const new({
    required this.thread,
    required this.name,
    required this.theirs,
    required this.one,
    required this.connection,
    required this.messages,
    required this.coaching,
    required this.messenger,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _reason = ValueNotifier<ReportReason?>(null);
  final _include = ValueNotifier(true);
  final _block = ValueNotifier(false);
  final _sending = ValueNotifier(false);

  @override
  void dispose() {
    _reason.dispose();
    _include.dispose();
    _block.dispose();
    _sending.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason.value;
    if (reason == null) return;
    final l = L.of(context);
    final navigator = Navigator.of(context);
    final _ReportSheet(:thread, :theirs, :connection, :messenger, :name) = widget;
    _sending.value = true;
    try {
      await widget.messages.report(
        thread,
        reason,
        messages: switch (_include.value) {
          true => theirs,
          false => const [],
        },
      );
    } catch (_) {
      if (mounted) _sending.value = false;
      messenger.snack(l.reportFailed);
      return;
    }
    navigator.pop();
    switch ((_block.value, connection)) {
      case (true, final Connection connection):
        try {
          await widget.coaching.block(connection);
          messenger.snack(l.reportSentBlocked(name));
        } catch (_) {
          messenger.snack(l.messagesBlockFailed(name));
        }
      case _:
        messenger.snack(l.reportSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final _ReportSheet(:name, :theirs, :one, :connection) = widget;
    return SafeArea(
      child: SingleChildScrollView(
        key: AppKeys.reportSheet,
        padding: const .fromLTRB(16, 24, 16, 8),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Text(l.reportTitle(name), style: textTheme.titleMedium),
            Text(l.reportWhy, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
            ValueListenableBuilder(
              valueListenable: _reason,
              builder: (context, picked, _) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in ReportReason.values)
                    ChoiceChip(
                      key: AppKeys.reportReason(reason.wire),
                      label: Text(_reasonLabel(l, reason)),
                      selected: picked == reason,
                      onSelected: (_) => _reason.value = reason,
                    ),
                ],
              ),
            ),
            if (theirs.isNotEmpty)
              ValueListenableBuilder(
                valueListenable: _include,
                builder: (context, include, _) => SwitchListTile(
                  key: AppKeys.reportInclude,
                  contentPadding: .zero,
                  title: Text(switch (one) {
                    true => l.reportIncludeThis,
                    false => l.reportIncludeRecent(theirs.length),
                  }),
                  subtitle: Text(l.reportIncludeBody),
                  value: include,
                  onChanged: (on) => _include.value = on,
                ),
              ),
            if (connection != null)
              ValueListenableBuilder(
                valueListenable: _block,
                builder: (context, block, _) => SwitchListTile(
                  key: AppKeys.reportBlock,
                  contentPadding: .zero,
                  title: Text(l.reportAlsoBlock(name)),
                  value: block,
                  onChanged: (on) => _block.value = on,
                ),
              ),
            // sent once a reason is picked: until then there is nothing to send
            ListenableBuilder(
              listenable: Listenable.merge([_reason, _sending]),
              builder: (context, _) => Align(
                alignment: .centerRight,
                child: switch ((_reason.value, _sending.value)) {
                  (null, _) => const SizedBox(height: 48),
                  (_, true) => const SizedBox.square(
                    dimension: 48,
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                  (_, false) => PrimaryButton.shrunk(
                    key: AppKeys.reportSend,
                    onPressed: _send,
                    child: Text(l.reportSend),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _reasonLabel(L l, ReportReason reason) {
    return switch (reason) {
      .harassment => l.reportHarassment,
      .spam => l.reportSpam,
      .inappropriate => l.reportInappropriate,
      .unsafeAdvice => l.reportUnsafeAdvice,
      .other => l.reportOther,
    };
  }
}
