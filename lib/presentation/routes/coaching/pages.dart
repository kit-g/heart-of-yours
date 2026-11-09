part of 'coaching.dart';

/// The people this account coaches. Empty until someone accepts an
/// invitation (#553); the roster itself is #559.
class ClientsPage extends StatelessWidget {
  final VoidCallback onYourTraining;

  const new({super.key, required this.onYourTraining});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _CoachingPage(
      title: l.coachingClients,
      onYourTraining: onYourTraining,
      child: _Empty(icon: Icons.groups_rounded, title: l.coachingNoClients, body: l.coachingNoClientsBody),
    );
  }
}

/// One conversation per client (#556).
class CoachMessagesPage extends StatelessWidget {
  final VoidCallback onYourTraining;

  const new({super.key, required this.onYourTraining});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _CoachingPage(
      title: l.coachingMessages,
      onYourTraining: onYourTraining,
      child: _Empty(icon: Icons.forum_outlined, title: l.coachingNoMessages, body: l.coachingNoMessagesBody),
    );
  }
}

/// The programs a coach writes for clients, apart from their own (#557).
class CoachProgramsPage extends StatelessWidget {
  final VoidCallback onYourTraining;

  const new({super.key, required this.onYourTraining});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return _CoachingPage(
      title: l.coachingPrograms,
      onYourTraining: onYourTraining,
      child: _Empty(icon: Icons.event_repeat_rounded, title: l.coachingNoPrograms, body: l.coachingNoProgramsBody),
    );
  }
}

/// The coach as their clients see them: the name and photo they use in Heart.
class CoachMePage extends StatelessWidget {
  final VoidCallback onYourTraining;

  const new({super.key, required this.onYourTraining});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final user = Auth.watch(context).user;
    final name = switch (user) {
      User(displayName: final String name) when name.trim().isNotEmpty => name.trim(),
      User(:final email) => email ?? '',
      null => '',
    };
    return _CoachingPage(
      title: l.coachingMe,
      onYourTraining: onYourTraining,
      child: ListView(
        padding: const .symmetric(horizontal: 16, vertical: 24),
        children: [
          Center(
            child: Avatar(remote: user?.remoteAvatar, local: user?.localAvatar, radius: 40),
          ),
          const SizedBox(height: 16),
          Text(name, style: textTheme.titleLarge, textAlign: .center),
          const SizedBox(height: 8),
          Text(
            l.coachingMeBody,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: .center,
          ),
        ],
      ),
    );
  }
}

/// A Coaching page's frame: its title, and on a compact window the way back
/// to the user's own training, which the rail holds on a wide one.
class _CoachingPage extends StatelessWidget {
  final String title;
  final VoidCallback onYourTraining;
  final Widget child;

  const new({required this.title, required this.onYourTraining, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (LayoutProvider.of(context) == .compact) _YourTrainingButton(onPressed: onYourTraining),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: child,
        ),
      ),
    );
  }
}

/// What a tab says before there is anything in it.
class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const new({required this.icon, required this.title, required this.body});

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
            const SizedBox(height: 8),
            Text(
              body,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: .center,
            ),
          ],
        ),
      ),
    );
  }
}
