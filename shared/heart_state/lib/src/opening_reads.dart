import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

/// Whether a launch's first reads are out of the way (#676).
///
/// A launch reads what its opening page shows: the account, the exercises,
/// the history, the templates, the programs. Everything else the session
/// wants from the server (flagged entries, device keys, messages, a coach's
/// people) used to dial out in the same second, and the gateway counts
/// requests in flight per account. So the rest waits here until those are in:
/// [begin] when startup starts dialling, [settle] when the opening page has
/// its data, and whoever waits listens, or hands [after] what to run.
///
/// Settled until a launch begins, so nothing waits where there is no launch
/// to wait for (a test, a tool), and never held for longer than [limit]: a
/// startup that stalls, offline or on a catalog that never arrives, does not
/// take the rest of the session with it.
class OpeningReads with ChangeNotifier {
  /// The longest the rest of the session waits for the opening page.
  final Duration limit;

  new({this.limit = const Duration(seconds: 8)});

  Timer? _waiting;

  /// The launch being waited for: a session that ended must not open the
  /// gate for the one that replaced it.
  Object? _launch;
  bool _disposed = false;

  /// Whether the reads that waited may go.
  bool get settled => _waiting == null;

  /// A launch's reads are going out: the rest waits for [settle]. Answers
  /// the launch, for its own [settle] to name.
  Object begin() {
    final launch = Object();
    if (_disposed) return launch;
    _waiting?.cancel();
    _launch = launch;
    _waiting = Timer(limit, settle);
    return launch;
  }

  /// The opening page has its data, or will not get it soon. With [launch],
  /// only while that launch is the one waited for; without, whichever is:
  /// the session changed hands, and what waited is let go.
  void settle([Object? launch]) {
    if (_disposed || _waiting == null) return;
    if (launch != null && !identical(launch, _launch)) return;
    _waiting?.cancel();
    _waiting = null;
    _launch = null;
    notifyListeners();
  }

  /// Runs [read] once the opening reads are in: now, when they already are.
  void after(VoidCallback read) {
    if (settled) return read();
    void run() {
      removeListener(run);
      read();
    }

    addListener(run);
  }

  @override
  void dispose() {
    _disposed = true;
    _waiting?.cancel();
    _waiting = null;
    super.dispose();
  }

  /// The app's, or null where none was provided: a presenter pumped alone.
  static OpeningReads? maybeOf(BuildContext context) {
    return Provider.of<OpeningReads?>(context, listen: false);
  }
}
