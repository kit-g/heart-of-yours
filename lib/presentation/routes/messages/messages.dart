/// Coaching messages (#556): one conversation per connection, sealed on the
/// device before it goes anywhere. A student reads theirs over the app; a
/// coach reads theirs in Coaching, beside the inbox on a wide window.
library;

import 'package:heart/core/utils/visual.dart';
import 'package:heart/presentation/widgets/keys.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The conversation of [connectionId] as a page of its own.
class ThreadPage extends StatelessWidget {
  final String connectionId;

  /// Who it is with, when the caller knows better than the server.
  final String? name;

  const new({super.key, required this.connectionId, this.name});

  @override
  Widget build(BuildContext context) {
    final thread = Messages.watch(context).threadOf(connectionId);
    return Scaffold(
      appBar: AppBar(title: Text(threadName(context, thread, fallback: name))),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: .topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: threadWidth),
            child: ThreadView(key: ValueKey(connectionId), connectionId: connectionId),
          ),
        ),
      ),
    );
  }
}

/// How wide a conversation grows: past this, bubbles drift too far apart to
/// read as a back and forth.
const threadWidth = 720.0;

/// Who a conversation is with: the name the server holds for them, else the
/// one [fallback] gives, else the role they play for this person.
String threadName(BuildContext context, Thread? thread, {String? fallback}) {
  final l = L.of(context);
  final coaching = Coaching.of(context);
  final connectionId = thread?.connectionId;
  final student = coaching.coaches.any((each) => each.connectionId == connectionId);
  return switch ((thread?.otherName?.trim(), fallback?.trim())) {
    (final String name, _) when name.isNotEmpty => name,
    (_, final String name) when name.isNotEmpty => name,
    _ when student => switch (connectionId) {
      final String id => Preferences.of(context).coachName(id) ?? l.yourCoach,
      null => l.yourCoach,
    },
    _ => l.coachingClientUnnamed,
  };
}

/// Where opening a conversation stands.
enum _Opening { opening, open, failed }

/// The conversation of [connectionId]: its messages, oldest at the top, and
/// the box to write in. Opens the thread on the server the first time.
class ThreadView extends StatefulWidget {
  final String connectionId;

  const new({super.key, required this.connectionId});

