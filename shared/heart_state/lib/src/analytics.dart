import 'package:heart_models/heart_models.dart' show ApiTokenExpiry, ApiTokenPurpose, ProgramActionKind, SetType;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'features.dart';
import 'skips.dart';

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

  /// A new account, signed into directly from the anonymous session rather
  /// than linked onto it — Apple, whose token Firebase redeems only once. The
  /// uid changed, so `Upsync.claim` rekeyed the rows as for a [takeover], but
  /// the account is new and the server has none of them yet.
  moved('moved'),

  /// No anonymous session stood behind the sign-in — the web's gate, or an app
  /// that was signed out. Nothing to carry, which is a third answer and not a
  /// quiet [takeover].
  direct('direct');

  final String id;

  new(this.id);
}

/// Where a workout came from. The distinction the retention questions turn on:
/// a blank workout is someone who came to log, a template is someone with a
/// routine, and a sample is someone still finding out what the app is for.
enum WorkoutSource {
  blank('blank'),
  template('template'),
  sample('sample'),

  /// Started from a workout already in the history — "do this one again".
  repeat('repeat'),

  /// A program's session, started from its band or its page (#347).
  program('program');

  final String id;

  new(this.id);
}

/// How a template came to exist. `fromWorkout` is the interesting one: it is
/// the user turning something they already did into something they intend to
/// repeat, which is the habit forming in one action. `duplicate` is week 2
/// made out of week 1 (#262).
enum TemplateSource {
  editor('editor'),
  fromWorkout('from_workout'),
  duplicate('duplicate');

  final String id;

  new(this.id);
}

/// Where a program came from: a folder made into one (#348), or Heart's
/// library (#352).
enum ProgramSource {
  folder('folder'),
  library('library');

  final String id;

  new(this.id);
}

/// How far an exercise replaced on the sheet reaches (#354).
enum ReplaceScope {
  /// This workout alone.
  today('today'),

  /// Its program's sessions too, and the growth rule with them.
  program('program'),

  /// An open slot filled with another exercise of its pattern (#349).
  slot('slot');

  final String id;

  new(this.id);
}

/// What became of a program's calendar export (#391).
enum ProgramCalendarChange {
  added('added'),
  changed('changed'),
  removed('removed');

  final String id;

  new(this.id);
}

/// What a calendar event's link opened (#391).
enum ProgramLinkOutcome {
  started('started'),
  workout('workout'),
  skip('skip'),
  program('program');

  final String id;

  new(this.id);
}

/// Which part of a logged workout was changed after the fact.
enum WorkoutEditField {
  times('times'),
  sets('sets');

  final String id;

  new(this.id);
}

