part of 'coaching.dart';

/// The coach as their clients see them, the name and photo they use in
/// Heart, and the account itself: Settings and logging out, without leaving
/// the space for them (#685).
class CoachMePage extends StatelessWidget {
  final VoidCallback onYourTraining;
  final VoidCallback onSettings;

  const new({super.key, required this.onYourTraining, required this.onSettings});

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
          const SizedBox(height: 24),
          ListTile(
            key: AppKeys.coachingSettings,
            leading: const Icon(Icons.settings_rounded),
            title: Text(l.settings),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onSettings,
          ),
          ListTile(
            key: AppKeys.coachingLogOut,
            leading: const Icon(Icons.logout_rounded),
            title: Text(l.logOut),
            // signed out, the space goes as if it had never been built, and
            // the frame takes the user back to their own
            onTap: () {
              AppTheme.of(context).onSignOut();
              clearState(context);
            },
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

  /// The page's own actions, before the way back.
  final List<Widget> actions;

  /// How wide the page grows: a column of prose by default.
  final double maxWidth;

  const new({
    required this.title,
    required this.onYourTraining,
    required this.child,
    this.actions = const [],
    this.maxWidth = readableWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...actions,
          if (LayoutProvider.of(context) == .compact) _YourTrainingButton(onPressed: onYourTraining),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
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
  final String? body;

  /// What to do about it, when there is something to do.
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
