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

  const new({super.key, required this.child, required this.onSpaceAvailable});

  @override
  State<CoachingPresenter> createState() => _CoachingPresenterState();
}

class _CoachingPresenterState extends State<CoachingPresenter> {
  Preferences? _preferences;
  Auth? _auth;

  /// Who was last read for, with which switches: null while nothing is on.
  (String, bool, bool)? _read;
  bool _space = false;

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
    final (coachPeople, coached) = (preferences.isOn(.coachPeople), preferences.isOn(.yourCoach));
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

  @override
  Widget build(BuildContext context) => widget.child;
}