/// What opened the Features page at one feature (#239): a What's new note's
/// button, or a link from outside the app — a post, a video, the website.
enum FeatureLinkSource {
  whatsNew('whats_new'),
  link('link');

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

const _workoutStarted = 'workout_started';
const _workoutFinished = 'workout_finished';
const _workoutCancelled = 'workout_cancelled';
const _workoutEdited = 'workout_edited';
const _templateCreated = 'template_created';
const _templateFolderCreated = 'template_folder_created';
const _templateMoved = 'template_moved';
const _exerciseCreated = 'exercise_created';
const _exerciseHistoryMoved = 'exercise_history_moved';
const _exerciseReplaced = 'exercise_replaced';
const _programCreated = 'program_created';
const _programSteered = 'program_steered';
const _programDeleted = 'program_deleted';
const _programSkipped = 'program_skipped';
const _programUnskipped = 'program_unskipped';
const _daySkipped = 'day_skipped';
const _skipReasonGiven = 'skip_reason_given';
const _programGoalKept = 'program_goal_kept';
const _programAgain = 'program_again';
const _programCalendar = 'program_calendar';
const _programConstraint = 'program_constraint';
const _programLinkOpened = 'program_link_opened';
const _historyBackfilled = 'history_backfilled';

const _dataExported = 'data_exported';
const _dataImported = 'data_imported';
const _avatarUpdated = 'avatar_updated';
const _upgradeGateShown = 'upgrade_gate_shown';
const _notificationPermission = 'notification_permission_result';
const _watchAppSwitched = 'watch_app_switched';
const _setTypeChanged = 'set_type_changed';
const _featureLinked = 'feature_linked';
const _apiTokenCreated = 'api_token_created';
const _apiTokenRevoked = 'api_token_revoked';
const _signInConnected = 'sign_in_connected';
const _signInDisconnected = 'sign_in_disconnected';

const _source = 'source';
const _pinnedNotes = 'pinned_notes';
const _exerciseCount = 'exercise_count';
const _setCount = 'set_count';
const _durationMin = 'duration_min';
const _untickedSets = 'unticked_sets';
const _hadContent = 'had_content';
const _field = 'field';
const _pages = 'pages';
const _format = 'format';
const _unmatched = 'unmatched';
const _createdCustom = 'created_custom';
const _filed = 'filed';
const _granted = 'granted';
const _on = 'on';
const _fromWatch = 'from_watch';
const _setType = 'set_type';
const _feature = 'feature';
const _purpose = 'purpose';
const _expiry = 'expiry';
const _fromCustom = 'from_custom';
const _toCustom = 'to_custom';
const _workoutExercises = 'workout_exercises';
const _sessions = 'sessions';
const _action = 'action';
const _keptTemplates = 'kept_templates';
const _replaceScope = 'replace_scope';
const _suggested = 'suggested';
const _libraryProgram = 'library_program';

const _accountStateProperty = 'account_state';
const _authProviderProperty = 'auth_provider';
const _formFactorProperty = 'form_factor';
const _workoutsBucketProperty = 'workouts_bucket';
const _templatesBucketProperty = 'templates_bucket';

/// A boolean as GA4 can hold it.
///
/// `logEvent` takes `String` or `num` and asserts on anything else, so a bool
/// has to be encoded. It goes as a string rather than 1/0 because a registered
/// custom *dimension* is what these read as in reports — "of the sign-ups that
/// completed, what share carried the session's work" is a breakdown, not a sum.
String _flag(bool value) => value ? 'true' : 'false';

/// A count as a user property can hold it.
///
/// Raw counts make terrible user properties: every distinct value becomes its
/// own segment, and "users who have logged 37 workouts" is a cohort of one.
/// Bucketed, the same number answers the question anyone actually asks, which
/// is how far along someone is.
String _bucket(int count) {
  return switch (count) {
    <= 0 => '0',
    <= 3 => '1_3',
    <= 10 => '4_10',
    <= 30 => '11_30',
    _ => '31_plus',
  };
}

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

  new({required this._service, this.onError});

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

  void signupStarted({
    required AuthProvider provider,
    required bool fromAnonymous,
  }) {
    _log(_signupStarted, {
      _provider: provider.id,
      _fromAnonymous: _flag(fromAnonymous),
    });
  }

