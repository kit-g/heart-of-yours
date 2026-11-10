part of 'coaching.dart';

/// What every client did, newest first, as one stream (#559): workouts,
/// skipped sessions, and programs nearing their end. Older pages come as the
/// coach scrolls.
class _ActivityView extends StatefulWidget {
  const new();

  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Roster.of(context).loadFeed();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final roster = Roster.watch(context);
    // a kind this build has no words for is left out, not shown as nothing
    final items = [
      for (final item in roster.feed)
        if (FeedKind.of(item) case final FeedKind kind) (item, kind),
    ];
    return switch ((roster.feedStatus, items)) {
      (.idle || .loading, []) => const Center(child: CircularProgressIndicator.adaptive()),
      (.failed, []) => _Empty(
        icon: Icons.cloud_off_rounded,
        title: l.coachingActivityFailed,
        action: OutlinedButton(onPressed: roster.loadFeed, child: Text(l.retry)),
      ),
      (_, []) => _Empty(icon: Icons.timeline_rounded, title: l.coachingNoActivity, body: l.coachingNoActivityBody),
      // a column of sentences, not as wide as the roster's table
      _ => Align(
        alignment: .topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readableWidth),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 400) roster.moreFeed();
              return false;
            },
            child: RefreshIndicator.adaptive(
              onRefresh: roster.loadFeed,
              child: ListView(
                padding: const .only(bottom: 24),
                children: [
                  for (final (item, kind) in items) _FeedTile(item: item, kind: kind),
                  if (roster.feedHasMore)
                    const Padding(
                      padding: .all(16),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    };
  }
}

class _FeedTile extends StatelessWidget {
  final CoachFeedItem item;
  final FeedKind kind;

  const new({required this.item, required this.kind});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final name = switch (item.name?.trim()) {
      final String name when name.isNotEmpty => name,
      _ => l.coachingClientUnnamed,
    };
    final title = switch (item.title?.trim()) {
      final String title when title.isNotEmpty => title,
      _ => null,
    };
    final at = item.at.toLocal();
    return ListTile(
      leading: Avatar(remote: item.avatar, radius: 20),
      title: Text(switch ((kind, title)) {
        (.workout, final String title) => l.coachingFeedWorkout(name, title),
        (.workout, null) => l.coachingFeedWorkoutUntitled(name),
        (.skip, _) => l.coachingFeedSkip(name),
        (.ending, final String title) => l.coachingFeedEnding(name, title),
        (.ending, null) => l.coachingFeedEndingUntitled(name),
      }),
      subtitle: Text(DateFormat.MMMEd(l.localeName).add_jm().format(at)),
      trailing: Icon(switch (kind) {
        .workout => Icons.check_circle_outline_rounded,
        .skip => Icons.redo_rounded,
        .ending => Icons.flag_outlined,
      }),
    );
  }
}
