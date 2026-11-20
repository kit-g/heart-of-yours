import 'package:material_ui/material_ui.dart';

import 'alarms.dart';
import 'anomalies.dart';
import 'api_tokens.dart';
import 'auth.dart';
import 'backfill.dart';
import 'charts.dart';
import 'client_programs.dart';
import 'coach_library.dart';
import 'coach_notes.dart';
import 'coaching.dart';
import 'device_keys.dart';
import 'exercises.dart';
import 'go_easy.dart';
import 'goals.dart';
import 'health.dart';
import 'history_filter.dart';
import 'messages.dart';
import 'preferences.dart';
import 'previous.dart';
import 'programs.dart';
import 'pushes.dart';
import 'roster.dart';
import 'stats.dart';
import 'templates.dart';
import 'timers.dart';
import 'upsync.dart';
import 'workouts.dart';

/// Signs out and forgets everything the session held.
///
/// This device stops getting the account's pushes first (heart-api#415): the
/// removal sets off before anything is forgotten and is waited for before the
/// session ends, the last moment the request can say whose pushes they are.
/// One that cannot be made does not hold the sign-out up.
Future<void> clearState(BuildContext context) async {
  final session = Auth.of(context);
  final unregistering = Pushes.of(context).unregister();
  clearUserState(context);
  await unregistering;
  await session.onSignOut();
}

/// Erases everything an anonymous session holds on the device and signs it
/// out, so the app starts over under a fresh uid.
///
/// The memory is cleared first: nothing a notifier still holds may be written
/// back once the rows are gone. Then the uid's rows and preferences, then the
/// session — which on mobile is replaced by a new anonymous one at once (see
/// [Auth.ensureSession]). Nothing happens for a session with an account: that
/// one has account deletion, and [Auth.eraseSession] refuses it.
Future<void> eraseState(BuildContext context) async {
  final auth = Auth.of(context);
  if (!auth.isAnonymous) return;
  if (auth.user?.id case String uid) {
    final preferences = Preferences.of(context);
    clearUserState(context);
    await preferences.forgetUser(uid);
    await auth.eraseSession();
  }
}

/// Forgets everything the session held, keeping the session itself.
///
/// What a uid switch needs: an account signed into from an anonymous session
/// replaces it under the same running app, and nothing the anonymous uid held
/// in memory — its workouts, templates, catalog units — may bleed into the
/// account's lists or, worse, get pushed to its server as pending writes.
///
/// Memory only: the rows stay in the store under the uid they belong to.
void clearUserState(BuildContext context) {
  for (final (:clear, key: _) in _sessionState(context)) {
    clear?.call();
  }
}

/// Keys every state class that reads by uid on [userId], the session's — or
/// on none.
void keyUserState(BuildContext context, String? userId) {
  for (final (clear: _, :key) in _sessionState(context)) {
    key?.call(userId);
  }
}

/// The uid the session's state is keyed on: null before the first session,
/// and again once [clearUserState] has forgotten it. Read back from the state
/// itself, so the app's own sign-outs, which clear before they sign out, leave
/// nothing for the user change that follows to clear again.
String? keyedUserId(BuildContext context) => Workouts.of(context).userId;

/// Every state class a session's data lives in, each once: how it forgets the
/// session, and, for one that reads by uid, how it is keyed on one. One list,
/// so a class added for the one cannot be missed by the other.
List<({void Function()? clear, void Function(String?)? key})> _sessionState(BuildContext context) {
  return [
    (clear: Exercises.of(context).onSignOut, key: (id) => Exercises.of(context).userId = id),
    (clear: Charts.of(context).onSignOut, key: (id) => Charts.of(context).userId = id),
    (clear: Goals.of(context).onSignOut, key: (id) => Goals.of(context).userId = id),
    (clear: Anomalies.of(context).onSignOut, key: (id) => Anomalies.of(context).userId = id),
    (clear: Health.of(context).onSignOut, key: (id) => Health.of(context).userId = id),
    (clear: PreviousExercises.of(context).onSignOut, key: (id) => PreviousExercises.of(context).userId = id),
    (clear: Stats.of(context).onSignOut, key: (id) => Stats.of(context).userId = id),
    (clear: Templates.of(context).onSignOut, key: (id) => Templates.of(context).userId = id),
    (clear: Programs.of(context).onSignOut, key: (id) => Programs.of(context).userId = id),
    // forgets what it held whenever it is keyed on another uid
    (clear: null, key: (id) => GoEasy.of(context).userId = id),
    (clear: Timers.of(context).onSignOut, key: (id) => Timers.of(context).userId = id),
    (clear: Workouts.of(context).onSignOut, key: (id) => Workouts.of(context).userId = id),
    (clear: Messages.of(context).onSignOut, key: (id) => Messages.of(context).userId = id),
    (clear: CoachNotes.of(context).onSignOut, key: (id) => CoachNotes.of(context).userId = id),
    (clear: Alarms.of(context).onSignOut, key: null),
    (clear: ApiTokens.of(context).onSignOut, key: null),
    (clear: Backfill.of(context).onSignOut, key: null),
    (clear: CoachLibrary.of(context).onSignOut, key: null),
    (clear: ClientPrograms.of(context).onSignOut, key: null),
    (clear: Coaching.of(context).onSignOut, key: null),
    (clear: DeviceKeys.of(context).onSignOut, key: null),
    (clear: HistoryFilter.of(context).onSignOut, key: null),
    (clear: Pushes.of(context).onSignOut, key: null),
    (clear: Roster.of(context).onSignOut, key: null),
    (clear: Upsync.of(context).onSignOut, key: null),
  ];
}
