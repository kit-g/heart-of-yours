import 'dart:async';

import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/push.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Runs the push client (#567): the app's first, and coaching's.
///
/// Opt-in through the features that push: it starts only with an account and
/// a coaching switch on (Coach people for an account that may coach, or Your
/// coach). Off, nothing reaches FCM or the server, and no channel shows in
/// the system's settings. When a switch goes off, or the person signs out, the
/// server is told to stop sending to this device (heart-api#415) and then the
/// token is dropped, so nothing sent to it arrives any more.
///
/// It never asks for the notification permission itself: silent pushes need
/// none, and the ask comes from the first thing that would push
/// ([askForPushes]).
///
/// Sits below Localizations (MaterialApp's builder): the Android channels are
/// named in the person's language.
class PushPresenter extends StatefulWidget {
  final Widget child;

  /// FCM, or null for a pass-through: web, desktop, tests, a build that never
  /// initialised notifications.
  final PushClient? client;

  const new({super.key, required this.child, required this.client});

  @override
  State<PushPresenter> createState() => _PushPresenterState();
}

/// Whether the push client runs: an account, and a coaching switch on (Coach
/// people counting only for an account that may coach). The one rule the
/// presenter and the Settings row both read.
bool pushesOn(BuildContext context, {bool listen = false}) {
  final preferences = Provider.of<Preferences>(context, listen: listen);
  final auth = Provider.of<Auth>(context, listen: listen);
  return _pushesOn(preferences, auth);
}

bool _pushesOn(Preferences preferences, Auth auth) {
  final account = auth.user != null && !auth.isAnonymous;
  final space = preferences.isOn(.coachPeople) && (auth.user?.mayCoach ?? false);
  return account && (space || preferences.isOn(.yourCoach));
}

/// Whether [_pushesOn]'s answer can be acted on. A coach with only Coach
/// people on reads as one who may not coach from the sign-in until the
/// server's copy of the account arrives, and that is no reason to drop the
/// token: the answer waits for the entitlements.
bool _pushesDecided(Preferences preferences, Auth auth) {
  final account = auth.user != null && !auth.isAnonymous;
  return !account || auth.entitlementsKnown || !preferences.isOn(.coachPeople) || preferences.isOn(.yourCoach);
}

/// Asks for the notification permission, in context: from the first thing
/// that would push, after the person's own yes to the feature, never at
/// launch (`docs/opt-in.md`). Does nothing where the push client cannot run,
/// and the OS asks only once whatever the number of calls.
Future<void> askForPushes(BuildContext context) async {
  final client = context.findAncestorStateOfType<_PushPresenterState>()?.widget.client;
  await client?.askPermission(analytics: Analytics.of(context));
}

class _PushPresenterState extends State<PushPresenter> {
  Preferences? _preferences;
  Auth? _auth;
  late final AppLifecycleListener _lifecycle;

  /// Whether the client should be running: null before the first look.
  bool? _live;

  /// Whether the client was last started (true) or stopped (false): null
  /// before either. Trails [_live] while a start or stop is on its way.
  bool? _running;

  /// The starts and stops, one at a time and in order: a stop that came while
  /// a start was still awaiting the platform would otherwise cancel nothing
  /// and leave a token made.
  Future<void> _settling = Future.value();

  /// This device's token, once FCM gave one.
  String? _token;

  final _subscriptions = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    pushTaps.addListener(_onTap);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    final auth = Auth.of(context);
    if (!identical(auth, _auth)) {
      _auth?.removeListener(_sync);
      _auth = auth..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _preferences?.removeListener(_sync);
    _auth?.removeListener(_sync);
    pushTaps.removeListener(_onTap);
    _lifecycle.dispose();
    _cancel();
    super.dispose();
  }

  void _sync() {
    final (preferences, auth, client) = (_preferences, _auth, widget.client);
    if (client == null || preferences == null || auth == null || !preferences.isInitialized) return;
    // before Firebase's first answer there is no user at all, which is not
    // the same as a session without an account: nothing is decided yet
    if (auth.user == null && _live == null) return;
    if (!_pushesDecided(preferences, auth)) return;
    final live = _pushesOn(preferences, auth);
    if (live != _live) {
      _live = live;
      _settle(client);
    } else if (live) {
      // the token may have come before the account's: Auth tells again once
      // the server's copy of the account arrives, and Pushes registers once
      _register();
    }
  }

  /// Queues a step towards [_live]. Each step reads [_live] when its turn
  /// comes, so a quick on and off ends where the switches are, whatever was
  /// asked of the platform on the way.
  void _settle(PushClient client) {
    _settling = _settling
        .then((_) {
          if (!mounted) return null;
          return switch ((_live, _running)) {
            (true, false || null) => _start(client),
            (false, true || null) => _stop(client),
            _ => null,
          };
        })
        .catchError((Object error, StackTrace stacktrace) {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stacktrace, library: 'push'));
        });
  }

  /// Starts the client, giving up between each wait the moment the switches
  /// are off again: the stop queued behind it takes down what was made.
  Future<void> _start(PushClient client) async {
    _running = true;
    final L(:pushKindComments, :pushKindMessages, :pushKindCoaching) = L.of(context);
    await client.createChannels(
      comments: pushKindComments,
      messages: pushKindMessages,
      coaching: pushKindCoaching,
    );
    if (!mounted || _live != true) return;
    _subscriptions.addAll([
      client.tokens.listen((token) {
        _token = token;
        _register();
      }),
      client.arrived.listen((arrival) => _arrived(arrival.push, title: arrival.title)),
      client.opened.listen(_open),
    ]);
    _token = await client.start();
    if (!mounted || _live != true) return;
    _register();
    if (await client.launchedBy() case final Push push when mounted) await _open(push);
    await _drain();
    // a tap on one the app showed itself, from before this was listening
    _onTap();
  }

  Future<void> _stop(PushClient client) async {
    // a start given up after its channels were made has no token to drop,
    // and its channels still go
    final started = _running == true;
    _running = false;
    _cancel();
    _token = null;
    // the server lets go of the token while it is still the one it knows; a
    // sign-out has already done so, while its session could
    await Pushes.of(context).unregister();
    if (await client.stop() || started) await client.deleteChannels();
  }

  void _cancel() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _register() {
    if (!mounted) return;
    final (token, platform) = (_token, pushPlatform(Theme.of(context).platform));
    if (token == null || platform == null) return;
    Pushes.of(context).register(
      platform: platform,
      token: token,
      // the server places the person's evening by it, for the daily pushes
      utcOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
  }

  /// Back in front: what arrived in the background meanwhile is fetched,
  /// shown or not, whichever way the app was opened, and a phone that crossed
  /// a time zone tells the server its new evening.
  void _onResume() {
    if (_live != true) return;
    _register();
    _drain();
  }

  Future<void> _drain() async {
    final client = widget.client;
    if (client == null) return;
    for (final push in await client.takePending()) {
      if (!mounted) return;
      await _fetch(push);
    }
  }

  void _onTap() {
    final push = pushTaps.value;
    if (push == null || _live != true) return;
    pushTaps.value = null;
    _open(push);
  }

  /// A push with the app in front. iOS shows a visible one itself; Android
  /// leaves that to the app. Either way, what it names is fetched now, so a
  /// tap finds it there.
  Future<void> _arrived(Push push, {String? title}) async {
    if (title case final String title) await widget.client?.show(push, title: title);
    if (mounted) await _fetch(push);
  }

  /// Fetches what [push] names, and nothing else.
  Future<void> _fetch(Push push) async {
    switch (push.known) {
      case .programChanged || .programReceived:
        if (push.programId case final String programId) {
          final templates = Templates.of(context);
          final program = await Programs.of(context).pull(programId);
          if (program != null) await templates.pull(program.sessions);
        }
      case .invitationAccepted:
        // the new connection arrives on the next read of them
        await Coaching.of(context).load();
      // messages (#556) and device keys (#555) are not built yet: nothing on
      // the device holds a thread or a device list to refresh
      case .threadCleared || .devicesChanged:
      // nothing to fetch: the tap opens where the news is read
      case .coachingMessage || .workoutDigest || .commentCreated || null:
        break;
    }
  }

  /// A tap on a push: where its news is read. One with nowhere in this build
  /// opens the app where it was.
  Future<void> _open(Push push) async {
    final router = HeartRouter.of(context);
    final preferences = Preferences.of(context);
    final space = preferences.isOn(.coachPeople) && (Auth.of(context).user?.mayCoach ?? false);
    switch (push.known) {
      // a push about a client opens Coaching (the design's rule)
      case .invitationAccepted || .workoutDigest when space:
        router.goToCoachingClients();
      case .coachingMessage when space:
        router.goToCoachingMessages();
      case .programReceived || .programChanged when preferences.isOn(.programs):
        if (push.programId case final String programId) {
          // fetched first: a tap that launched the app arrives before the
          // program is anywhere on the device
          if (Programs.of(context).lookup(programId) == null) await _fetch(push);
          if (mounted && Programs.of(context).lookup(programId) != null) router.goToProgram(programId);
        }
      case .invitationAccepted || .workoutDigest || .coachingMessage || .programReceived || .programChanged:
      // nowhere to read these yet: comments have no screen in the app, and a
      // student's messages come with #556
      case .commentCreated || .threadCleared || .devicesChanged || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