  @override
  State<ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<ThreadView> {
  final _opening = ValueNotifier(_Opening.opening);
  final _text = TextEditingController();
  late final Messages _messages;
  String? _threadId;

  @override
  void initState() {
    super.initState();
    _messages = Messages.of(context);
    _text.addListener(_keepDraft);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    if (_threadId case final String id) _messages.close(id);
    _text
      ..removeListener(_keepDraft)
      ..dispose();
    _opening.dispose();
    super.dispose();
  }

  void _keepDraft() {
    if (_threadId case final String id) _messages.keepDraft(id, _text.text);
  }

  Future<void> _open() async {
    if (!mounted) return;
    _opening.value = .opening;
    try {
      final thread = await _messages.threadFor(widget.connectionId);
      if (!mounted) return;
      _threadId = thread.id;
      // what was being written here before, kept across a fold
      _text.text = _messages.draft(thread.id);
      _opening.value = .open;
      await _messages.open(thread.id);
    } catch (_) {
      if (mounted) _opening.value = .failed;
    }
  }

  Future<void> _send() async {
    final threadId = _threadId;
    final text = _text.text.trim();
    if (threadId == null || text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final failed = L.of(context).messagesSendFailed;
    _text.clear();
    try {
      await _messages.send(threadId, text);
    } catch (_) {
      // nothing was kept: the words go back where they were written
      if (_text.text.isEmpty) _text.text = text;
      messenger.snack(failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ValueListenableBuilder(
      valueListenable: _opening,
      builder: (context, opening, _) {
        return switch ((opening, _threadId)) {
          (.open, final String threadId) => _Conversation(
            threadId: threadId,
            text: _text,
            onSend: _send,
          ),
          (.failed, _) => _Note(
            icon: Icons.cloud_off_rounded,
            title: l.messagesFailed,
            action: OutlinedButton(onPressed: _open, child: Text(l.retry)),
          ),
          _ => const Center(child: CircularProgressIndicator.adaptive()),
        };
      },
    );
  }
}

class _Conversation extends StatelessWidget {
  final String threadId;
  final TextEditingController text;
  final VoidCallback onSend;

  const new({required this.threadId, required this.text, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messages = Messages.watch(context);
    final thread = messages.thread(threadId);
    // newest at the bottom, where the eye and the box are
    final shown = thread.messages.reversed.toList();
    return Column(
      children: [
        Expanded(
          child: switch ((shown, thread.status)) {
            ([], .idle || .loading) => const Center(child: CircularProgressIndicator.adaptive()),
            ([], .failed) => _Note(
              icon: Icons.cloud_off_rounded,
              title: l.messagesFailed,
              action: OutlinedButton(onPressed: () => messages.open(threadId), child: Text(l.retry)),
            ),
            ([], _) => _Note(icon: Icons.lock_outline_rounded, title: l.messagesEmpty, body: l.messagesEmptyBody),
            _ => RefreshIndicator.adaptive(
              onRefresh: () => messages.pull(threadId),
              child: ListView.builder(
                key: AppKeys.thread,
                reverse: true,
                padding: const .symmetric(horizontal: 12, vertical: 8),
                itemCount: shown.length + 1,
                itemBuilder: (context, index) => switch (index < shown.length) {
                  true => _Bubble(message: shown[index]),
                  false => switch (thread.hasOlder) {
                    true => Center(
                      child: TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                        onPressed: () => messages.older(threadId),
                        child: Text(l.messagesOlder),
                      ),
                    ),
                    false => const SizedBox(height: 8),
                  },
                },
              ),
            ),
          },
        ),
        switch (thread.closed) {
          true => _Closed(),
          false => _Composer(text: text, onSend: onSend),
        },
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;

  const new({required this.message});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final mine = message.mine;
    final (background, foreground) = switch (mine) {
      true => (colorScheme.primary, colorScheme.onPrimary),
      false => (colorScheme.surfaceContainerHigh, colorScheme.onSurface),
    };
    final words = switch (message.opened) {
      Opened(:final text) => Text(text, style: textTheme.bodyLarge?.copyWith(color: foreground)),
      Locked() => _Unopened(icon: Icons.key_rounded, text: l.messagesLocked, color: foreground),
      Refused() => _Unopened(icon: Icons.block_rounded, text: l.messagesRefused, color: foreground),
    };
    final time = DateFormat.jm(Localizations.localeOf(context).toString()).format(message.at.toLocal());
    final delivery = switch ((mine, message.delivery)) {
      (true, .waiting) => Tooltip(
        message: l.messagesWaiting,
        child: Icon(
          Icons.schedule_rounded,
          size: 14,
          color: colorScheme.onSurfaceVariant,
          semanticLabel: l.messagesWaiting,
        ),
      ),
      (true, .closed) => Text(l.messagesNotSent, style: textTheme.labelSmall?.copyWith(color: colorScheme.error)),
      _ => null,
    };
    return Padding(
      key: AppKeys.message(message.id),
      padding: const .symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: switch (mine) {
          true => .end,
          false => .start,
        },
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: DecoratedBox(
              decoration: BoxDecoration(color: background, borderRadius: .circular(16)),
              child: Padding(padding: const .symmetric(horizontal: 14, vertical: 10), child: words),
            ),
          ),
          Padding(
            padding: const .only(top: 2, left: 4, right: 4),
            child: Row(
              mainAxisSize: .min,
              spacing: 4,
              children: [
                Text(time, style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ?delivery,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A message that didn't open, and why.
class _Unopened extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const new({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontStyle: .italic);
    return Row(
      mainAxisSize: .min,
      spacing: 6,
      children: [
        Icon(icon, size: 16, color: color),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController text;
  final VoidCallback onSend;

  const new({required this.text, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const .fromLTRB(12, 4, 8, 12),
      child: Row(
        crossAxisAlignment: .end,
        spacing: 4,
        children: [
          Expanded(
            child: TextField(
              key: AppKeys.messageBox,
              controller: text,
              minLines: 1,
              maxLines: 5,
              textCapitalization: .sentences,
              decoration: InputDecoration(hintText: l.messagesHint),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: text,
            builder: (context, value, _) => IconButton(
              key: AppKeys.messageSend,
              tooltip: l.messagesSend,
              icon: const Icon(Icons.send_rounded),
              onPressed: switch (value.text.trim().isEmpty) {
                true => null,
                false => onSend,
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      padding: const .all(16),
      child: Text(
        L.of(context).messagesClosed,
        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        textAlign: .center,
      ),
    );
  }
}

/// What a conversation says in place of messages.
class _Note extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  const new({required this.icon, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const .all(32),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: textTheme.titleMedium, textAlign: .center),
            if (body case final String body) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: .center,
              ),
            ],
            if (action case final Widget action) ...[const SizedBox(height: 24), action],
          ],
        ),
      ),
    );
  }
}
