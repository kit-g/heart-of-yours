import 'package:flutter/material.dart';
import 'package:heart_models/heart_models.dart';
import 'package:provider/provider.dart';

import 'goals.dart';
import 'remote.dart';
import 'templates.dart';

/// The server's answer to one replayed create: the row as it now stands there,
/// and whether this call made it (`201`) or found it already there (`200`).
typedef Replayed<T> = ({T row, bool created});

/// The remote half of the replay — `Api` behind an adapter in the app, the way
/// `RemoteTemplateFilingService` is. One method per resource the replay
/// order names (heart-api#66); each throws the server's body whole on a
/// refusal, so [Upsync] can read the `code` off it.
abstract interface class UpsyncService {
  Future<Replayed<Exercise>> replayExercise(Exercise exercise);

  /// Always lands when the server is reachable: an upsert, local wins.
  Future<void> replayUnitPreference(String exerciseId, MeasurementUnit unit);

  Future<Replayed<TemplateFolder>> replayFolder(TemplateFolder folder);

  Future<Replayed<Template>> replayTemplate(Template template);

  Future<Replayed<Workout>> replayWorkout(Workout workout);

  Future<Replayed<Goal>> replayGoal(Goal goal);
}

/// The store's half: the uid move, the debt, the ledger, and the reference
/// rewrites a name-merge needs. `LocalDatabase` behind an adapter in the app,
/// for the same reason `LocalGoalService` is.
abstract interface class LocalUpsyncService {
  /// Moves every row under [from] onto [to] — the "existing account" case.
  Future<void> rekeyUser(String from, String to);

  /// Records that [userId] is owed a replay; idempotent.
  Future<void> owe(String userId);

  Future<bool> isOwed(String userId);

  /// Every step the server has already answered, by resource and by the id
  /// the row has locally after confirmation.
  Future<Map<UpsyncResource, Map<String, UpsyncOutcome>>> ledger(String userId);

  Future<void> record(String userId, UpsyncResource resource, String id, UpsyncOutcome outcome);

  /// The run is complete: the debt and the ledger go together.
  Future<void> settle(String userId);

  /// The server merged a replayed custom onto the account's own by that name:
  /// every reference to [from] becomes a reference to [to], and the row under
  /// [from] goes. The row under [to] is already stored.
  Future<void> mergeExercise(String userId, {required String from, required String to});

  /// The folder counterpart of [mergeExercise].
  Future<void> mergeFolder(String userId, {required String from, required String to});
}

/// The kinds of row the replay carries, in the order it carries them. Later
/// resources reference earlier ones, and a name-merge changes the id they
/// must reference — so the order is the contract, not a preference.
enum UpsyncResource { exercise, unit, folder, template, workout, goal }

/// What the server said about one step.
enum UpsyncOutcome {
  /// `201`: this replay made the row.
  created,

  /// `200`: the account already had it, by id or by name.
  existing,

  /// A refusal that repeating would only repeat — `id_taken`, the goal cap.
  /// Reported, recorded so it is not retried, and left alone locally.
  skipped,
}

enum UpsyncStatus {
  /// Nothing owed, or nothing to say any more.
  idle,
  running,

  /// Stopped at a step the server could not be reached for; retryable.
  failed,

  /// The last run completed this session; [Upsync.report] has the numbers.
  done,
}

/// The tallies the final line is made of.
typedef UpsyncReport = ({int uploaded, int existing, int skipped});

/// One step of the plan: which row, and how to replay it — answering with the
/// id the row has locally afterwards and what the server said.
typedef _Step = ({UpsyncResource resource, String id, Future<(String, UpsyncOutcome)> Function() replay});

/// Replays an anonymous session's store into the account it just became
/// (heart-of-yours#96).
///
/// Not a sync engine. The rows are the ones the offline paths already leave
/// behind — a finished workout with `synced = 0`, a template saved under its
/// client id, a custom exercise that never had a server to go to — and the
/// server makes every create safe to repeat (heart-api#66). What this adds is
/// the order those paths never had, a ledger so an interrupted run resumes
/// without posting a row twice, and a number the user can watch.
///
/// The remote leg is closed to everyone else for the length of the run — see
/// [RemoteAccess.replaying] — and opened when it completes.
class Upsync with ChangeNotifier implements SignOutStateSentry {
  final LocalUpsyncService _local;
  final UpsyncService _remote;
  final ExerciseService _exercises;
  final LocalTemplateFolderService _folders;
  final TemplateService _templates;
  final WorkoutService _workouts;
  final LocalGoalService _goals;
  final RemoteAccess _access;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  /// The run completed: the caller re-pulls what the server now holds.
  final void Function()? onComplete;

