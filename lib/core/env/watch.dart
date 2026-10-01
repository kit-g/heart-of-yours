import 'dart:async';

import 'package:flutter/services.dart';
import 'package:heart/core/env/ongoing_workout.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Watch');

/// What the watch app shows (#182). The phone is the only writer: the watch
/// holds nothing but the last of these it was sent, so every state is complete
/// on its own — never a delta against one the watch may not have.
///
/// Every string is finished copy. The watch app has no localisations of its
/// own; whatever it says, the phone said first.
sealed class WatchState {
  const new();

  Map<String, Object?> toMap();
}

/// The set up next, as the watch edits and ticks it (#183).
///
/// Values are in the unit the phone shows this exercise in, and the phone
/// converts back what the watch returns: the watch does no unit arithmetic,
/// and never learns that weights are stored in kilograms.
typedef WatchSet = ({
  /// The workout exercise and set a command about it must name.
  String exerciseId,
  String setId,

  /// Null when the set takes no weight (reps only), and [reps] null when it
  /// takes neither — a cardio or timed set, ticked as prescribed.
  double? weight,
  int? reps,

  /// The weight's unit, as copy ("kg"), and one Digital Crown detent of it.
  String? unit,
  double step,

  /// The same set last time, as finished copy; null when there was none.
  String? previous,

  /// Where it sits in its exercise, as copy: "Set 2 of 3".
  String position,
});

/// One exercise of the workout as the watch lists it (#183), for going back to
/// a set already done: its sets, their values in the unit it is shown in, and
/// what the set measures — so the editor knows which values it may offer.
typedef WatchExercise = ({
  String id,
  String name,
  String? unit,
  double step,

  /// Whether its sets take a weight, and whether they take a count.
  bool weighted,
  bool counted,

  /// Its rest timer in seconds, null when it has none — so a watch with the
  /// phone out of reach (#206) can start the rest a tick starts.
  int? rest,
  List<WatchSetRow> sets,
});

/// One set in [WatchExercise.sets]: its identity, its values and whether it is
/// ticked. Its number is its place in the list.
///
/// With the copy the watch shows once it is the set up next — so a watch with
/// the phone out of reach (#206) can move on to it without asking: where it
/// sits ([WatchSet.position]), last time ([WatchSet.previous]), and the lock
/// screen's "Next:" line for the complication.
typedef WatchSetRow = ({
  String id,
  double? weight,
  int? reps,
  bool done,
  String position,
  String? previous,
  String next,
});

/// The watch's controls, as copy — labels and what it says when it cannot act.
typedef WatchControls = ({
  String done,
  String skip,
  String add,
  String subtract,
  String reps,
  String unreachable,

  /// Labels for what the watch's own workout session measures (#184). Only
  /// the words cross over: the readings never leave the watch.
  String heartRate,
  String bpm,
  String energy,
  String kcal,

  /// Finishing from the wrist, and its one confirmation — the phone's own
  /// words for the same question.
  String finish,
  String finishTitle,
  String finishConfirm,
  String finishCancel,

  /// Going back to a set (#183): saving new values for a ticked one, and
  /// taking the tick away.
  String save,
  String notDone,

  /// What the watch says for itself while the phone is out of reach (#206):
  /// the rest it starts, the "Next:" line once every set is ticked, and the
  /// idle line after it finishes the workout.
  String restLabel,
  String restOver,
  String allDone,
  String idle,
});

/// A workout is running: the same summary the lock screen shows, plus the set
/// up next and the copy for the controls that act on it.
final class WatchWorkout extends WatchState {
  final OngoingWorkout workout;
  final WatchSet? set;
  final WatchControls? controls;

  /// What the session is, as `WorkoutActivity` names it — what the watch's
  /// workout session measures it as, and labels it with in Health (#184).
  final String? activity;

  /// The whole workout, for the watch's second page (#183).
  final List<WatchExercise> exercises;

