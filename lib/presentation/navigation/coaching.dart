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
    if (preferences.pendingInvitation case (:final token, :final fingerprint) when !auth.isAnonymous) {
      preferences.setPendingInvitation(null);
      widget.onPendingInvitation(token, fingerprint);
    }
    final (coachPeople, coached) = (preferences.isOn(.coachPeople), preferences.isOn(.yourCoach));
    final was = _coached;
    _coached = coached;
    if (was != null && was != coached && !auth.isAnonymous) _followSwitch(on: coached);
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
  }

  /// Your coach off pauses every coach: the coach stops seeing new workouts
  /// and is told so, rather than a student believing coaching is off while
  /// data keeps flowing. On resumes them: only the student can (#553).
  Future<void> _followSwitch({required bool on}) async {
    final coaching = Coaching.of(context);
    try {
      // switched on, the list may never have been read
      if (on) await coaching.load();
      for (final coach in coaching.coaches.toList()) {
        switch ((on, coach.status)) {
          case (false, .active):
            await coaching.pause(coach);
          case (true, .paused):
            await coaching.resume(coach);
          default:
            break;
        }
      }
    } catch (error, stacktrace) {
      coaching.onError?.call(error, stacktrace: stacktrace);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