  new({
    required this._local,
    required this._remote,
    required this._exercises,
    required this._folders,
    required this._templates,
    required this._workouts,
    required this._goals,
    RemoteAccess? access,
    this.onError,
    this.onComplete,
  }) : _access = access ?? RemoteAccess();

  static Upsync of(BuildContext context) => Provider.of<Upsync>(context, listen: false);

  static Upsync watch(BuildContext context) => Provider.of<Upsync>(context, listen: true);

  UpsyncStatus _status = .idle;

  UpsyncStatus get status => _status;

  /// The uid the current or last run was for.
  String? userId;

  int _done = 0;

  int _total = 0;

  /// Steps answered so far this run, and the steps the run has found to do.
  /// [total] grows if a pass finds more; it never shrinks.
  int get done => _done;

  int get total => _total;

  UpsyncReport _report = (uploaded: 0, existing: 0, skipped: 0);

  UpsyncReport get report => _report;

  bool _reachedServer = false;

  /// Whether the run that stopped got an answer at all. Only meaningful while
  /// [status] is `failed`.
  ///
  /// The two are different things to be told. A phone with no signal is the
  /// user's to fix and "check your connection" is the right nudge; a server
  /// that answered and refused is not, and telling them to check a connection
  /// that is working sends them after a fault they do not have. The 500 that
  /// stopped a 358-row backup at row 26 read exactly that way
  /// (heart-of-yours#113).
  bool get reachedServer => _reachedServer;

  /// `Api` throws the decoded body when the server answered and the answer was
  /// an error; a transport failure arrives as a `SocketException`, a
  /// `ClientException` or a timeout. So a Map is the server's voice.
  static bool _isServerAnswer(Object? error) => error is Map;

  Future<void>? _running;

  /// The gate is left as it stands: a sign-out closes the leg through
  /// [RemoteAccess.account] regardless, and a uid *switch* — an anonymous
  /// session becoming an account, which clears state the same way — has just
  /// had [claim] hold it for the replay. [restore] settles it for whoever
  /// arrives next.
  @override
  void onSignOut() {
    // a run still going is the old account's; it checks at every step
    userId = null;
    _running = null;
    _status = .idle;
    _done = 0;
    _total = 0;
    _report = (uploaded: 0, existing: 0, skipped: 0);
    _reachedServer = false;
  }

  /// The moment a sign-in from an anonymous session lands: the store is owed a
  /// replay into [to], and the rows move first when the uid changed.
  ///
  /// Called by `Auth` before the new user is adopted, so nothing reads the
  /// store under the new uid until the rows are there.
  Future<void> claim({required String from, required String to}) async {
    _access.replaying = true;
    if (from != to) await _local.rekeyUser(from, to);
    await _local.owe(to);
  }

  /// A launch under [uid]: whether a replay is still owed, and the remote leg
  /// gated accordingly before anything else dials out.
  Future<bool> restore(String uid) async {
    final owed = await _local.isOwed(uid);
    _access.replaying = owed;
    return owed;
  }

  /// Nothing more to show for the last run.
  void dismiss() {
    if (_status != .done && _status != .failed) return;
    _status = .idle;
    notifyListeners();
  }

  /// Retries a failed run from where it stopped.
  Future<void> retry() {
    return switch (userId) {
      String uid => run(uid),
      null => Future.value(),
    };
  }

  /// Replays everything [uid]'s store holds that the server has not confirmed,
  /// in the contract's order, until nothing is left or the server cannot be
  /// reached. Shares one run between concurrent callers.
  Future<void> run(String uid) {
    return _running ??= _run(uid).whenComplete(() => _running = null);
  }

