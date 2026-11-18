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

  /// Opens a client's copy of their program.
  final void Function(String connectionId, String programId) onOpenProgram;

  /// Opens the template editor on a session of a client's program, from the
  /// program beside them on a tablet (#693).
  final void Function(String connectionId, String programId, {required bool isNew}) onEditSession;

  /// Opens the conversation with a client.
  final ValueChanged<String> onMessage;

  /// Opens the coach's notes on a client.
  final ValueChanged<String> onNotes;

  /// Opens a workout to log for a client (#560).
  final void Function(String connectionId, PastWorkout past) onLog;

  const new({
    super.key,
    required this.onYourTraining,
    required this.onOpenClient,
    required this.onOpenWorkout,
    required this.onOpenProgram,
    required this.onEditSession,
    required this.onMessage,
    required this.onNotes,
    required this.onLog,
  });

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

/// The roster and the invitations, read again from the server, and the
/// former clients once anything read them: someone who left since joins
/// them. A coach left with nobody coached reads them too, since they're
/// then the only way to the notes kept on anyone.
Future<void> _reloadClients(BuildContext context) async {
  final roster = Roster.of(context);
  await Future.wait([
    roster.load(),
    Coaching.of(context).loadInvitations().catchError((_) {}),
  ]);
  if (roster.formerStatus != .idle || (roster.status == .loaded && roster.clients.isEmpty)) await roster.loadFormer();
}

/// Where a client opens beside the roster rather than over it: room for a
/// list of names and a client's workouts side by side.
const _besideWidth = 720.0;

/// Where a page has room for the roster, a client and the column beside
/// them: an 11" iPad on its side, past its rail.
const _threeColumnsAt = 1000.0;

/// How wide the roster stays with a client open beside it: narrower on a
/// page with room for a third column, as the coaching design's desk has it
/// (#693).
double _paneRosterWidth(double width) {
  return switch (width >= _threeColumnsAt) {
    true => 300,
    false => 280,
  };
}

class _ClientsPageState extends State<ClientsPage> {
  final _view = ValueNotifier(_ClientsView.roster);

  /// A coach shares a link from another app and comes back to see whether it
  /// was taken: the tab stays alive the whole time, so opening it once is
  /// not enough.
  late final _lifecycle = AppLifecycleListener(onResume: _resumed);

  /// When the roster was last read, so coming back to the app often doesn't
  /// read it each time.
  DateTime? _readAt;

  /// How stale the roster may be before coming back reads it again.
  static const _fresh = Duration(minutes: 1);

  void _reload() {
    if (!mounted) return;
    _readAt = clock.now();
    _reloadClients(context);
  }

  /// Reads the roster again on coming back, but only while it's what's on
  /// screen and it's more than [_fresh] old: another tab, a page over it, or
  /// a quick switch away and back reads nothing.
  void _resumed() {
    if (!mounted) return;
    final shown = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    final stale = switch (_readAt) {
      final DateTime at => clock.now().difference(at) >= _fresh,
      null => true,
    };
    if (shown && stale) _reload();
  }

  /// The client open beside the roster, on a page wide enough for both, and
  /// one of their workouts over them in the pane when that is what was
  /// opened.
  final _open = ValueNotifier<_Opened?>(null);

