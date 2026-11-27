part of 'settings.dart';

/// The account's devices that hold coaching's encryption keys (#555), and the
/// way to let one in: a device the account adds gets none of its messages
/// and notes until one it already has compares a code with it.
///
/// Reads the account's devices on every open: one added elsewhere since the
/// last look belongs here.
class YourDevicesPage extends StatefulWidget {
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  const new({super.key, this.onError});

  @override
  State<YourDevicesPage> createState() => _YourDevicesPageState();
}

class _YourDevicesPageState extends State<YourDevicesPage> {
  /// The last read failed: said with a way to read again.
  final _failed = ValueNotifier(false);

  /// Reading the queue for a comparison asked for elsewhere, which no push may
  /// tell of (#734): while the page is on screen, for as long as one lives.
  VoidCallback? _stopExpecting;
  Timer? _expecting;
  ValueListenable<TickerModeData>? _visible;

  static const _expectsFor = Duration(minutes: 5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // off on another tab, whose pages stay built, and under another page
    final visible = TickerMode.getValuesNotifier(context);
    if (identical(visible, _visible)) return;
    _visible?.removeListener(_expect);
    _visible = visible..addListener(_expect);
    _expect();
  }

  void _expect() {
    _expecting?.cancel();
    _stopExpecting?.call();
    _expecting = null;
    _stopExpecting = null;
    if (!(_visible?.value.enabled ?? false)) return;
    final stop = _stopExpecting = DeviceKeys.of(context).approval.expectAsk();
    _expecting = Timer(_expectsFor, stop);
  }