  Future<void> _run(String uid) async {
    userId = uid;
    if (!await _local.isOwed(uid)) {
      _access.replaying = false;
      return;
    }
    _access.replaying = true;
    _status = .running;
    notifyListeners();

    final ledger = await _local.ledger(uid);
    _report = _tally(ledger);
    _done = ledger.values.fold(0, (sum, rows) => sum + rows.length);
    _total = _done;
    notifyListeners();

    // Passes rather than one plan: a row written while the run was under way
    // — a workout finished with the remote leg closed — is picked up by the
    // next pass instead of waiting for the sweeps this run holds back.
    for (final _ in Iterable<int>.generate(_maxPasses)) {
      final pending = await _pending(uid, ledger);
      if (pending == 0) break;
      _total = _done + pending;
      notifyListeners();

      // One resource at a time, and each one planned only when its turn comes:
      // the steps before it may have moved the ids it references. See
      // [_planFor].
      for (final resource in UpsyncResource.values) {
        for (final step in await _planFor(resource, uid, ledger)) {
          // signed out mid-run: whatever comes back is the previous account's
          if (userId != uid) return;
          try {
            final (id, outcome) = await step.replay();
            await _local.record(uid, step.resource, id, outcome);
            ledger.putIfAbsent(step.resource, () => {})[id] = outcome;
            _report = _tally(ledger);
          } catch (error, stacktrace) {
            if (userId != uid) return;
            onError?.call(error, stacktrace: stacktrace);
            // the server considered this one and said no, and will again: the
            // rest of the run is not blocked on it
            if (_isRefusal(error)) {
              await _local.record(uid, step.resource, step.id, .skipped);
              ledger.putIfAbsent(step.resource, () => {})[step.id] = .skipped;
              _report = _tally(ledger);
            } else {
              _reachedServer = _isServerAnswer(error);
              _status = .failed;
              notifyListeners();
              return;
            }
          }
          _done++;
          notifyListeners();
        }
      }
    }

    if (userId != uid) return;
    await _local.settle(uid);
    _status = .done;
    _access.replaying = false;
    notifyListeners();
    onComplete?.call();
  }

  /// Guards the pass loop against a store that keeps producing rows.
  static const _maxPasses = 3;

  static UpsyncReport _tally(Map<UpsyncResource, Map<String, UpsyncOutcome>> ledger) {
    var uploaded = 0;
    var existing = 0;
    var skipped = 0;
    for (final outcome in ledger.values.expand((rows) => rows.values)) {
      switch (outcome) {
        case .created:
          uploaded++;
        case .existing:
          existing++;
        case .skipped:
          skipped++;
      }
    }
    return (uploaded: uploaded, existing: existing, skipped: skipped);
  }

  /// `id_taken` should never occur in a normal replay; the goal cap can.
  /// Either way the answer is final — see [GoalRejected] for why a named
  /// refusal is not an outage.
  /// Answers the server gives that repeating would only repeat.
  ///
  /// `id_taken` is the id collision. The rest are heart-api's mapping of a
  /// Postgres constraint onto a code (heart-api 593ea80): a row naming a
  /// reference the account does not have, or one that is already there under
  /// a unique key. Every one of them is about *this* row and no other, which
  /// is what makes skipping it and carrying on the right answer — before that
  /// mapping the same cases arrived as `500`s, and a single bad row stopped a
  /// backup of 358 with 332 never attempted (heart-of-yours#113).
  static const _refusals = {'id_taken', 'unknown_exercise', 'unknown_folder', 'invalid_reference', 'duplicate'};

  static bool _isRefusal(Object? error) {
    return switch (error) {
      {'code': String code} when _refusals.contains(code) => true,
      _ => GoalRejected.from(error) != null,
    };
  }

