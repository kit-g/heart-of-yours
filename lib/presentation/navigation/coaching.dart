import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart';

/// Keeps [Coaching] in step with the two coaching switches (#566): it reads
/// the connections when either is on, and again when the account changes,
/// and with both off it reads nothing, so nothing goes over the wire.
///
/// Coach people counts only for an account that may coach. That arrives with
/// the server's copy of the account, after sign-in has already settled the
/// router, so [onSpaceAvailable] is told the moment the space is there: a
/// launch that should open in it can then do so.
class CoachingPresenter extends StatefulWidget {
  final Widget child;
  final VoidCallback onSpaceAvailable;

  /// An invitation link opened before there was an account, to open again now
  /// that there is one (#553).
  final void Function(String token, String? fingerprint) onPendingInvitation;

  const new({super.key, required this.child, required this.onSpaceAvailable, required this.onPendingInvitation});

  @override
  State<CoachingPresenter> createState() => _CoachingPresenterState();
}

class _CoachingPresenterState extends State<CoachingPresenter> {
  Preferences? _preferences;
  Auth? _auth;

  /// Who was last read for, with which switches: null while nothing is on.
  (String, bool, bool)? _read;
  bool _space = false;

  /// Your coach as last seen: null before the first look, so launching is
  /// never mistaken for a flip of the switch.
  bool? _coached;

  /// A flip being followed, so another doesn't start over it.
  bool _following = false;

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
    super.dispose();
  }

  void _sync() {
    final (preferences, auth) = (_preferences, _auth);
    if (preferences == null || auth == null || !preferences.isInitialized) return;
    // a link kept while the person made an account: before the switches,
    // since following a first invitation is how Your coach gets turned on
    // an account, settled: before Firebase's first answer there is no user at
    // all, and that is not the same as one with an account
    if (preferences.pendingInvitation case (:final token, :final fingerprint)
        when auth.user != null && !auth.isAnonymous) {
      preferences.setPendingInvitation(null);
      widget.onPendingInvitation(token, fingerprint);
    }
    final (coachPeople, coached) = (preferences.isOn(.coachPeople), preferences.isOn(.yourCoach));
    final was = _coached;
    _coached = coached;
    final account = auth.user != null && !auth.isAnonymous && RemoteAccess.of(context).allowed;
    if (account && was != null && was != coached) {
      _followSwitch(on: coached);
    } else if (account && !coached && preferences.coachPauseOwed) {
      // off, and a pause that didn't go through last time
      _followSwitch(on: false);
    }
    // both off: coaching was never built, and nothing about the account is read
    if (!coachPeople && !coached) {
      _space = false;
      _read = null;
      return;
    }
    final user = auth.user;
    final space = coachPeople && (user?.mayCoach ?? false);

    if (space && !_space) widget.onSpaceAvailable();
    _space = space;

    final read = switch ((user?.id, space || coached)) {
      (final String id, true) => (id, space, coached),
      _ => null,
    };
    if (read == null || read == _read) {
      _read = read;
      return;
    }
    // no token yet: the read would be skipped, so it isn't counted as made.
    // Auth tells again once the server's copy of the account arrives
    if (!RemoteAccess.of(context).allowed) return;
    _read = read;
    Coaching.of(context).load();
    // the inbox too, for the unread counts on the ways in (#556): after the
    // frame, once the account's id has reached the messages
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Messages.of(context).load();
    });
  }

  /// Your coach off pauses every coach: the coach stops seeing new workouts
  /// and is told so, rather than a student believing coaching is off while
  /// data keeps flowing. On resumes them, which only the student can (#553).
  /// The switch is the only pause a student has, so on resumes every paused
  /// coach.
  ///
  /// The list is read fresh first: a flip that arrives from another device,
  /// by settings sync, finds that device's pauses already made. Each coach is
  /// tried on its own, and a pause that fails is owed until it goes through.
  Future<void> _followSwitch({required bool on}) async {
    if (_following) return;
    _following = true;
    final coaching = Coaching.of(context);
    final preferences = Preferences.of(context);
    var failed = false;
    try {
      await coaching.load();
      if (coaching.status != .loaded) {
        failed = true;
        return;
      }
      for (final coach in coaching.coaches.toList()) {
        try {
          switch ((on, coach.status)) {
            case (false, .active):
              await coaching.pause(coach);
            case (true, .paused):
              await coaching.resume(coach);
            default:
              break;
          }
        } catch (error, stacktrace) {
          failed = true;
          coaching.onError?.call(error, stacktrace: stacktrace);
        }
      }
    } finally {
      _following = false;
      // owed only while off: on, there is nothing left to pause
      await preferences.setCoachPauseOwed(owed: !on && failed);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
