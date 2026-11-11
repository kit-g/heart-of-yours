part of 'settings.dart';

/// What reaches the person by push (#554): every topic the server lists, how
/// often each comes, and the same per person they train with.
///
/// Drawn from the server's answer, so a kind of push this build has never
/// heard of still shows and changes: its name and description are the
/// server's words. Only the deliveries (instant, daily, off) and the group
/// headings are this build's copy; a delivery it has no word for is not
/// offered, and a topic it could not offer any choice for is left out rather
/// than shown dead.
///
/// The way here is the Settings row that otherwise opens the system's
/// notification settings, and only while the push client runs (a coaching
/// switch on, with an account). Off, that row is what it always was.
class PushSettingsPage extends StatefulWidget {
  const new({super.key});

  @override
  State<PushSettingsPage> createState() => _PushSettingsPageState();
}

class _PushSettingsPageState extends State<PushSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Pushes.of(context).load();
      // who the per-person answers are about: a coach's clients, a student's
      // coaches
      if (Coaching.of(context).status == .idle) Coaching.of(context).load();
      if (coachingSpaceOn(context)) Roster.of(context).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final L(:pushSettings, :pushSettingsLoadFailed, :retry) = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final pushes = Pushes.watch(context);
    final topics = pushes.topics.where(_offerable).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(pushSettings),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // a name over a choice of two or three: across a tablet pane the
          // choice ends up nowhere near the name it answers
          final width = math.min(constraints.maxWidth, readableWidth);
          return Align(
            alignment: .topCenter,
            child: SizedBox(
              width: width,
              child: ListView(
                padding: const .symmetric(vertical: 8),
                children: [
                  const _SystemNotificationsRow(),
                  const SizedBox(height: 8),
                  ...switch ((pushes.status, topics)) {
                    (.idle || .loading, []) => [
                      const Padding(
                        padding: .all(24),
                        child: Center(child: CircularProgressIndicator.adaptive()),
                      ),
                    ],
                    (.failed, []) => [
                      Padding(
                        padding: const .symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          children: [
                            Text(
                              pushSettingsLoadFailed,
                              textAlign: .center,
                              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                              onPressed: Pushes.of(context).load,
                              child: Text(retry),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _ => [
                      for (final (index, group) in _grouped(topics).indexed) ...[
                        if (index > 0) const SizedBox(height: 16),
                        if (_groupTitle(L.of(context), group.$1) case final String title)
                          _Section(title: title, children: const []),
                        ...group.$2.map((topic) => _TopicTile(topic: topic)),
                      ],
                      const _People(),
                    ],
                  },
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Topics in the server's order, gathered under their groups in the order
  /// each group first appears.
  static List<(String, List<PushSetting>)> _grouped(List<PushSetting> topics) {
    final groups = <String>{for (final topic in topics) topic.group};
    return [
      for (final group in groups) (group, topics.where((topic) => topic.group == group).toList()),
    ];
  }
}

/// A heading for a group this build has words for; none for one it hasn't,
/// whose topics still show, under the one before.
String? _groupTitle(L l, String group) {
  return switch (group) {
    'comments' => l.pushKindComments,
    'reactions' => l.pushKindReactions,
    'coaching' => l.pushKindCoaching,
    _ => null,
  };
}

/// A delivery as this build says it, or null for one it has no word for.
String? _deliveryLabel(L l, String delivery) {
  return switch (PushDelivery.of(delivery)) {
    .instant => l.pushDeliveryInstant,
    .daily => l.pushDeliveryDaily,
    .off => l.pushDeliveryOff,
    null => null,
  };
}

/// Whether a topic can be offered: two or more deliveries this build can name,
/// the current one among them.
bool _offerable(PushSetting topic) {
  final known = topic.options.where((each) => PushDelivery.of(each) != null);
  return known.length > 1 && known.contains(topic.delivery);
}

class _TopicTile extends StatelessWidget {
  final PushSetting topic;

  const new({required this.topic});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      key: ValueKey('pushTopic-${topic.topic}'),
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(topic.name, style: textTheme.bodyLarge),
          Text(topic.description, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Align(
            alignment: .centerLeft,
            child: SettingSwitcher<String>(
              value: topic.delivery,
              onValueChanged: (delivery) {
                if (delivery != null) _change(context, () => Pushes.of(context).set(topic.topic, delivery));
              },
              children: {
                for (final option in topic.options)
                  if (_deliveryLabel(l, option) case final String label) option: Text(label),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A change the server refused: put back by [Pushes], and said once.
Future<void> _change(BuildContext context, Future<void> Function() change) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = L.of(context).pushSettingFailed;
  try {
    await change();
  } catch (_) {
    messenger.snack(failed);
  }
}

/// The person's own answers for the people they train with: a coach's clients
/// and a student's coaches, each opening what reaches them from that one
/// person. Absent while there is nobody, or no topic that could be narrowed.
class const _People() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final preferences = Preferences.watch(context);
    final coaches = [
      for (final coach in Coaching.watch(context).coaches)
        if (coach.connectionId case final String id) (id: id, name: preferences.coachName(id) ?? l.yourCoach),
    ];
    final clients = switch (coachingSpaceOn(context, listen: true)) {
      true => [
        for (final client in Roster.watch(context).clients)
          (id: client.connectionId, name: client.name ?? l.coachingClientUnnamed),
      ],
      false => const <({String id, String name})>[],
    };
    final people = [...coaches, ...clients];
    final topics = Pushes.watch(context).topics.where((topic) => topic.group == 'coaching').where(_offerable).toList();
    if (people.isEmpty || topics.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const .only(top: 16),
      child: _Section(
        title: l.pushPeople,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: Text(l.pushPeopleBody, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          for (final person in people)
            ListTile(
              key: ValueKey('pushPerson-${person.id}'),
              title: Text(person.name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _open(context, person, topics),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, ({String id, String name}) person, List<PushSetting> topics) {
    showBrandedDialog<void>(
      context,
      title: Text(person.name),
      content: _PersonTopics(connectionId: person.id, topics: topics),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: Text(L.of(context).close),
        ),
      ],
    );
  }
}

/// Each coaching topic for one person: the topic's own answer by default, or
/// one of its deliveries for them alone.
class _PersonTopics extends StatelessWidget {
  final String connectionId;
  final List<PushSetting> topics;

  const new({required this.connectionId, required this.topics});

  /// The switcher's value for "as for everyone": a delivery is never empty.
  static const _follow = '';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme) = Theme.of(context);
    final pushes = Pushes.watch(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          for (final topic in topics) ...[
            const SizedBox(height: 8),
            Text(topic.name, style: textTheme.bodyLarge),
            const SizedBox(height: 4),
            SettingSwitcher<String>(
              key: ValueKey('pushPersonTopic-${topic.topic}'),
              value: pushes.deliveryFor(topic.topic, connectionId) ?? _follow,
              onValueChanged: (picked) {
                if (picked == null) return;
                // "as for all" clears the person's own answer
                final delivery = switch (picked) {
                  _follow => null,
                  final picked => picked,
                };
                _change(context, () => Pushes.of(context).setFor(topic.topic, connectionId, delivery));
              },
              children: {
                _follow: Text(l.pushDeliveryFollow),
                for (final option in topic.options)
                  if (_deliveryLabel(l, option) case final String label) option: Text(label),
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// The way to the system's own settings for the app's notifications: banners,
/// sounds, the lock screen. Its icon says whether they are allowed at all.
class const _SystemNotificationsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final L(:pushSystemSettings, :pushSystemSettingsBody) = L.of(context);
    return FutureBuilder<bool>(
      future: hasNotificationsPermission(Theme.of(context).platform),
      builder: (context, snapshot) {
        return ListTile(
          leading: switch (snapshot.data ?? false) {
            true => const Icon(Icons.edit_notifications_rounded),
            false => const Icon(Icons.notifications_off_rounded),
          },
          title: Text(pushSystemSettings),
          subtitle: Text(pushSystemSettingsBody),
          onTap: openNotificationSettings,
        );
      },
    );
  }
}