  /// Counts taps that open something beside the roster.
  var _taps = 0;

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
      // the roster caps itself; the page is the pane's too
      maxWidth: .infinity,
      child: switch ((roster.status, roster.clients, waiting)) {
        (.idle || .loading, [], []) => const Center(child: CircularProgressIndicator.adaptive()),
        (.failed, [], []) => _Empty(
          icon: Icons.cloud_off_rounded,
          title: l.coachingRosterFailed,
          action: OutlinedButton(onPressed: roster.load, child: Text(l.retry)),
        ),
        // nobody coached and nobody who was: the first invitation
        (_, [], []) when roster.former.isEmpty => _Empty(
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
        _ => LayoutBuilder(
          builder: (context, constraints) {
            final beside = constraints.maxWidth >= _besideWidth;
            return ValueListenableBuilder(
              valueListenable: _open,
              builder: (context, open, _) {
                // a client who left the roster since closes with it
                final shown = switch (open) {
                  final _Opened open when beside && roster.client(open.connectionId) != null => open,
                  _ => null,
                };
                final list = _ClientOpener(
                  selected: shown?.connectionId,
                  beside: beside,
                  // a fresh tap each time, so tapping what is already open
                  // starts the pane over rather than being equal to it
                  onOpenClient: (id) => switch (beside) {
                    true => _open.value = (connectionId: id, workoutId: null, tap: ++_taps),
                    false => widget.onOpenClient(id),
                  },
                  onOpenWorkout: (id, workoutId) => switch (beside) {
                    true => _open.value = (connectionId: id, workoutId: workoutId, tap: ++_taps),
                    false => widget.onOpenWorkout(id, workoutId),
                  },
                  // nobody coached: no activity, only invitations out and
                  // the people who were
                  child: switch (roster.clients.isEmpty) {
                    true => _RosterView(waiting: waiting),
                    false => _rosterOrActivity(l, waiting),
                  },
                );
                return MasterDetail(
                  masterWidth: _paneRosterWidth,
                  maxMasterWidth: _rosterMaxWidth,
                  master: list,
                  detail: switch (shown) {
                    final _Opened shown => _ClientPane(
                      // what was opened, afresh: another client, or a workout
                      // from Activity, starts the pane over
                      key: ValueKey(shown),
                      opened: shown,
                      onOpenProgram: (programId) => widget.onOpenProgram(shown.connectionId, programId),
                      onEditSession: (programId, {required isNew}) {
                        widget.onEditSession(shown.connectionId, programId, isNew: isNew);
                      },
                      onLog: widget.onLog,
                      onClose: () => _open.value = null,
                    ),
                    null => null,
                  },
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
            // a narrowed roster beside a client, under larger type: the two
            // words shrink rather than run off its edge
            child: FittedBox(
              fit: .scaleDown,
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

  /// Whether what a row opens goes beside the roster, which the rows' taps
  /// depend on: a turn of the device can change it with nothing selected.
  final bool beside;
  final ValueChanged<String> onOpenClient;
  final void Function(String connectionId, String workoutId) onOpenWorkout;

  const new({
    required this.selected,
    required this.beside,
    required this.onOpenClient,
    required this.onOpenWorkout,
    required super.child,
  });

  static _ClientOpener? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ClientOpener>();

  @override
  bool updateShouldNotify(_ClientOpener old) => selected != old.selected || beside != old.beside;
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
                // keeps its place, and the former ones open, as a client
                // opens beside it
                key: const PageStorageKey('Coaching.roster'),
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
                    if (roster.clients.isNotEmpty || roster.former.isNotEmpty) const _FormerClients(),
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
/// word, and the last seven days; set apart while opening them would clear
/// a reason.
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
      // something new since the coach last opened them: set apart until
      // they do, which is what clears it (#686)
      tileColor: switch (_lookClears(client)) {
        true => colorScheme.surfaceContainerHigh,
        false => null,
      },
      isThreeLine: true,
    );
  }
}

/// The table's columns, by flex.
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
    // the fill on the Material under the ink, so a set-apart row still
    // shows its splash, hover and focus
    return Material(
      color: switch (_lookClears(client)) {
        true => colorScheme.surfaceContainerHigh,
        false => Colors.transparent,
      },
      child: InkWell(
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
                        child: Text(
                          _clientName(l, client),
                          style: textTheme.bodyLarge,
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),
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
              ],
            ),
          ),
        ),
      ),
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
    final opener = _ClientOpener.of(context);
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
        // opened as a client is, for the coach's notes on them and what
        // the two of them wrote
        (.loaded, final former) => [
          for (final client in former)
            switch ((opener, _formerOpens(context, client.connectionId))) {
              // nothing kept of them here, as on the web with no
              // conversation left: a name, and nowhere to go
              (null, _) || (_, false) => ListTile(
                key: AppKeys.coachingClient(client.connectionId),
                leading: Avatar(remote: client.avatar, radius: 20),
                title: Text(_clientName(l, client)),
              ),
              (final opener?, true) => ListTile(
                key: AppKeys.coachingClient(client.connectionId),
                leading: Avatar(remote: client.avatar, radius: 20),
                title: Text(_clientName(l, client)),
                selected: opener.selected == client.connectionId,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => opener.onOpenClient(client.connectionId),
              ),
            },
        ],
      },
    );
  }
}

/// Whether opening [client] would clear a reason they have (#686): one a
/// look clears, which this build knows. A reason it doesn't know may hold
/// until it stops being true, and marking for it on every open would never
/// clear it.
bool _lookClears(ClientSummary client) {
  return client.reasons.any((reason) => ClientReason.of(reason)?.clearsOnReview ?? false);
}

/// Whether [client] is no longer coached: the connection was severed.
bool _former(ClientSummary client) => client.status == 'severed';

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
