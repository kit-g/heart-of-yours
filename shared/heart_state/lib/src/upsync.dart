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
      final plan = await _plan(uid, ledger);
      if (plan.isEmpty) break;
      _total = _done + plan.length;
      notifyListeners();

      for (final step in plan) {
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
            _status = .failed;
            notifyListeners();
            return;
          }
        }
        _done++;
        notifyListeners();
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
  static bool _isRefusal(Object? error) {
    return switch (error) {
      {'code': 'id_taken'} => true,
      _ => GoalRejected.from(error) != null,
    };
  }

  /// Everything under [uid] the ledger does not yet answer for, in order.
  Future<List<_Step>> _plan(String uid, Map<UpsyncResource, Map<String, UpsyncOutcome>> ledger) async {
    bool pending(UpsyncResource resource, String id) => !(ledger[resource]?.containsKey(id) ?? false);

    final (_, catalog) = await _exercises.getExercises(userId: uid);
    final units = await _exercises.getExerciseUnits(uid);
    final folders = await _folders.getFolders(uid);
    final templates = await _templates.getTemplates(uid);
    final workouts = await _workouts.getWorkoutHistory(uid) ?? const <Workout>[];
    final goals = await _goals.unsyncedGoals(uid);

    return <_Step>[
      for (final exercise in catalog)
        if (exercise.isMine && pending(.exercise, exercise.id))
          (resource: .exercise, id: exercise.id, replay: () => _replayExercise(uid, exercise)),
      for (final MapEntry(key: exerciseId, value: unit) in units.entries)
        if (pending(.unit, exerciseId)) (resource: .unit, id: exerciseId, replay: () => _replayUnit(exerciseId, unit)),
      for (final folder in folders)
        if (folder.id case String id when pending(.folder, id))
          (resource: .folder, id: id, replay: () => _replayFolder(uid, folder)),
      for (final template in templates)
        // a draft the editor never finished is not a template the user has
        if (template.name != null && template.isNotEmpty && pending(.template, template.id))
          (resource: .template, id: template.id, replay: () => _replayTemplate(uid, template)),
      for (final workout in workouts)
        if (workout.isCompleted && !workout.synced && pending(.workout, workout.id))
          (resource: .workout, id: workout.id, replay: () => _replayWorkout(uid, workout)),
      for (final goal in goals)
        if (goal.id case String id when pending(.goal, id))
          (resource: .goal, id: id, replay: () => _replayGoal(uid, goal)),
    ];
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
