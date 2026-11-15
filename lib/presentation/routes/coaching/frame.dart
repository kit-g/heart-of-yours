part of 'coaching.dart';

/// The Coaching space's tabs, through [TabFrame], with the way back to the
/// user's own training at the foot of the rail, and a line leading back to a
/// workout of theirs still going.
///
/// It also keeps [Preferences.inCoachingSpace] true for as long as it is on
/// screen, and false once it goes, whichever way the user left: the way back,
/// a Live Activity, a shortcut, a link. A process killed inside the space
/// never clears it, which is what reopens the app there.
class CoachingFrame extends StatefulWidget {
  final StatefulNavigationShell shell;

  /// Back to the user's own space.
  final VoidCallback onYourTraining;

  /// Back to the user's own space, with their running workout open.
  final VoidCallback onBackToWorkout;

  const new({
    super.key,
    required this.shell,
    required this.onYourTraining,
    required this.onBackToWorkout,
  });

  @override
  State<CoachingFrame> createState() => _CoachingFrameState();
}

class _CoachingFrameState extends State<CoachingFrame> {
  late final Preferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = Preferences.of(context)..setInCoachingSpace(inside: true);
  }

  @override
  void dispose() {
    _preferences.setInCoachingSpace(inside: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CoachingFrame(:shell, :onYourTraining, :onBackToWorkout) = widget;
    // switched off, or an account that may no longer coach, from inside the
    // space: it goes, as if it had never been built
    if (!coachingSpaceOn(context, listen: true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onYourTraining());
    }
    final l = L.of(context);
    return TabFrame(
      shell: shell,
      destinations: [
        (
          label: l.coachingClients,
          icon: (_) => const Icon(Icons.groups_rounded, key: AppKeys.coachingClientsStack),
        ),
        (
          label: l.coachingMessages,
          icon: (_) => const _MessagesIcon(),
        ),
        (
          label: l.coachingPrograms,
          icon: (_) => const Icon(Icons.event_repeat_rounded, key: AppKeys.coachingProgramsStack),
        ),
        (
          label: l.coachingMe,
          icon: (_) => const Icon(Icons.badge_outlined, key: AppKeys.coachingMeStack),
        ),
      ],
      // every tab is one page for now: tapping it again has nowhere to go back to
      onReselect: (_, _) {},
      railFooter: Padding(
        padding: const .only(bottom: 16),
        child: _YourTrainingButton(onPressed: onYourTraining, rail: true),
      ),
      banner: Selector<Workouts, bool>(
        selector: (_, workouts) => workouts.hasActiveWorkout,
        builder: (_, running, _) => switch (running) {
          true => _WorkoutRunning(onBack: onBackToWorkout),
          false => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The Messages tab's icon, with how many of the clients' messages wait
/// unread. Rebuilt for the count alone, not every word from [Messages].
class _MessagesIcon extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // as one string: a list or a set built afresh is never equal to the last
    final clients = context.select<Coaching, String>(
      (coaching) => coaching.clients.map((each) => each.connectionId).nonNulls.join(' '),
    );
    final unread = context.select<Messages, int>((messages) => messages.unreadIn(clients.split(' ')));
    return UnreadBadge(
      count: unread,
      child: const Icon(Icons.forum_outlined, key: AppKeys.coachingMessagesStack),
    );
  }
}

/// The way out of the space, in words: an icon alone could be mistaken for
/// starting a workout, and this is the only way back. Beside its icon in an
/// app bar, under it at the foot of the rail, as the rail's own tabs are.
class _YourTrainingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool rail;

  const new({required this.onPressed, this.rail = false});

  @override
  Widget build(BuildContext context) {
    final label = L.of(context).coachingYourTraining;
    const icon = Icon(Icons.fitness_center_rounded);
    return switch (rail) {
      false => TextButton.icon(
        key: AppKeys.coachingYourTraining,
        onPressed: onPressed,
        icon: icon,
        label: Text(label),
      ),
      true => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          key: AppKeys.coachingYourTraining,
          onTap: onPressed,
          borderRadius: const .all(.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
            child: Padding(
              padding: const .symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisSize: .min,
                spacing: 4,
                children: [
                  icon,
                  Text(label, style: Theme.of(context).textTheme.labelMedium, textAlign: .center),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}

/// One line while the user's own workout is still going: nothing about a
/// client is in their own space, so nothing about their workout is here
/// beyond this.
class _WorkoutRunning extends StatelessWidget {
  final VoidCallback onBack;

  const new({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Material(
      color: colorScheme.secondaryContainer,
      child: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.fitness_center_rounded, size: 18, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.coachingWorkoutRunning,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSecondaryContainer),
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ),
            TextButton(
              key: AppKeys.coachingBackToWorkout,
              onPressed: onBack,
              child: Text(l.coachingBackToWorkout),
            ),
          ],
        ),
      ),
    );
  }
}