  /// What [uid]'s store owes for one [resource], read at the moment the
  /// resource's turn comes round.
  ///
  /// Late on purpose. The order in [UpsyncResource] exists because later
  /// resources reference earlier ones, and a name-merge *changes the id they
  /// must reference*: the server answers a replayed custom with its own id,
  /// [LocalDatabase.mergeExercise] rewrites every local reference to it, and
  /// the row under the old id goes. A plan built before the run holds the id
  /// the store has just stopped using — and sends it, to a server that has
  /// never had it.
  ///
  /// Found by seeding 358 rows against an account that already owned a custom
  /// by the same name: the merge landed, the units step posted the pre-merge
  /// id, and the whole backup stopped at row 26. Reading here rather than up
  /// front means every step sees the store as the steps before it left it.
  Future<List<_Step>> _planFor(
    UpsyncResource resource,
    String uid,
    Map<UpsyncResource, Map<String, UpsyncOutcome>> ledger,
  ) async {
    bool pending(String id) => !(ledger[resource]?.containsKey(id) ?? false);

    return switch (resource) {
      .exercise => [
        for (final exercise in (await _exercises.getExercises(userId: uid)).$2)
          if (exercise.isMine && pending(exercise.id))
            (resource: resource, id: exercise.id, replay: () => _replayExercise(uid, exercise)),
      ],
      .unit => [
        for (final MapEntry(key: exerciseId, value: unit) in (await _exercises.getExerciseUnits(uid)).entries)
          if (pending(exerciseId)) (resource: resource, id: exerciseId, replay: () => _replayUnit(exerciseId, unit)),
      ],
      .folder => [
        for (final folder in await _folders.getFolders(uid))
          if (folder.id case String id when pending(id))
            (resource: resource, id: id, replay: () => _replayFolder(uid, folder)),
      ],
      .template => [
        for (final template in await _templates.getTemplates(uid))
          // a draft the editor never finished is not a template the user has
          if (template.name != null && template.isNotEmpty && pending(template.id))
            (resource: resource, id: template.id, replay: () => _replayTemplate(uid, template)),
      ],
      .workout => [
        for (final workout in await _workouts.getWorkoutHistory(uid) ?? const <Workout>[])
          if (workout.isCompleted && !workout.synced && pending(workout.id))
            (resource: resource, id: workout.id, replay: () => _replayWorkout(uid, workout)),
      ],
      .goal => [
        for (final goal in await _goals.unsyncedGoals(uid))
          if (goal.id case String id when pending(id))
            (resource: resource, id: id, replay: () => _replayGoal(uid, goal)),
      ],
    };
  }

  /// How many steps the store owes across every resource — the number the row
  /// counts towards.
  ///
  /// Costs a second read of each source per pass, and buys a total that is
  /// settled before the first request rather than growing a resource at a
  /// time under the user's eyes. Local reads against a hundred rows, next to
  /// one HTTP request each.
  Future<int> _pending(String uid, Map<UpsyncResource, Map<String, UpsyncOutcome>> ledger) async {
    final plans = await Future.wait(UpsyncResource.values.map((each) => _planFor(each, uid, ledger)));
    return plans.fold<int>(0, (running, steps) => running + steps.length);
  }

  Future<(String, UpsyncOutcome)> _replayExercise(String uid, Exercise exercise) async {
    final (:row, :created) = await _remote.replayExercise(exercise);
    // the server's copy is the account's own row now, whatever `own` it
    // arrived with
    await _exercises.storeExercises([row.copyWith(isMine: true)], userId: uid);
    if (row.id != exercise.id) {
      await _local.mergeExercise(uid, from: exercise.id, to: row.id);
    }
    return (row.id, _outcome(created));
  }

  static UpsyncOutcome _outcome(bool created) {
    return switch (created) {
      true => .created,
      false => .existing,
    };
  }

  Future<(String, UpsyncOutcome)> _replayUnit(String exerciseId, MeasurementUnit unit) async {
    await _remote.replayUnitPreference(exerciseId, unit);
    return (exerciseId, UpsyncOutcome.created);
  }

  Future<(String, UpsyncOutcome)> _replayFolder(String uid, TemplateFolder folder) async {
    final (:row, :created) = await _remote.replayFolder(folder);
    await _folders.storeFolder(row, uid);
    if (row.id != folder.id) {
      await _local.mergeFolder(uid, from: folder.id!, to: row.id!);
    }
    return (row.id!, _outcome(created));
  }

  Future<(String, UpsyncOutcome)> _replayTemplate(String uid, Template template) async {
    final (:row, :created) = await _remote.replayTemplate(template);
    // a template minted before the cutover comes back under the server's id;
    // the row it was is dropped before the copy is stored, or both would show
    if (row.id != template.id) {
      await _templates.deleteTemplate(template.id);
    }
    await _templates.storeTemplates([row], userId: uid);
    return (row.id, _outcome(created));
  }

  Future<(String, UpsyncOutcome)> _replayWorkout(String uid, Workout workout) async {
    final (:row, :created) = await _remote.replayWorkout(workout);
    // marks the row synced; a shallow echo keeps the exercises the mirror holds
    await _workouts.storeWorkoutHistory([row], uid);
    return (row.id, _outcome(created));
  }

  Future<(String, UpsyncOutcome)> _replayGoal(String uid, Goal goal) async {
    final (:row, :created) = await _remote.replayGoal(goal);
    await _goals.reconcileGoalId(goal.id!, row, uid);
    return (row.id!, _outcome(created));
  }
}
