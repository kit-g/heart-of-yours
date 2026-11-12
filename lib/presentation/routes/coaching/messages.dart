part of 'coaching.dart';

/// The Messages tab (#556): one conversation per client, last arrival first.
/// On a wide pane the open conversation sits beside the list; on a narrow
/// one it is a page of its own ([onOpen]).
class CoachMessagesPage extends StatefulWidget {
  final VoidCallback onYourTraining;
  final ValueChanged<String> onOpen;

  const new({super.key, required this.onYourTraining, required this.onOpen});

  @override
  State<CoachMessagesPage> createState() => _CoachMessagesPageState();
}

class _CoachMessagesPageState extends State<CoachMessagesPage> {
  /// The conversation open beside the list, by its connection.
  final _open = ValueNotifier<String?>(null);

  /// Wide enough for the list and a conversation side by side.
  static const _besideWidth = 600.0;
  static const _listWidth = 320.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Messages.of(context).load();
    });
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _CoachingPage(
      title: l.coachingMessages,
      onYourTraining: widget.onYourTraining,
      maxWidth: .infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final beside = constraints.maxWidth >= _besideWidth;
          return ValueListenableBuilder(
            valueListenable: _open,
            builder: (context, open, _) {
              final inbox = _Inbox(
                selected: switch (beside) {
                  true => open,
                  false => null,
                },
                onOpen: (id) => switch (beside) {
                  true => _open.value = id,
                  false => widget.onOpen(id),
                },
              );
              if (!beside) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: readableWidth),
                    child: inbox,
                  ),
                );
              }
              return Row(
                crossAxisAlignment: .stretch,
                children: [
                  SizedBox(width: _listWidth, child: inbox),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: switch (open) {
                      final String id => Align(
                        alignment: .topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: threadWidth),
                          child: ThreadView(key: ValueKey(id), connectionId: id),
                        ),
                      ),
                      null => _Empty(icon: Icons.forum_outlined, title: l.messagesPick),
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Inbox extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onOpen;

  const new({required this.selected, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final messages = Messages.watch(context);
    final threads = messages.threads.where((each) => each.connectionId != null).toList();
    if (threads.isEmpty) {
      return switch (messages.status) {
        .idle || .loading => const Center(child: CircularProgressIndicator.adaptive()),
        .failed => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.messagesFailed,
          action: OutlinedButton(onPressed: messages.load, child: Text(l.retry)),
        ),
        .loaded => _Empty(icon: Icons.forum_outlined, title: l.coachingNoMessages, body: l.coachingNoMessagesBody),
      };
    }
    return RefreshIndicator.adaptive(
      onRefresh: messages.load,
      child: ListView.builder(
        itemCount: threads.length,
        itemBuilder: (context, index) => _InboxRow(
          thread: threads[index],
          selected: threads[index].connectionId == selected,
          onOpen: onOpen,
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  final Thread thread;
  final bool selected;
  final ValueChanged<String> onOpen;

  const new({required this.thread, required this.selected, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final last = switch (thread.lastAt?.toLocal()) {
      final DateTime at when DateUtils.isSameDay(at, clock.now()) => DateFormat.jm(locale).format(at),
      final DateTime at => DateFormat.MMMd(locale).format(at),
      null => null,
    };
    return ListTile(
      key: AppKeys.inboxThread(thread.id),
      selected: selected,
      leading: Avatar(remote: thread.otherAvatar, radius: 20),
      title: Text(
        threadName(context, thread),
        maxLines: 1,
        overflow: .ellipsis,
        style: switch (thread.unread > 0) {
          true => textTheme.bodyLarge?.copyWith(fontWeight: .w600),
          false => null,
        },
      ),
      subtitle: switch (last) {
        final String last => Text(last),
        null => null,
      },
      trailing: switch (thread.unread) {
        0 => null,
        final int count => Badge(
          label: Text('$count', semanticsLabel: l.messagesUnread(count)),
          backgroundColor: colorScheme.primary,
          textColor: colorScheme.onPrimary,
        ),
      },
      onTap: () => onOpen(thread.connectionId!),
    );
  }
}