  const new(this.workout, {this.set, this.controls, this.activity, this.exercises = const []});

  @override
  Map<String, Object?> toMap() {
    final OngoingWorkout(:workoutId, :startedAt, :title, :exercise, :next, :rest, :preset) = workout;
    return {
      'activity': ?activity,
      if (set case WatchSet set) ...{
        'exerciseId': set.exerciseId,
        'setId': set.setId,
        'weight': ?set.weight,
        'reps': ?set.reps,
        'unit': ?set.unit,
        'step': set.step,
        'previous': ?set.previous,
        'position': set.position,
      },
      'exercises': [
        for (final exercise in exercises)
          {
            'id': exercise.id,
            'name': exercise.name,
            'unit': ?exercise.unit,
            'step': exercise.step,
            'weighted': exercise.weighted,
            'counted': exercise.counted,
            'rest': ?exercise.rest,
            'sets': [
              for (final row in exercise.sets)
                {
                  'id': row.id,
                  'weight': ?row.weight,
                  'reps': ?row.reps,
                  'done': row.done,
                  'position': row.position,
                  'previous': ?row.previous,
                  'next': row.next,
                },
            ],
          },
      ],
      if (controls case WatchControls controls) ...{
        'done': controls.done,
        'skip': controls.skip,
        'add': controls.add,
        'subtract': controls.subtract,
        'repsLabel': controls.reps,
        'unreachable': controls.unreachable,
        'heartRate': controls.heartRate,
        'bpm': controls.bpm,
        'energy': controls.energy,
        'kcal': controls.kcal,
        'finish': controls.finish,
        'finishTitle': controls.finishTitle,
        'finishConfirm': controls.finishConfirm,
        'finishCancel': controls.finishCancel,
        'save': controls.save,
        'notDone': controls.notDone,
        'restLabelAway': controls.restLabel,
        'restOverAway': controls.restOver,
        'allDone': controls.allDone,
        'idle': controls.idle,
      },
      'state': 'workout',
      'workoutId': workoutId,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'title': title,
      'exercise': exercise,
      'next': next,
      if (rest case OngoingRest rest) ...{
        'restStart': rest.start.millisecondsSinceEpoch,
        'restEnd': rest.end.millisecondsSinceEpoch,
        'restLabel': rest.label,
        'restOver': rest.over,
      },
      // the watch is always dark: only the dark half of the preset applies
      'accent': preset.dark.accent.toARGB32(),
    };
  }

  /// By content. The exercises are lists, which records compare by identity: a
  /// state rebuilt on every keystroke would never equal the last one, and the
  /// presenter would send each of them.
  @override
  bool operator ==(Object other) => other is WatchWorkout && _same(toMap(), other.toMap());

  @override
  int get hashCode => Object.hash(workout, set, controls, activity, exercises.length);
}

/// Deep equality over what [WatchState.toMap] produces: maps, lists and scalars.
bool _same(Object? a, Object? b) {
  return switch ((a, b)) {
    (Map a, Map b) => a.length == b.length && a.keys.every((key) => b.containsKey(key) && _same(a[key], b[key])),
    (List a, List b) => a.length == b.length && Iterable<int>.generate(a.length).every((i) => _same(a[i], b[i])),
    _ => a == b,
  };
}

/// Something the user did on the watch (#183): a request, never an edit. The
/// phone applies it the way the same tap on the phone would, then sends the
/// state that results — or ignores it, if it names a workout or a set that is
/// no longer current, and the state it sends back says so on its own.
sealed class WatchCommand {
  final String workoutId;

  /// When the user did it, as the watch's clock had it. Null from a watch that
  /// predates #206. A command sent while the phone was out of reach arrives
  /// late — minutes, or the rest of the workout — and what it did must be
  /// placed at this time, not at the time it arrived.
  final DateTime? at;

  const new(this.workoutId, {this.at});