  @override
  void initState() {
    super.initState();
    // after the first frame: the read notifies, and the page watches it
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void dispose() {
    _visible?.removeListener(_expect);
    _expecting?.cancel();
    _stopExpecting?.call();
    _failed.dispose();
    _removing.dispose();
    _startingOver.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    if (!mounted) return;
    final userId = Auth.of(context).user?.id;
    if (userId == null) return;
    _failed.value = false;
    final keys = DeviceKeys.of(context);
    // one already asked for shows at once
    unawaited(keys.refresh());
    try {
      await keys.devicesOf(userId);
    } catch (_) {
      // offline, or keys not running yet: the page offers to read again
      if (mounted) _failed.value = true;
    }
  }

  /// A comparison this page is starting, until its sheet closes: a second
  /// tap before the sheet covers the button starts nothing.
  bool _starting = false;

  Future<void> _compare(String deviceId) async {
    if (_starting) return;
    _starting = true;
    try {
      final approval = DeviceKeys.of(context).approval;
      final Future<void> asking;
      try {
        asking = approval.start(deviceId);
      } on StateError {
        // another comparison runs, or keys stopped meanwhile: nothing began,
        // so there is no sheet to show, and nothing for the logs
        snack(context, L.of(context).compareCodesCantStart);
        return;
      }
      // the sheet follows the comparison from its first step, and only it
      final sheet = showCodeComparison(context, approval, approval.value!.id);
      try {
        await asking;
      } catch (error, stacktrace) {
        // the sheet says it failed: the cause goes to the logs
        widget.onError?.call(error, stacktrace: stacktrace);
      }
      await sheet;
    } finally {
      _starting = false;
    }
  }

  /// The devices being removed from here: their menus are gone until it ends.
  final _removing = ValueNotifier(const <String>{});

  /// Starting over as a new device, while it runs.
  final _startingOver = ValueNotifier(false);

  /// After this device was removed: new keys, then the list again.
  Future<void> _startOver() async {
    if (_startingOver.value) return;
    _startingOver.value = true;
    final l = L.of(context);
    try {
      await DeviceKeys.of(context).startOver();
      await _read();
    } catch (error, stacktrace) {
      if (mounted) snack(context, l.deviceStartOverFailed);
      widget.onError?.call(error, stacktrace: stacktrace);
    } finally {
      _startingOver.value = false;
    }
  }

  /// Asks once, then removes [device] for good, from the menu [anchor]
  /// opened under. One this device may not remove yet is offered greyed,
  /// saying when it may.
  Future<void> _remove(BuildContext anchor, CryptoDevice device) async {
    final l = L.of(context);
    final keys = DeviceKeys.of(context);
    final deviceId = device.id;
    final later = keys.removableAt(device);
    final picked = await showMenu<_DeviceAction>(
      context: anchor,
      position: menuUnder(anchor),
      items: [
        PopupMenuItem(
          key: AppKeys.deviceRemove(deviceId),
          value: .remove,
          enabled: later == null,
          child: switch (later) {
            null => Text(l.deviceRemove),
            final DateTime at => Column(
              crossAxisAlignment: .start,
              children: [
                Text(l.deviceRemove),
                Text(l.deviceRemovableFrom(_when(l, at)), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          },
        ),
      ],
    );
    if (picked != .remove || !mounted) return;
    final sure = await confirmDestructive(
      context,
      title: l.deviceRemoveTitle(deviceName(l, deviceId)),
      body: l.deviceRemoveBody,
      confirm: l.deviceRemove,
      cancel: l.cancel,
      key: AppKeys.deviceRemoveConfirm,
    );
    if (!sure || !mounted || _removing.value.contains(deviceId)) return;
    _removing.value = {..._removing.value, deviceId};
    try {
      await keys.remove(deviceId);
    } on RemovalRefused catch (refused) {
      // the server's reasons, said as they are: none of them a failure here
      if (mounted) {
        snack(context, switch (refused) {
          RemovalRefused(reason: .tooNew, removableAt: final DateTime at) => l.deviceRemoveTooNew(_when(l, at)),
          RemovalRefused(reason: .tooNew) => l.deviceRemoveTooNewUnknown,
          RemovalRefused(reason: .notJoined) => l.deviceRemoveNotJoined,
          RemovalRefused(reason: .clock) => l.deviceRemoveClock,
        });
      }
    } catch (error, stacktrace) {
      if (mounted) snack(context, l.deviceRemoveFailed);
      widget.onError?.call(error, stacktrace: stacktrace);
    } finally {
      _removing.value = {..._removing.value}..remove(deviceId);
    }
  }

  /// A moment, in the reader's language: the day and the time.
  static String _when(L l, DateTime at) => DateFormat.MMMd(l.localeName).add_jm().format(at.toLocal());

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final keys = DeviceKeys.watch(context);
    final peer = switch (Auth.of(context).user?.id) {
      final String userId => keys.peer(userId),
      null => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.yourDevices),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: LogoStripe(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: .fromLTRB(
            math.max(0, (constraints.maxWidth - _maxWidth) / 2),
            0,
            math.max(0, (constraints.maxWidth - _maxWidth) / 2),
            // over the whole app, nothing below it keeps clear of the edge
            MediaQuery.paddingOf(context).bottom,
          ),
          children: switch (keys.status) {
            // it holds nothing now, and lists nothing: only the way back
            .removed => [_RemovedHere(startingOver: _startingOver, onStartOver: _startOver)],
            .off || .local || .published || .failed || .waiting || .full => [
              ...switch (keys.status) {
                .waiting => [_Full(words: l.yourDevicesFull)],
                .full => [_Full(words: l.yourDevicesFullElsewhere)],
                .off || .local || .published || .failed || .removed => const <Widget>[],
              },
              Padding(
                padding: const .all(16),
                child: Text(l.yourDevicesExplainer),
              ),
              ...switch (peer) {
                final Peer peer => [
                  ..._rows(context, l, keys, peer),
                  ..._waiting(context, l, keys),
                  ..._removedLately(context, l, keys),
                ],
                null => [
                  ValueListenableBuilder(
                    valueListenable: _failed,
                    builder: (context, failed, _) {
                      return switch (failed) {
                        true => Align(
                          child: PrimaryButton.shrunk(onPressed: _read, child: Text(l.retry)),
                        ),
                        false => const LinearProgressIndicator(),
                      };
                    },
                  ),
                ],
              },
            ],
          },
        ),
      ),
    );
  }

  List<Widget> _rows(BuildContext context, L l, DeviceKeys keys, Peer peer) {
    final self = keys.deviceId;
    final format = DateFormat.yMMMd(l.localeName);
    // this device first, then the others newest first
    final devices = [...peer.devices]
      ..sort(
        (a, b) => switch ((a.id == self, b.id == self)) {
          (true, _) => -1,
          (_, true) => 1,
          _ => b.device.createdAt.compareTo(a.device.createdAt),
        },
      );
    // comparing a code travels through the queue, which needs this device's
    // keys on the server
    final canCompare = keys.status == .published;
    final seen = _Seen(l, format);
    return [
      for (final each in devices)
        ListTile(
          key: AppKeys.deviceRow(each.id),
          leading: Icon(each.id == self ? Icons.smartphone_rounded : Icons.devices_other_rounded),
          title: Text(deviceName(l, each.id)),
          subtitle: Column(
            crossAxisAlignment: .start,
            children: [
              // approved: trusted from here, by a compared code or a vouch
              // from one that was, and on the server for the account's other
              // devices too; one whose vouch from here hasn't landed yet says
              // so, and the vouch is tried again on its own
              Text(switch ((each.id == self, each.trusted, keys.owesVouch(each.id))) {
                (true, _, _) => l.thisDevice,
                (false, true, false) => l.deviceApproved,
                (false, true, true) => l.deviceApprovedHereOnly,
                (false, false, _) => l.deviceNotApproved,
              }),
              Text(l.deviceAddedOn(format.format(each.device.createdAt.toLocal()))),
              if (each.id != self) ?seen.line(context, each.device),
              // under the words, so the title keeps the row's width in every
              // language and at large text
              if (canCompare && each.id != self && !each.trusted)
                Padding(
                  padding: const .only(top: 8),
                  child: OutlinedButton(
                    key: AppKeys.compareCodes(each.id),
                    onPressed: () => _compare(each.id),
                    child: Text(l.compareCodes),
                  ),
                ),
            ],
          ),
          // this device is never removed from here
          trailing: switch (each.id == self) {
            true => null,
            false => _menu(l, keys, each.device),
          },
        ),
    ];
  }

  /// [device]'s menu, while this device may sign a removal at all: the server
  /// knows it, in its place or waiting for one. Gone while [device] is on its
  /// way out.
  Widget? _menu(L l, DeviceKeys keys, CryptoDevice device) {
    final signs = switch (keys.status) {
      .published || .waiting => true,
      .off || .local || .failed || .full || .removed => false,
    };
    if (!signs) return null;
    return ValueListenableBuilder(
      valueListenable: _removing,
      builder: (context, removing, _) => switch (removing.contains(device.id)) {
        // on its way out: nothing more to ask of it
        true => const SizedBox.square(dimension: kMinInteractiveDimension),
        false => Builder(
          builder: (anchor) => IconButton(
            key: AppKeys.deviceMenu(device.id),
            tooltip: l.deviceOptions,
            icon: Icon(switch (Theme.of(context).platform) {
              .iOS || .macOS => Icons.more_horiz_rounded,
              _ => Icons.more_vert_rounded,
            }),
            onPressed: () => _remove(anchor, device),
          ),
        ),
      },
    );
  }

  /// The account's other devices waiting for a place (#750): nothing is sent
  /// to them, and they may be removed like the rest.
  List<Widget> _waiting(BuildContext context, L l, DeviceKeys keys) {
    final waiting = keys.waiting;
    if (waiting.isEmpty) return const [];
    final format = DateFormat.yMMMd(l.localeName);
    return [
      _Heading(key: AppKeys.yourDevicesWaiting, words: l.yourDevicesWaiting),
      for (final each in waiting)
        ListTile(
          key: AppKeys.waitingRow(each.id),
          leading: const Icon(Icons.hourglass_empty_rounded),
          title: Text(deviceName(l, each.id)),
          subtitle: Text(l.deviceWaitingSince(format.format(each.createdAt.toLocal()))),
          trailing: _menu(l, keys, each),
        ),
    ];
  }

  /// What the account removed in the last weeks (#750), newest first, by
  /// which device: one this device didn't remove stands out, since a removal
  /// nobody recognises means someone else has the password.
  List<Widget> _removedLately(BuildContext context, L l, DeviceKeys keys) {
    final removed = keys.removedLately;
    if (removed.isEmpty) return const [];
    final format = DateFormat.yMMMd(l.localeName);
    final colorScheme = Theme.of(context).colorScheme;
    return [
      _Heading(key: AppKeys.yourDevicesRemovedLately, words: l.yourDevicesRemovedLately),
      for (final each in removed)
        ListTile(
          key: AppKeys.removedRow(each.id),
          leading: switch (each.removedBy == keys.deviceId) {
            true => Icon(Icons.remove_circle_outline_rounded, color: colorScheme.onSurfaceVariant),
            false => Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
              semanticLabel: l.deviceRemovedElsewhere,
            ),
          },
          title: Text(deviceName(l, each.id)),
          subtitle: Text(switch ((each.removedBy, each.removedAt)) {
            (final String by, final DateTime at) when by == keys.deviceId => l.deviceRemovedByThis(
              format.format(at.toLocal()),
            ),
            (final String by, final DateTime at) => l.deviceRemovedBy(deviceName(l, by), format.format(at.toLocal())),
            (null, final DateTime at) => l.deviceRemovedOn(format.format(at.toLocal())),
            (_, null) => l.deviceRemovedUnknown,
          }),
        ),
    ];
  }
}

