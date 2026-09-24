import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Where an [Analytics] writes.
///
/// Implemented in the app over `firebase_analytics`; `heart_state` never sees
/// the SDK. A run that must not report — debug, the driver, Test Lab — swaps
/// the transport for one that drops everything, so no call site grows a
/// condition and no test needs the plugin.
abstract interface class AnalyticsService {
  /// [parameters] values are `String` or `num` only. The SDK asserts on
  /// anything else, so [Analytics] encodes before it gets here.
  Future<void> logEvent(String name, Map<String, Object> parameters);

  Future<void> setUserProperty(String name, String? value);
}

/// Which sign-in an event is about. Firebase states these as `google.com` and
/// friends; the short form is what the reports read better as, and it is an
/// identifier either way.
enum AuthProvider {
  google('google'),
  apple('apple'),
  password('password');

  final String id;

  new(this.id);
}

/// How an account arrived on a session.
///
/// The two anonymous paths are not the same operation and do not cost the
/// same, which is the whole reason this is a dimension: a [linked] account
/// keeps the uid it already had, while a [takeover] rekeys every local row
/// onto another uid and replays the lot into an account that may already hold
/// most of it — the "3 uploaded, 23 already there" `Upsync.adopt` documents.
enum AccountArrival {
  /// The credential was linked onto the anonymous session: the uid survived,
  /// the store was already the account's, and only a replay is owed.
  linked('linked'),

  /// The credential already had an account, so the session signed into that
  /// instead. `Upsync.claim` rekeys the session's rows onto it first — nothing
  /// is lost, but it is the slow path and the one that meets the server's own
  /// copy of the same rows.
  takeover('takeover'),

  /// No anonymous session stood behind the sign-in — the web's gate, or an app
  /// that was signed out. Nothing to carry, which is a third answer and not a
  /// quiet [takeover].
  direct('direct');

  final String id;

  new(this.id);
}

/// The rung of the ladder a session is on — the property every report segments
/// by. Gains `premium` and `coach` when those ship.
enum AccountState {
  anonymous('anonymous'),
  account('account');

  final String id;

  new(this.id);
}

/// Which real estate the app is running on. GA4 reports a device category of
/// its own, but the phone/tablet split this app acts on is `_isPhone`'s, and
/// only the app can state it.
enum FormFactor {
  phone('phone'),
  tablet('tablet');

  final String id;

  new(this.id);
}

// Event names. GA4 allows 40 characters of letters, digits and underscores, and
// reserves the `firebase_`, `google_` and `ga_` prefixes. `screen_view` is not
// here on purpose: `FirebaseAnalyticsObserver` already sends it.
const _anonSessionMinted = 'anon_session_minted';
const _signupPromptShown = 'signup_prompt_shown';
const _signupStarted = 'signup_started';
const _signupCompleted = 'signup_completed';
const _signupFailed = 'signup_failed';
const _loginCompleted = 'login_completed';
const _replayFinished = 'upsync_replay_finished';
const _deletionScheduled = 'deletion_scheduled';
const _deletionCancelled = 'deletion_cancelled';

// Parameter keys, and the user property names — a separate namespace, capped at
// 24 characters against a parameter's 40.
const _provider = 'provider';
const _fromAnonymous = 'from_anonymous';
const _arrival = 'arrival';
const _reason = 'reason';
const _placement = 'placement';
const _rows = 'rows';
const _uploaded = 'uploaded';
const _existing = 'existing';
const _skipped = 'skipped';
const _durationMs = 'duration_ms';
const _ok = 'ok';

const _accountStateProperty = 'account_state';
const _authProviderProperty = 'auth_provider';
const _formFactorProperty = 'form_factor';

/// A boolean as GA4 can hold it.
///
/// `logEvent` takes `String` or `num` and asserts on anything else, so a bool
/// has to be encoded. It goes as a string rather than 1/0 because a registered
/// custom *dimension* is what these read as in reports — "of the sign-ups that
/// completed, what share carried the session's work" is a breakdown, not a sum.
String _flag(bool value) => value ? 'true' : 'false';