  /// Null for anything unrecognised — a newer watch app, say — which is dropped.
  static WatchCommand? fromMap(Map<Object?, Object?> map) {
    final at = switch (map['at']) {
      num at => DateTime.fromMillisecondsSinceEpoch(at.toInt()),
      _ => null,
    };
    return switch (map) {
      {'action': 'complete', 'workoutId': String workoutId, 'setId': String setId} => WatchComplete(
        workoutId,
        setId: setId,
        weight: (map['weight'] as num?)?.toDouble(),
        reps: (map['reps'] as num?)?.toInt(),
        at: at,
      ),
      {'action': 'skipRest', 'workoutId': String workoutId} => WatchSkipRest(workoutId, at: at),
      {'action': 'finish', 'workoutId': String workoutId} => WatchFinishWorkout(workoutId, at: at),
      {'action': 'edit', 'workoutId': String workoutId, 'setId': String setId} => WatchEditSet(
        workoutId,
        setId: setId,
        weight: (map['weight'] as num?)?.toDouble(),
        reps: (map['reps'] as num?)?.toInt(),
        at: at,
      ),
      {'action': 'untick', 'workoutId': String workoutId, 'setId': String setId} => WatchUntickSet(
        workoutId,
        setId: setId,
        at: at,
      ),
      {'action': 'adjustRest', 'workoutId': String workoutId, 'seconds': num seconds} => WatchAdjustRest(
        workoutId,
        seconds: seconds.toInt(),
        at: at,
      ),
      _ => null,
    };
  }
}

/// Tick [setId], with the values the watch shows for it — in the unit the
/// phone sent ([WatchSet.unit]).
final class WatchComplete extends WatchCommand {
  final String setId;
  final double? weight;
  final int? reps;

  const new(super.workoutId, {required this.setId, this.weight, this.reps, super.at});
}

final class WatchSkipRest extends WatchCommand {
  const new(super.workoutId, {super.at});
}

/// New values for a set already done, gone back to from the workout page —
/// in the unit the phone sent. It stays ticked.
final class WatchEditSet extends WatchCommand {
  final String setId;
  final double? weight;
  final int? reps;

  const new(super.workoutId, {required this.setId, this.weight, this.reps, super.at});
}

/// Take the tick off a set: it was not done after all.
final class WatchUntickSet extends WatchCommand {
  final String setId;

  const new(super.workoutId, {required this.setId, super.at});
}

/// Finish the workout, confirmed on the wrist. Offered only once every set is
/// ticked — anything left unticked is the phone's question to ask.
final class WatchFinishWorkout extends WatchCommand {
  const new(super.workoutId, {super.at});
}

final class WatchAdjustRest extends WatchCommand {
  final int seconds;

  const new(super.workoutId, {required this.seconds, super.at});
}

/// No workout is running, or the switch is off: one line saying so.
final class WatchMessage extends WatchState {
  /// `idle` or `off` — the watch draws them differently.
  final String kind;
  final String message;

  const new idle(this.message) : kind = 'idle';

  const new off(this.message) : kind = 'off';

  @override
  Map<String, Object?> toMap() => {'state': kind, 'message': message};

  @override
  bool operator ==(Object other) => other is WatchMessage && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);
}

/// Something the watch app did.
enum WatchEvent {
  /// The watch app was launched. The first launch ever is the user's yes
  /// (`docs/opt-in.md`); every launch is also a request for the current state,
  /// which a reinstalled watch app no longer has.
  opened,

  /// A watch was paired or unpaired, or Heart installed on or removed from it.
  changed,
}

/// The phone's end of the watch app (#175), through
/// `ios/Runner/WatchChannel.swift`.
abstract interface class WatchLink {
  /// Whether a paired watch has Heart installed — what decides if the setting
  /// is offered at all.
  Future<bool> isInstalled();

  /// Replaces what the watch shows.
  Future<void> send(WatchState state);

