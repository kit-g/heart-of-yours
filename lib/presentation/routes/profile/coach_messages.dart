part of 'profile.dart';

/// A student's way to their coach's messages (#556), from Profile: with Your
/// coach on and a coach to write to, and how many wait unread. One coach opens
/// the conversation; several are picked from a menu.
class _CoachMessages extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    if (!Preferences.watch(context).isOn(.yourCoach)) return const SizedBox.shrink();
    final coaches = [
      for (final coach in Coaching.watch(context).coaches)
        if ((coach.connectionId, coach.status) case (String(), ConnectionStatus.active || ConnectionStatus.paused))
          coach,
    ];
    if (coaches.isEmpty) return const SizedBox.shrink();
    final unread = Messages.watch(context).unreadIn(coaches.map((each) => each.connectionId));
    final tooltip = switch (coaches) {
      [final coach] => l.messagesWith(_coachName(context, coach)),
      _ => l.coachingMessages,
    };
    return IconButton(
      key: AppKeys.profileMessages,
      tooltip: switch (unread) {
        0 => tooltip,
        _ => '$tooltip, ${l.messagesUnread(unread)}',
      },
      onPressed: () => _open(context, coaches),
      icon: switch (unread) {
        0 => const Icon(Icons.forum_outlined),
        _ => Badge.count(count: unread, child: const Icon(Icons.forum_outlined)),
      },
    );
  }

  Future<void> _open(BuildContext context, List<Connection> coaches) async {
    final router = HeartRouter.of(context);
    final picked = switch (coaches) {
      [final coach] => coach.connectionId,
      _ => await showMenu<String>(
        context: context,
        position: menuUnder(context),
        items: [
          for (final coach in coaches)
            PopupMenuItem(value: coach.connectionId, child: Text(_coachName(context, coach))),
        ],
      ),
    };
    if (picked != null) router.openThread(picked);
  }

  /// As their profile names them now, else as their invitation did here.
  static String _coachName(BuildContext context, Connection coach) {
    return switch ((coach.name?.trim(), coach.connectionId)) {
      (final String name, _) when name.isNotEmpty => name,
      (_, final String id) => Preferences.of(context).coachName(id) ?? L.of(context).yourCoach,
      _ => L.of(context).yourCoach,
    };
  }
}