/// A section's heading on the page.
class _Heading extends StatelessWidget {
  final String words;

  const new({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:textTheme, :colorScheme) = Theme.of(context);
    return Padding(
      padding: const .fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(words, style: textTheme.titleSmall?.copyWith(color: colorScheme.primary)),
      ),
    );
  }
}

/// When a device last reached the server, by day: today, yesterday, a date,
/// and, past [_stale], since when it hasn't, with a quiet mark.
class _Seen {
  final L l;
  final DateFormat format;

  const new(this.l, this.format);

  static const _stale = 14;

  Widget? line(BuildContext context, CryptoDevice device) {
    final on = device.lastSeenOn;
    if (on == null) return null;
    final now = DateTime.now().toUtc();
    // both UTC days, as the server keeps them
    final days = DateTime.utc(now.year, now.month, now.day).difference(on).inDays;
    final date = format.format(on);
    return switch (days) {
      >= _stale => Row(
        key: AppKeys.deviceStale(device.id),
        spacing: 4,
        children: [
          Icon(Icons.history_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          Flexible(child: Text(l.deviceNotSeenSince(date))),
        ],
      ),
      <= 0 => Text(l.deviceSeenToday),
      1 => Text(l.deviceSeenYesterday),
      _ => Text(l.deviceSeenOn(date)),
    };
  }
}

/// This device was removed and forgot its keys (#750): said, with the one
/// way back, as a new device.
class _RemovedHere extends StatelessWidget {
  final ValueListenable<bool> startingOver;
  final VoidCallback onStartOver;

  const new({required this.startingOver, required this.onStartOver});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      key: AppKeys.yourDevicesRemoved,
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          Text(l.yourDevicesRemoved),
          ValueListenableBuilder(
            valueListenable: startingOver,
            builder: (context, starting, _) => switch (starting) {
              true => const LinearProgressIndicator(),
              false => PrimaryButton.shrunk(
                key: AppKeys.deviceStartOver,
                hitHeight: kMinInteractiveDimension,
                onPressed: onStartOver,
                child: Text(l.deviceStartOver),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// What a device's menu offers.
enum _DeviceAction { remove }

/// Said at the top while the account has no place for this device (#750):
/// what to do, here or on another device.
class _Full extends StatelessWidget {
  final String words;

  const new({required this.words});

  @override
  Widget build(BuildContext context) {
    final ThemeData(:colorScheme, :textTheme) = Theme.of(context);
    return Padding(
      key: AppKeys.yourDevicesFull,
      padding: const .fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: colorScheme.error),
          Expanded(
            child: Text(words, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