  /// Whether the watch app was opened while nothing here was listening — a
  /// launch that happened while the phone app was not running. Asking clears
  /// it.
  Future<bool> takeOpened();

  Stream<WatchEvent> get events;

  /// Commands from the watch, as they arrive.
  Stream<WatchCommand> get commands;

  /// Commands that arrived while nothing here was listening — sent from the
  /// watch while the phone app was not running — oldest first. Asking clears
  /// them.
  Future<List<WatchCommand>> takeCommands();

  /// [workoutId] was finished on the phone at [end] (#184). If the watch ran a
  /// workout session for it, the watch saves that workout to Health — with the
  /// heart rate and energy it measured — and this answers true, so the phone
  /// does not write a second, unmeasured copy. False when the watch measured
  /// nothing, and the phone writes as it always has.
  ///
  /// A workout that ends any other way — cancelled — is never finished here,
  /// and the watch discards what it measured.
  Future<bool> finish(String workoutId, {required DateTime end});

  /// Whether the watch is measuring [workoutId] with a workout session — and
  /// so, awake with the wrist down, taps the wrist itself when a rest ends
  /// (#185). The phone's rest notification would reach the same wrist a
  /// second time; while this is true, the watch owns the tap.
  Future<bool> measures(String workoutId);
}

/// The link for [platform], or null where there is no watch app.
WatchLink? watchLink(TargetPlatform platform) {
  return switch (platform) {
    .iOS => _WatchConnectivity.instance,
    _ => null,
  };
}

/// WatchConnectivity. Like the Live Activity, every call is fire-and-report:
/// a watch that cannot be reached is never a reason to fail a workout.
class _WatchConnectivity implements WatchLink {
  static final instance = _WatchConnectivity._();

  static const _channel = MethodChannel('heart/watch');

  final _events = StreamController<WatchEvent>.broadcast();
  final _commands = StreamController<WatchCommand>.broadcast();

  new _() {
    _channel.setMethodCallHandler((call) async {
      switch ((call.method, call.arguments, WatchEvent.values.asNameMap()[call.method])) {
        // the answer tells the native side whether anyone was listening; if
        // not, it keeps the command for [takeCommands]
        case ('command', Map arguments, _):
          if (!_commands.hasListener) return false;
          if (WatchCommand.fromMap(arguments) case WatchCommand command) _commands.add(command);
          return true;
        case (_, _, WatchEvent event):
          _events.add(event);
          return true;
        default:
          throw MissingPluginException('heart/watch has no ${call.method}');
      }
    });
  }

  @override
  Stream<WatchEvent> get events => _events.stream;

  @override
  Stream<WatchCommand> get commands => _commands.stream;

  @override
  Future<List<WatchCommand>> takeCommands() async {
    try {
      final queued = await _channel.invokeListMethod<Map<Object?, Object?>>('takeCommands') ?? const [];
      return queued.map(WatchCommand.fromMap).nonNulls.toList();
    } on MissingPluginException {
      return const [];
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Watch takeCommands failed', e, stacktrace);
      return const [];
    }
  }

  @override
  Future<bool> isInstalled() => _ask('installed');

  @override
  Future<bool> measures(String workoutId) => _ask('measures', {'workoutId': workoutId});

  @override
  Future<bool> finish(String workoutId, {required DateTime end}) {
    return _ask('finish', {'workoutId': workoutId, 'end': end.millisecondsSinceEpoch});
  }

  @override
  Future<bool> takeOpened() => _ask('takeOpened');

  @override
  Future<void> send(WatchState state) async {
    try {
      await _channel.invokeMethod<void>('send', state.toMap());
    } on MissingPluginException {
      // a host without the channel — a widget test, an older build
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Watch send failed', e, stacktrace);
    }
  }

  Future<bool> _ask(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<bool>(method, arguments) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Watch $method failed', e, stacktrace);
      return false;
    }
  }
}
