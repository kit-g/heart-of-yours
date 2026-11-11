part of 'coaching.dart';

/// What the Clients tab shows: everyone, or what they all did.
enum _ClientsView { roster, activity }

/// Where the roster stops being a list and becomes a table, measured on the
/// page: a table's five columns need room a phone doesn't have.
const _tableWidth = 640.0;

/// How wide the roster's table grows: past this, its columns only drift apart.
const _rosterMaxWidth = 960.0;

/// The people this account coaches, those who may need a word first, and
/// the invitations still waiting for an answer (#553, #559).
class ClientsPage extends StatefulWidget {
  final VoidCallback onYourTraining;

  /// Opens a client's own page, where there's no room for it beside the
  /// roster.
  final ValueChanged<String> onOpenClient;

  /// Opens a client's workout, target beside done.
  final void Function(String connectionId, String workoutId) onOpenWorkout;

  const new({super.key, required this.onYourTraining, required this.onOpenClient, required this.onOpenWorkout});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

/// The roster and the invitations, read again from the server.
Future<void> _reloadClients(BuildContext context) {
  return Future.wait([
    Roster.of(context).load(),
    Coaching.of(context).loadInvitations().catchError((_) {}),
  ]);
}

/// Where a client opens beside the roster rather than over it: room for a
/// list of names and a client's workouts side by side.
const _besideWidth = 720.0;

/// How wide the roster stays with a client open beside it.
const _paneRosterWidth = 340.0;

class _ClientsPageState extends State<ClientsPage> {
  final _view = ValueNotifier(_ClientsView.roster);

  /// A coach shares a link from another app and comes back to see whether it
  /// was taken: the tab stays alive the whole time, so opening it once is
  /// not enough.
  late final _lifecycle = AppLifecycleListener(onResume: _reload);

  void _reload() {
    if (mounted) _reloadClients(context);
  }

