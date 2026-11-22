import 'dart:async';

import 'package:heart/core/env/notifications.dart';
import 'package:heart/core/env/push.dart';
import 'package:heart/presentation/navigation/router/router.dart';
import 'package:heart/presentation/routes/messages/messages.dart' show threadName;
import 'package:heart/presentation/widgets/in_view.dart';
import 'package:heart/presentation/widgets/push_note.dart';
import 'package:heart_models/heart_models.dart' show Program, Thread;
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
  return coachingRuns(preferences, auth);
}

/// The rule behind [pushesOn], which device keys (#555) follow too: both run
/// for coaching and for nothing else.
bool coachingRuns(Preferences preferences, Auth auth) {
  final account = auth.user != null && !auth.isAnonymous;
  return account && (coachingSpaceRuns(preferences, auth) || preferences.isOn(.yourCoach));
}

/// Whether the Coaching space is there at all: Coach people is on, for an
/// account that may coach. The one rule the space's ways in, the presenter
/// and [coachingRuns] all read.
bool coachingSpaceRuns(Preferences preferences, Auth auth) {
  return preferences.isOn(.coachPeople) && (auth.user?.mayCoach ?? false);
}

/// Whether [coachingRuns]'s answer can be acted on. A coach with only Coach
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

  /// What a push with the app in front shows (#724).
  final _note = ValueNotifier<PushNote?>(null);
  Timer? _noteTimer;

  /// Counts arrivals, in the order they came: a note is never replaced by
  /// one for an older push whose fetch took longer.
  var _arrivals = 0;

  /// The arrival the latest note was for.
  var _latest = 0;

  /// Counts starts and stops: a push whose fetch outlived the client that
  /// heard it, a sign-out's say, shows nothing.
  var _session = 0;

  /// A push that came while the app was in front but not active (iOS's
  /// Control Centre over it), which the system was told not to show: the
  /// note waits for the app's return.
  ({int order, Push push, String? title})? _held;

  /// How long the note stays: a line or two, read at a glance.
  static const _noteFor = Duration(seconds: 5);

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
    _noteTimer?.cancel();
    _note.dispose();
    super.dispose();
  }

  void _sync() {
    final (preferences, auth, client) = (_preferences, _auth, widget.client);
    if (client == null || preferences == null || auth == null || !preferences.isInitialized) return;
    // before Firebase's first answer there is no user at all, which is not
    // the same as a session without an account: nothing is decided yet
    if (auth.user == null && _live == null) return;
    if (!_pushesDecided(preferences, auth)) return;
    final live = coachingRuns(preferences, auth);
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
    _session++;
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
    _session++;
    _cancel();
    _held = null;
    _withdraw();
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
    if (_held case (:final order, :final push, :final title)) {
      _held = null;
      _offer(order, push, title: title);
    }
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

  /// A push with the app in front (#724): what it names is fetched now, so a
  /// tap finds it there, and then it shows as the app's own note, in the
  /// app's words, where the system would have drawn a banner. The system
  /// draws none: iOS is told so in [PushClient.start], and Android never does.
  ///
  /// In front is not always active: Android's shade pulled over the app, or
  /// a split screen's other half in use, still counts, and so does iOS's
  /// Control Centre. A note there would go unseen, so Android posts the
  /// system's notification instead, and iOS, which cannot, keeps the note
  /// for the app's return.
  Future<void> _arrived(Push push, {String? title}) async {
    final (order, session) = (++_arrivals, _session);
    try {
      await _fetch(push);
    } finally {
      if (mounted && session == _session && _running == true) {
        switch (WidgetsBinding.instance.lifecycleState) {
          case .resumed || null:
            await _offer(order, push, title: title);
          case .inactive || .hidden || .paused || .detached:
            final shown = switch ((title, widget.client)) {
              (final String title, final PushClient client) => await client.show(push, title: title),
              _ => false,
            };
            if (!shown && mounted && session == _session) _held = (order: order, push: push, title: title);
        }
      }
    }
  }

  Future<void> _offer(int order, Push push, {String? title}) async {
    // a newer push's note stands
    if (order < _latest) return;
    // what the person turned off for the app, or for this kind, stays off
    if (!(await widget.client?.allows(push) ?? true) || !mounted) return;
    if (order < _latest) return;
    final said = _said(push, title: title);
    if (said == null) return;
    final (icon, text, line) = said;
    _latest = order;
    _note.value = (serial: order, push: push, icon: icon, title: text, line: line);
    _noteTimer?.cancel();
    // a screen reader's person reaches it in their own time, and puts it
    // away themselves, as a snack bar with an action waits for them
    _noteTimer = switch (MediaQuery.accessibleNavigationOf(context)) {
      true => null,
      false => Timer(_noteFor, _withdraw),
    };
  }

  /// What the note says about [push]: its glyph, its words and a line under
  /// them. The app's words wherever it can name what arrived, the server's
  /// [title] where it can't, and nothing for a push that shows nothing (one
  /// without a title, one silent by its topic), for what is already on
  /// screen, or for a program the switches hide.
  (IconData, String, String?)? _said(Push push, {String? title}) {
    final l = L.of(context);
    (IconData, String, String?)? titled(IconData icon) {
      return switch (title) {
        final String title => (icon, title, null),
        null => null,
      };
    }

    switch (push.known) {
      case .coachingMessage:
        final thread = switch (push.threadId) {
          final String id => Messages.of(context).lookup(id),
          null => null,
        };
        // the conversation open in front of them shows the message itself
        if (title == null) return null;
        if (thread?.connectionId case final String id when inView((.thread, id))) return null;
        return switch (thread) {
          final Thread thread => (Icons.forum_outlined, l.pushNoteMessage(threadName(context, thread)), null),
          null => titled(Icons.forum_outlined),
        };
      case .programReceived || .programChanged:
        final preferences = Preferences.of(context);
        final id = push.programId;
        if (id == null || inView((.program, id))) return null;
        final program = Programs.of(context).lookup(id);
        // a program the switches hide is as if never sent; one that didn't
        // arrive is judged by whether any program could show
        final shown = switch (program) {
          final Program program => preferences.programShown(program),
          null => preferences.programsReach,
        };
        if (!shown) return null;
        return switch ((push.known, program)) {
          (.programReceived, final Program program) when title != null => (
            Icons.event_repeat_rounded,
            l.pushNoteProgramReceived(_coachOf(program)),
            program.name,
          ),
          (.programReceived, _) => titled(Icons.event_repeat_rounded),
          // silent by the server's word, since it says nothing: the app can,
          // for a student whose coach changed what they follow
          (_, final Program program) when _fromCoach(program) => (
            Icons.edit_note_rounded,
            l.pushNoteProgramChanged(_coachOf(program), program.name),
            null,
          ),
          _ => null,
        };
      case .invitationAccepted:
        // it carries no id: who accepted is in the server's words alone
        return titled(Icons.person_add_alt_rounded);
      case .workoutDigest:
        return titled(Icons.fitness_center_rounded);
      case .commentCreated:
        return titled(Icons.chat_bubble_outline_rounded);
      case null:
        // one this build has never heard of: the server words it
        return titled(Icons.notifications_none_rounded);
      case .threadCleared || .devicesChanged || .queueWaiting:
        return null;
    }
  }

  /// Whether [program] is a coach's copy of this person's, under Your coach:
  /// a change to it came from the coach. A coach's own device hears of a
  /// student's change too, with no name to put to it.
  bool _fromCoach(Program program) {
    final coach = program.coachId;
    return coach != null && coach != Auth.of(context).user?.id && Preferences.of(context).isOn(.yourCoach);
  }

  String _coachOf(Program program) {
    return switch (program.coachName?.trim()) {
      final String name when name.isNotEmpty => name,
      _ => L.of(context).yourCoach,
    };
  }

  void _withdraw() {
    _noteTimer?.cancel();
    _noteTimer = null;
    _note.value = null;
  }

  /// [note] put away: the one showing, not whichever came after it.
  void _dismiss(PushNote note) {
    if (_note.value?.serial == note.serial) _withdraw();
  }

  void _tapNote(PushNote note) {
    _dismiss(note);
    _open(note.push);
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
      case .devicesChanged:
        // someone this device shares keys with added, removed or vouched for
        // one (#555)
        if (push.userId case final String userId) await DeviceKeys.of(context).devicesChanged(userId);
      case .queueWaiting:
        // every app of the account's hears it: the one whose device it names reads
        if (push.deviceId case final String deviceId) await DeviceKeys.of(context).queueWaiting(deviceId);
      case .coachingMessage:
        // the inbox again, and the thread when it is open (#556)
        if (push.threadId case final String threadId) await Messages.of(context).arrived(threadId);
      case .threadCleared:
        if (push.threadId case final String threadId) await Messages.of(context).cleared(threadId);
      // nothing to fetch: the tap opens where the news is read
      case .workoutDigest || .commentCreated || null:
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
      case .coachingMessage:
        // the thread itself, wherever it lives: a coach's in Coaching, a
        // student's over the app (#556)
        final messages = Messages.of(context);
        if (push.threadId case final String threadId) {
          if (messages.lookup(threadId) == null) await messages.load();
          final connectionId = messages.lookup(threadId)?.connectionId;
          if (!mounted) return;
          switch ((connectionId, space && _coaches(connectionId))) {
            case (final String id, true):
              router.goToCoachingThread(id);
            case (final String id, false):
              router.openThread(id);
            case (null, true):
              router.goToCoachingMessages();
            case (null, false):
              break;
          }
        }
      // a coach's program is shown under Your coach alone (#593)
      case .programReceived || .programChanged when preferences.programsReach:
        if (push.programId case final String programId) {
          // fetched first: a tap that launched the app arrives before the
          // program is anywhere on the device
          if (Programs.of(context).lookup(programId) == null) await _fetch(push);
          if (!mounted) return;
          if (Programs.of(context).lookup(programId) case final Program program
              when preferences.programShown(program)) {
            router.goToProgram(programId);
          }
        }
      case .invitationAccepted || .workoutDigest || .programReceived || .programChanged:
      // nowhere to read these yet: comments have no screen in the app
      case .commentCreated || .threadCleared || .devicesChanged || .queueWaiting || null:
        break;
    }
  }

  /// Whether [connectionId] is one where this person coaches: its thread
  /// lives in Coaching.
  bool _coaches(String? connectionId) {
    return Coaching.of(context).clients.any((each) => each.connectionId == connectionId);
  }

  @override
  Widget build(BuildContext context) {
    return PushNoteHost(note: _note, onTap: _tapNote, onDismiss: _dismiss, child: widget.child);
  }
}
