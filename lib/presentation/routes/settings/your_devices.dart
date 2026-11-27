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
          children: [
            Padding(
              padding: const .all(16),
              child: Text(l.yourDevicesExplainer),
            ),
            ...switch (peer) {
              final Peer peer => _rows(context, l, keys, peer),
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
            ],
          ),
          trailing: switch (canCompare && each.id != self && !each.trusted) {
            true => OutlinedButton(
              key: AppKeys.compareCodes(each.id),
              onPressed: () => _compare(each.id),
              child: Text(l.compareCodes),
            ),
            false => null,
          },
        ),
    ];
  }
}