  /// The client open beside the roster, on a page wide enough for both.
  final _open = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _lifecycle;
    // read on opening, as the tokens page is: the list is the server's
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _view.dispose();
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final roster = Roster.watch(context);
    final waiting = Coaching.watch(context).pendingInvitations.toList();
    final invite = IconButton(
      key: AppKeys.coachingInviteAction,
      tooltip: l.coachingInvite,
      onPressed: () => inviteSomeone(context),
      icon: const Icon(Icons.person_add_alt_1_rounded),
    );
    return _CoachingPage(
      title: l.coachingClients,
      onYourTraining: widget.onYourTraining,
      actions: [invite],
      maxWidth: _rosterMaxWidth,
      child: switch ((roster.status, roster.clients, waiting)) {
        (.idle || .loading, [], []) => const Center(child: CircularProgressIndicator.adaptive()),
        (.failed, [], []) => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.coachingRosterFailed,
          action: OutlinedButton(onPressed: roster.load, child: Text(l.retry)),
        ),
        (_, [], []) => _Empty(
          icon: Icons.groups_rounded,
          title: l.coachingNoClients,
          body: l.coachingNoClientsBody,
          action: FilledButton.icon(
            key: AppKeys.coachingInvite,
            onPressed: () => inviteSomeone(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: Text(l.coachingInvite),
          ),
        ),
        // invitations out, nobody accepted yet: nothing to have done
        (_, [], _) => _RosterView(waiting: waiting),
        _ => LayoutBuilder(
          builder: (context, constraints) {
            final beside = constraints.maxWidth >= _besideWidth;
            return ValueListenableBuilder(
              valueListenable: _open,
              builder: (context, open, _) {
                // a client who left the roster since closes with it
                final shown = switch (open) {
                  final String id when beside && roster.client(id) != null => id,
                  _ => null,
                };
                final list = _ClientOpener(
                  selected: shown,
                  onOpenClient: (id) => switch (beside) {
                    true => _open.value = id,
                    false => widget.onOpenClient(id),
                  },
                  onOpenWorkout: widget.onOpenWorkout,
                  child: _rosterOrActivity(l, waiting),
                );
                if (shown == null) return list;
                return Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    SizedBox(width: _paneRosterWidth, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _ClientView(
                        key: AppKeys.coachingClientPane,
                        connectionId: shown,
                        onOpenWorkout: (workoutId) => widget.onOpenWorkout(shown, workoutId),
                        leading: Align(
                          alignment: .centerRight,
                          child: IconButton(
                            key: AppKeys.coachingClientClose,
                            tooltip: l.coachingClientClose,
                            onPressed: () => _open.value = null,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      },
    );
  }
}

extension on _ClientsPageState {
  Widget _rosterOrActivity(L l, List<Invitation> waiting) {
    return ValueListenableBuilder(
      valueListenable: _view,
      builder: (context, view, _) => Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(16, 8, 16, 8),
            child: Center(
              child: SettingSwitcher<_ClientsView>(
                value: view,
                onValueChanged: (picked) => _view.value = picked ?? view,
                children: {
                  .roster: Text(l.coachingClients, key: AppKeys.coachingRosterView),
                  .activity: Text(l.coachingActivity, key: AppKeys.coachingActivityView),
                },
              ),
            ),
          ),
          Expanded(
            child: switch (view) {
              .roster => _RosterView(waiting: waiting),
              .activity => const _ActivityView(),
            },
          ),
        ],
      ),
    );
  }
}

/// How a row of the roster or the feed opens what it names: beside the
/// roster where there's room, over it where there isn't.
class _ClientOpener extends InheritedWidget {
  /// The client open beside the roster, if any.
  final String? selected;
  final ValueChanged<String> onOpenClient;
  final void Function(String connectionId, String workoutId) onOpenWorkout;

  const new({
    required this.selected,
    required this.onOpenClient,
    required this.onOpenWorkout,
    required super.child,
  });

  static _ClientOpener? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ClientOpener>();

  @override
  bool updateShouldNotify(_ClientOpener old) => selected != old.selected;
}

/// Everyone, sorted by who may need a word, with a filter for each reason
/// any of them has: a list on a phone, a table where there is room.
class _RosterView extends StatefulWidget {
  final List<Invitation> waiting;

  const new({required this.waiting});

  @override
  State<_RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<_RosterView> {
  /// The reason to filter by, by its server name; null for everyone.
  final _reason = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = Roster.watch(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = constraints.maxWidth >= _tableWidth;
        return ValueListenableBuilder(
          valueListenable: _reason,
          builder: (context, picked, _) {
            final reasons = roster.reasons;
            // a filter whose last client was looked at has nothing left to show
            final reason = switch (picked) {
              final String picked when reasons.contains(picked) => picked,
              _ => null,
            };
            final clients = switch (reason) {
              final String reason => roster.withReason(reason).toList(),
              null => roster.clients,
            };
            return RefreshIndicator.adaptive(
              onRefresh: () => _reloadClients(context),
              child: ListView(
                padding: const .only(bottom: 24),
                children: [
                  if (reasons.isNotEmpty)
                    _ReasonFilter(reasons: reasons, picked: reason, onPicked: (each) => _reason.value = each),
                  if (table && clients.isNotEmpty) const _TableHeader(),
                  for (final client in clients)
                    switch (table) {
                      true => _ClientRow(client: client),
                      false => _ClientTile(client: client),
                    },
                  if (reason == null) ...[
                    if (widget.waiting.isNotEmpty) _WaitingInvitations(invitations: widget.waiting),
                    if (roster.clients.isNotEmpty) const _FormerClients(),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// One chip per reason any client has, and one for everyone.
class _ReasonFilter extends StatelessWidget {
  final Set<String> reasons;
  final String? picked;
  final ValueChanged<String?> onPicked;

  const new({required this.reasons, required this.picked, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    // two words this build doesn't know read alike, so they share a chip's
    // words but keep their own filter
    // one line that scrolls sideways: wrapped, five chips took a phone's
    // first third before the first client
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const .fromLTRB(16, 4, 16, 8),
      child: Row(
        spacing: 8,
        children: [
          for (final reason in [null, ...reasons])
            ChoiceChip(
              key: AppKeys.coachingReasonFilter(reason),
              label: Text(switch (reason) {
                final String reason => _reasonWords(l, reason),
                null => l.coachingEveryone,
              }),
              selected: picked == reason,
              onSelected: (_) => onPicked(reason),
            ),
        ],
      ),
    );
  }
}

/// A client on a phone: who, their program and week, why they may need a
/// word, the last seven days, and "looked at" while a look would clear one.
class _ClientTile extends StatelessWidget {
  final ClientSummary client;

  const new({required this.client});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final reasons = _reasonsInWords(l, client);
    final opener = _ClientOpener.of(context);
    return ListTile(
      key: AppKeys.coachingClient(client.connectionId),
      onTap: switch (opener) {
        final opener? => () => opener.onOpenClient(client.connectionId),
        null => null,
      },
      selected: opener?.selected == client.connectionId,
      leading: Avatar(remote: client.avatar, radius: 20),
      title: Text(_clientName(l, client), maxLines: 1, overflow: .ellipsis),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(_programLine(l, client), maxLines: 1, overflow: .ellipsis),
          const SizedBox(height: 6),
          _WeekDots(client: client),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reasons.join(' · '), style: textTheme.bodySmall?.copyWith(color: colorScheme.tertiary)),
          ],
        ],
      ),
      trailing: switch (_lookClears(client)) {
        true => _MarkReviewed(client: client),
        false => null,
      },
      isThreeLine: true,
    );
  }
}

/// The table's columns, by flex, with "looked at" a fixed button's width.
const _columns = (client: 3, program: 3, days: 2, reasons: 3);

class _TableHeader extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    final style = textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
    return Padding(
      padding: const .fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: _columns.client,
            child: Text(l.coachingColumnClient, style: style),
          ),
          Expanded(
            flex: _columns.program,
            child: Text(l.coachingColumnProgram, style: style),
          ),
          Expanded(
            flex: _columns.days,
            child: Text(l.coachingColumnWeek, style: style),
          ),
          Expanded(
            flex: _columns.reasons,
            child: Text(l.coachingColumnReasons, style: style),
          ),
          const SizedBox(width: kMinInteractiveDimension),
        ],
      ),
    );
  }
}

/// A client as a table row, where the page has the width.
class _ClientRow extends StatelessWidget {
  final ClientSummary client;

  const new({required this.client});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final ThemeData(:textTheme, :colorScheme, :dividerColor) = Theme.of(context);
    final opener = _ClientOpener.of(context);
    return InkWell(
      key: AppKeys.coachingClient(client.connectionId),
      onTap: switch (opener) {
        final opener? => () => opener.onOpenClient(client.connectionId),
        null => null,
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: dividerColor.withValues(alpha: .4))),
        ),
        child: Padding(
          padding: const .fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: _columns.client,
                child: Row(
                  children: [
                    Avatar(remote: client.avatar, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_clientName(l, client), style: textTheme.bodyLarge, maxLines: 1, overflow: .ellipsis),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: _columns.program,
                child: Padding(
                  padding: const .only(right: 8),
                  child: Text(_programLine(l, client), style: textTheme.bodyMedium, maxLines: 2, overflow: .ellipsis),
                ),
              ),
              Expanded(
                flex: _columns.days,
                child: Align(
                  alignment: .centerLeft,
                  child: _WeekDots(client: client),
                ),
              ),
              Expanded(
                flex: _columns.reasons,
                child: Text(
                  _reasonsInWords(l, client).join(' · '),
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.tertiary),
                ),
              ),
              SizedBox(
                width: kMinInteractiveDimension,
                child: switch (_lookClears(client)) {
                  true => _MarkReviewed(client: client),
                  false => null,
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The coach has looked at a client: their note or lighter session stops
/// counting.
class _MarkReviewed extends StatelessWidget {
  final ClientSummary client;

  const new({required this.client});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return IconButton(
      key: AppKeys.coachingMarkReviewed(client.connectionId),
      tooltip: l.coachingMarkReviewed,
      icon: const Icon(Icons.done_rounded),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final failed = l.coachingMarkReviewedFailed;
        try {
          await Roster.of(context).markReviewed(client);
        } catch (_) {
          messenger.snack(failed);
        }
      },
    );
  }
}

/// The last seven days as dots, today last: filled for a day they trained.
class _WeekDots extends StatelessWidget {
  final ClientSummary client;

  const new({required this.client});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme) = Theme.of(context);
    final days = client.lastSevenDays(clock.now());
    return Semantics(
      label: L.of(context).coachingLastSevenDays(days.where((trained) => trained).length),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: .min,
        spacing: 4,
        children: [
          for (final trained in days)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: .circle,
                color: switch (trained) {
                  true => colorScheme.primary,
                  false => null,
                },
                border: Border.all(
                  color: switch (trained) {
                    true => colorScheme.primary,
                    false => colorScheme.outline,
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The people the coach no longer coaches, read the first time they're
/// opened: most coaches look rarely, if ever.
class _FormerClients extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final roster = Roster.watch(context);
    return ExpansionTile(
      key: AppKeys.coachingFormerClients,
      title: Text(l.coachingFormerClients),
      onExpansionChanged: (open) {
        if (open && roster.formerStatus == .idle) roster.loadFormer();
      },
      children: switch ((roster.formerStatus, roster.former)) {
        (.idle || .loading, _) => [const Padding(padding: .all(16), child: CircularProgressIndicator.adaptive())],
        (.failed, _) => [
          ListTile(
            title: Text(l.coachingRosterFailed),
            trailing: TextButton(onPressed: roster.loadFormer, child: Text(l.retry)),
          ),
        ],
        (.loaded, []) => [ListTile(title: Text(l.coachingNoFormerClients))],
        (.loaded, final former) => [
          for (final client in former)
            ListTile(
              key: AppKeys.coachingClient(client.connectionId),
              leading: Avatar(remote: client.avatar, radius: 20),
              title: Text(_clientName(l, client)),
            ),
        ],
      },
    );
  }
}

/// Whether a look would clear anything: a gap or an ending holds until it
/// stops being true, so a button for those alone would do nothing. A reason
/// this build doesn't know might clear, so it gets the button.
bool _lookClears(ClientSummary client) {
  return client.reasons.any((reason) => ClientReason.of(reason)?.clearsOnReview ?? true);
}

String _clientName(L l, ClientSummary client) {
  return switch (client.name?.trim()) {
    final String name when name.isNotEmpty => name,
    _ => l.coachingClientUnnamed,
  };
}

/// Their program and week, and whether coaching is paused.
String _programLine(L l, ClientSummary client) {
  final program = switch (client) {
    ClientSummary(programName: final String name, programWeek: final int week, programWeeks: final int weeks) =>
      l.coachingClientWeek(name, week, weeks),
    ClientSummary(programName: final String name, programWeek: final int week) => l.coachingClientWeekOpen(name, week),
    ClientSummary(programName: final String name) => name,
    _ => l.coachingClientNoProgram,
  };
  return switch (client.status) {
    'paused' => '$program · ${l.coachingClientPaused}',
    _ => program,
  };
}

/// Each reason once, in words: two this build doesn't know read alike.
List<String> _reasonsInWords(L l, ClientSummary client) {
  return {for (final reason in client.reasons) _reasonWords(l, reason)}.toList();
}

String _reasonWords(L l, String reason) {
  return switch (ClientReason.of(reason)) {
    .lighter => l.coachingReasonLighter,
    .note => l.coachingReasonNote,
    .gap => l.coachingReasonGap,
    .ending => l.coachingReasonEnding,
    null => l.coachingReasonOther,
  };
}