  /// An account that did not exist before now does — Firebase's own
  /// `isNewUser`, not a guess from which method was called.
  void signupCompleted({
    required AuthProvider provider,
    required AccountArrival arrival,
  }) {
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
  void loginCompleted({
    required AuthProvider provider,
    required AccountArrival arrival,
  }) {
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
  // Tier 2
  //
  // None of these carries a health value. A set count and an exercise count
  // are what the user typed into this app, never anything read back out of
  // the health store — see the note at the top of this class.

  void workoutStarted({
    required WorkoutSource source,
    required bool pinnedNotes,
  }) {
    _log(_workoutStarted, {
      _source: source.id,
      _pinnedNotes: _flag(pinnedNotes),
    });
  }

  /// [untickedSets] is the UX smell: sets that were typed into and never
  /// ticked. A number that stays high means the tick affordance is not
  /// landing, which no crash report would ever say.
  void workoutFinished({
    required WorkoutSource source,
    required int exerciseCount,
    required int setCount,
    required int durationMin,
    required int untickedSets,
  }) {
    _log(_workoutFinished, {
      _source: source.id,
      _exerciseCount: exerciseCount,
      _setCount: setCount,
      _durationMin: durationMin,
      _untickedSets: untickedSets,
    });
  }

  /// [hadContent] separates the two cancellations that look identical from
  /// here: opening a workout and thinking better of it, and abandoning one
  /// with sets already in it.
  void workoutCancelled({
    required bool hadContent,
    required int exerciseCount,
  }) {
    _log(_workoutCancelled, {
      _hadContent: _flag(hadContent),
      _exerciseCount: exerciseCount,
    });
  }

  void workoutEdited({required WorkoutEditField field}) {
    _log(_workoutEdited, {_field: field.id});
  }

  void templateCreated({required TemplateSource source}) {
    _log(_templateCreated, {_source: source.id});
  }

  void templateFolderCreated() => _log(_templateFolderCreated);

  /// [filed] is false when the template was moved *out* of a folder — the one
  /// case that says the filing was not wanted after all.
  void templateMoved({required bool filed}) {
    _log(_templateMoved, {_filed: _flag(filed)});
  }

  void exerciseCreated() => _log(_exerciseCreated);

  /// An exercise's history was moved onto another (#338). [fromCustom] and
  /// [toCustom] tell a custom folded into the library apart from a wrong
  /// import guess between two library exercises; [workoutExercises] is how
  /// many logged exercises the move re-keyed, the size of what was fixed.
  void exerciseHistoryMoved({required bool fromCustom, required bool toCustom, required int workoutExercises}) {
    _log(_exerciseHistoryMoved, {
      _fromCustom: _flag(fromCustom),
      _toCustom: _flag(toCustom),
      _workoutExercises: workoutExercises,
    });
  }

  /// An exercise on the sheet replaced before any of its sets was ticked
  /// (#354): how far the replacement reaches, and whether the pick was one the
  /// picker suggested. Never which exercises.
  void exerciseReplaced({required ReplaceScope scope, required bool suggested}) {
    _log(_exerciseReplaced, {_replaceScope: scope.id, _suggested: _flag(suggested)});
  }

  /// A program started (#348): where it came from and how many sessions it
  /// runs on. Never its name: from the library, [library] is which program
  /// by its key, an identifier like an exercise's.
  void programCreated({required ProgramSource source, required int sessions, String? library}) {
    _log(_programCreated, {_source: source.id, _sessions: sessions, _libraryProgram: ?library});
  }

  /// The user steered a program: repeat, pause, resume or replay. Repeat is
  /// the one to watch, an honest "not ready" the design wants to feel normal.
  void programSteered({required ProgramActionKind action}) {
    _log(_programSteered, {_action: action.value});
  }

  /// "Not today" (#312): a program session set aside, from its band on the
  /// Workout tab or from the program's page. Never which session.
  void programSkipped({required bool fromBand}) {
    _log(_programSkipped, {
      _source: switch (fromBand) {
        true => 'band',
        false => 'page',
      },
    });
  }

  /// A skip taken back with its Undo: how often "Not today" was a slip.
  void programUnskipped() => _log(_programUnskipped);

  /// "Not today" (#312) on a day no program asked for, from the Workout tab.
  void daySkipped() => _log(_daySkipped);

  /// The one-tap reason after a skip, a program's or a plain day's: which
  /// tag, never anything about the day.
  void skipReasonGiven({required SkipReason reason}) => _log(_skipReasonGiven, {_reason: reason.value});

  /// A goal a finished program implied, kept as one of the user's own (#353).
  /// Never which goal, nor its target.
  void programGoalKept() => _log(_programGoalKept);

  /// A finished program run again from week 1, heavier (#353).
  void programAgain() => _log(_programAgain);

  /// A program put in the device calendar, moved to another calendar or time,
  /// or taken out (#391). Never which calendar, nor a time.
  void programCalendar({required ProgramCalendarChange change}) => _log(_programCalendar, {_action: change.id});

  /// A program's constraint (#355) chosen or cleared. Never which: an area
  /// or a movement to go easy on is health-shaped, even as a content key.
  void programConstraint({required bool set}) {
    _log(_programConstraint, {
      _action: switch (set) {
        true => 'set',
        false => 'cleared',
      },
    });
  }

  /// A calendar event's link opened (#391), and what it opened: the session
  /// started, the workout or skip that did it, or the program.
  void programLinkOpened({required ProgramLinkOutcome outcome}) => _log(_programLinkOpened, {_action: outcome.id});

  /// A program deleted, and whether its sessions stayed as templates.
  void programDeleted({required bool keptTemplates}) {
    _log(_programDeleted, {_keptTemplates: _flag(keptTemplates)});
  }

  void historyBackfilled({required int pages}) {
    _log(_historyBackfilled, {_pages: pages});
  }

  void dataExported({required String format}) {
    _log(_dataExported, {_format: format});
  }

  /// [unmatched] is how many exercise names the preview could not resolve —
  /// how messy the incoming file was — and [createdCustom] how many of those
  /// the user agreed to create. The gap between them is the consent step
  /// being declined, which is the only part of this flow that can lose data.
  /// [source] is the app the export came from, as the import endpoint names
  /// it (`strong`, `hevy`, `heart`), and [format] the file's (`csv`, or `json`
  /// for Heart's own export, which the app reads itself, #329).
  void dataImported({
    required String source,
    required String format,
    required int unmatched,
    required int createdCustom,
  }) {
    _log(_dataImported, {_source: source, _format: format, _unmatched: unmatched, _createdCustom: createdCustom});
  }

  void avatarUpdated() => _log(_avatarUpdated);

  /// The forced-upgrade gate was put in front of someone. Nothing else in the
  /// app can strand a user this completely, and today its volume is invisible.
  void upgradeGateShown() => _log(_upgradeGateShown);

  void notificationPermissionResult({required bool granted}) {
    _log(_notificationPermission, {_granted: _flag(granted)});
  }

  /// The watch app (#175) was turned on or off. [fromWatch] is the opt-in's
  /// yes — Heart opened on the watch for the first time — as opposed to the
  /// Settings switch, so the reach of the feature and its reversals read apart.
  void watchAppSwitched({required bool on, required bool fromWatch}) {
    _log(_watchAppSwitched, {_on: _flag(on), _fromWatch: _flag(fromWatch)});
  }

  /// A set was marked as a warm-up, drop or failure set, or made plain again
  /// (#151) — the reach of set types, and which of them people use. [type] is
  /// the one picked, so `normal` is an un-marking.
  void setTypeChanged({required SetType type}) {
    _log(_setTypeChanged, {_setType: type.value});
  }

  /// The Features page opened at one [feature] (#239), from [source] — the
  /// question being whether a note or a tutorial gets anyone to the switch.
  /// What they did with it there is the feature's own answer, not this event.
  void featureLinked({
    required Feature feature,
    required FeatureLinkSource source,
  }) {
    _log(_featureLinked, {_feature: feature.value, _source: source.id});
  }

  /// A personal access token minted (#271): what the owner said it is for
  /// and how long it lives. Never its name, never its secret.
  void apiTokenCreated({
    required ApiTokenPurpose? purpose,
    required ApiTokenExpiry expiry,
  }) {
    _log(_apiTokenCreated, {
      _purpose: purpose?.name ?? 'unset',
      _expiry: expiry.name,
    });
  }

  void apiTokenRevoked() => _log(_apiTokenRevoked);

  /// A second sign-in linked onto the account from Account control (#323),
  /// or the one a refused sign-in left pending.
  void signInConnected({required AuthProvider provider}) {
    _log(_signInConnected, {_provider: provider.id});
  }

  void signInDisconnected({required AuthProvider provider}) {
    _log(_signInDisconnected, {_provider: provider.id});
  }

  void setAccountState(AccountState? state) => _property(_accountStateProperty, state?.id);

  void setWorkoutsBucket(int count) => _property(_workoutsBucketProperty, _bucket(count));

  void setTemplatesBucket(int count) => _property(_templatesBucketProperty, _bucket(count));

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
