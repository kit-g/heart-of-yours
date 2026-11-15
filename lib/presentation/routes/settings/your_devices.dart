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

  @override
  void initState() {
    super.initState();
    // after the first frame: the read notifies, and the page watches it
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void dispose() {
    _failed.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    if (!mounted) return;
    final userId = Auth.of(context).user?.id;
    if (userId == null) return;
    _failed.value = false;
    try {
      await DeviceKeys.of(context).devicesOf(userId);
    } catch (_) {
      // offline, or keys not running yet: the page offers to read again
      _failed.value = true;
    }
  }

  Future<void> _compare(String deviceId) async {
    final approval = DeviceKeys.of(context).approval;
    // the sheet follows the comparison from its first step
    final starting = approval.start(deviceId);
    final sheet = showCodeComparison(context, approval);
    try {
      await starting;
    } catch (error, stacktrace) {
      // the sheet says it failed: the cause goes to the logs
      widget.onError?.call(error, stacktrace: stacktrace);
    }
    await sheet;
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
          padding: .symmetric(horizontal: math.max(0, (constraints.maxWidth - _maxWidth) / 2)),
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
              Text(switch ((each.id == self, each.trusted)) {
                (true, _) => l.thisDevice,
                (false, true) => l.deviceApproved,
                (false, false) => l.deviceNotApproved,
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
