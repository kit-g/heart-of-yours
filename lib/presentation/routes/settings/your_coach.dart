part of 'settings.dart';

/// Under Your coach's switch (#553): each coach, what they see beyond the
/// workouts logged since accepting, and leaving them. Shown whatever the switch
/// says, so a student can leave a coach without turning coaching back on; the
/// switch itself is the pause.
class _YourCoaches extends StatefulWidget {
  const new();

  @override
  State<_YourCoaches> createState() => _YourCoachesState();
}

class _YourCoachesState extends State<_YourCoaches> {
  @override
  void initState() {
    super.initState();
    // read here too: with the switch off nothing else reads them, and leaving
    // a coach mustn't need coaching turned back on
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Coaching.of(context).status == .idle) Coaching.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final coaches = Coaching.watch(context).coaches.toList();
    return Column(
      crossAxisAlignment: .stretch,
      children: [for (final coach in coaches) _CoachCard(coach: coach)],
    );
  }
}

class _CoachCard extends StatelessWidget {
  final Connection coach;

  const new({required this.coach});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    // their name as their profile says it now (heart-api#409), else as their
    // invitation showed it on this device
    final name = switch ((coach.name?.trim(), coach.connectionId)) {
      (final String name, _) when name.isNotEmpty => name,
      (_, final String id) => Preferences.watch(context).coachName(id),
      _ => null,
    };
    final paused = coach.status == .paused;
    final shares = {
      for (final share in coach.shares)
        if (ConnectionShare.values.where((each) => each.name == share).firstOrNull case final ConnectionShare known)
          known,
    };

    Widget share(ConnectionShare which, String title) => SwitchListTile(
      contentPadding: .zero,
      title: Text(title),
      value: shares.contains(which),
      onChanged: (on) => _try(
        context,
        () => Coaching.of(context).setShares(coach, switch (on) {
          true => {...shares, which},
          false => {...shares}..remove(which),
        }),
      ),
    );

    return Padding(
      key: AppKeys.yourCoach(coach.connectionId ?? coach.targetId),
      padding: const .only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text(name ?? l.yourCoach, style: textTheme.titleMedium),
          if (paused)
            Text(l.yourCoachPaused, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          share(.history, l.invitationShareHistory),
          share(.goals, l.invitationShareGoals),
          // their one conversation (#556): only while Your coach runs, since
          // off sends nothing anywhere
          if ((coach.connectionId, Preferences.watch(context).isOn(.yourCoach)) case (final String id, true))
            Align(
              alignment: .centerLeft,
              child: TextButton.icon(
                key: AppKeys.yourCoachMessage(id),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => HeartRouter.of(context).openThread(id),
                icon: const Icon(Icons.forum_outlined),
                label: Text(l.messagesWith(name ?? l.yourCoach)),
              ),
            ),
          Align(
            alignment: .centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: colorScheme.error),
              onPressed: () => _leave(context, name ?? l.yourCoach),
              child: Text(l.yourCoachLeave),
            ),
          ),
        ],
      ),
    );
  }

  /// Leaving is immediate and can't be taken back, so it is asked once.
  Future<void> _leave(BuildContext context, String name) async {
    final l = L.of(context);
    final sure = await showBrandedDialog<bool>(
      context,
      title: Text(l.yourCoachLeaveTitle(name)),
      content: Text(l.yourCoachLeaveBody),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false),
          child: Text(l.cancel),
        ),
        TextButton(
          key: AppKeys.yourCoachLeaveConfirm,
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
          child: Text(l.yourCoachLeave),
        ),
      ],
    );
    if (sure != true || !context.mounted) return;
    await _try(context, () => Coaching.of(context).end(coach));
  }
}

/// Who the person has blocked, with the way to lift each: shown whatever the
/// switch says, since a block made from an invitation outlives a no to it.
class _Blocked extends StatefulWidget {
  const new();

  @override
  State<_Blocked> createState() => _BlockedState();
}

class _BlockedState extends State<_Blocked> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Coaching.of(context).loadBlocks().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final blocks = Coaching.watch(context).blocks;
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const .symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .only(top: 8, bottom: 4),
            child: Text(l.yourCoachBlocked, style: textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          for (final person in blocks)
            ListTile(
              contentPadding: .zero,
              leading: Avatar(remote: person.avatar, radius: 16),
              title: Text(person.name ?? ''),
              trailing: TextButton(
                key: AppKeys.yourCoachUnblock(person.id),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: () => _try(context, () => Coaching.of(context).lift(person)),
                child: Text(l.yourCoachUnblock),
              ),
            ),
        ],
      ),
    );
  }
}

/// A change the server refused or never heard: said once, and nothing here
/// changed, since the list follows the server's answer.
Future<void> _try(BuildContext context, Future<void> Function() change) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = L.of(context).invitationFailed;
  try {
    await change();
  } catch (_) {
    messenger.snack(failed);
  }
}