/// The app's analytics vocabulary: every event it sends, named once.
///
/// Call sites say what happened in domain terms and this decides the wire
/// names, the encoding and the parameter keys — which is what keeps the
/// taxonomy in `docs/2026-09-24.analytics.md` honest, and what makes a rename
/// one edit rather than a grep.
///
/// Nothing here is awaited by callers and nothing here throws: reporting is
/// never allowed to slow down, or break, the thing it reports on. A transport
/// failure goes to [onError] and no further.
///
/// **Health data never reaches this class.** Nothing derived from a
/// `HealthMetric` — a weight, a heart rate, a body-fat percentage — is a legal
/// argument to any method, as value, bucket or flag. See
/// `docs/2026-09-05.health-data.md`.
class Analytics {
  final AnalyticsService _service;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required this._service,
    this.onError,
  });

  void _log(String name, [Map<String, Object> parameters = const {}]) {
    _service.logEvent(name, parameters).catchError(_swallow);
  }

  void _property(String name, String? value) {
    _service.setUserProperty(name, value).catchError(_swallow);
  }

  void _swallow(Object error, StackTrace stacktrace) {
    onError?.call(error, stacktrace: stacktrace);
  }

  /// A uid with no account behind it now exists — the denominator of the
  /// ladder funnel, and the only event an anonymous session reports before it
  /// does anything.
  void anonymousSessionMinted() => _log(_anonSessionMinted);

  /// The app offered an account. [placement] names the surface that offered it,
  /// so the ones that convert can be told from the ones that only nag.
  void signupPromptShown({required String placement}) {
    _log(_signupPromptShown, {_placement: placement});
  }

  void signupStarted({required AuthProvider provider, required bool fromAnonymous}) {
    _log(_signupStarted, {_provider: provider.id, _fromAnonymous: _flag(fromAnonymous)});
  }

  /// An account that did not exist before now does — Firebase's own
  /// `isNewUser`, not a guess from which method was called.
  void signupCompleted({required AuthProvider provider, required AccountArrival arrival}) {
    _log(_signupCompleted, {_provider: provider.id, _arrival: arrival.id});
  }

  /// [reason] is an error *code* — `credential-already-in-use`, not the message
  /// it came with. A message is copy, and may carry an address.
  void signupFailed({required AuthProvider provider, required String reason}) {
    _log(_signupFailed, {_provider: provider.id, _reason: reason});
  }

  /// A sign-in to an account that already existed. Carries [arrival] for the
  /// same reason a sign-up does: this is where [AccountArrival.takeover] is
  /// common, and where the replay it triggers is worth watching.
  void loginCompleted({required AuthProvider provider, required AccountArrival arrival}) {
    _log(_loginCompleted, {_provider: provider.id, _arrival: arrival.id});
  }

  /// The store an anonymous session built has finished replaying into the
  /// account that took it over. Every remote leg is held shut until this lands
  /// (see `RemoteAccess.replaying`), so a slow or failing replay is a new
  /// account that feels broken on its first day.
  void replayFinished({
    required int rows,
    required int uploaded,
    required int existing,
    required int skipped,
    required int durationMs,
    required bool ok,
  }) {
    _log(_replayFinished, {
      _rows: rows,
      _uploaded: uploaded,
      _existing: existing,
      _skipped: skipped,
      _durationMs: durationMs,
      _ok: _flag(ok),
    });
  }

  void accountDeletionScheduled() => _log(_deletionScheduled);

  void accountDeletionCancelled() => _log(_deletionCancelled);

  /// Null where there is no session at all — the web's gate, or the moment
  /// after a sign-out. That is neither rung, and saying so beats leaving the
  /// last session's answer standing against the next one's events.
  void setAccountState(AccountState? state) => _property(_accountStateProperty, state?.id);

  /// Null where there is no account behind the session, which is a different
  /// statement from any of the providers and is worth segmenting on.
  void setAuthProvider(AuthProvider? provider) {
    _property(_authProviderProperty, provider?.id);
  }

  void setFormFactor(FormFactor factor) => _property(_formFactorProperty, factor.id);

  static Analytics of(BuildContext context) {
    return Provider.of<Analytics>(context, listen: false);
  }
}
