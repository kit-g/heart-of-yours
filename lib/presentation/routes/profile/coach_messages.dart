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
    final coaches = coachesToWrite(Coaching.watch(context));
    if (coaches.isEmpty) return const SizedBox.shrink();
    final unread = context.select<Messages, int>(
      (messages) => messages.unreadIn(coaches.map((each) => each.connectionId)),
    );
    final tooltip = switch (coaches) {
      [final coach] => l.messagesWith(coachName(context, coach)),
      _ => l.coachingMessages,
    };
    return IconButton(
      key: AppKeys.profileMessages,
      tooltip: tooltip,
      onPressed: () => _open(context, coaches),
      icon: UnreadBadge(count: unread, child: const Icon(Icons.forum_outlined)),
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
          for (final coach in coaches) PopupMenuItem(value: coach.connectionId, child: Text(coachName(context, coach))),
        ],
      ),
    };
    if (picked != null) router.openThread(picked);
  }
}
