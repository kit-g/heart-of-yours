part of '../api.dart';

/// What the device knows of an exercise: its name here, and whether it is
/// the account's own.
typedef DeviceExercise = ({String name, bool own});

/// Exercise names in what the server sends back (heart-of-yours#612).
///
/// The server names the exercises inside a workout or a template from its
/// base rows, and a library exercise's row is English, never translated
/// (heart-api#447). History takes the server's copies over the device's, so
/// a Russian phone's History and templates read in English while its library
/// reads in Russian. Those payloads get the library's names from the device
/// before they are read.
///
/// Only where an exercise is shown: a workout's or a template's exercises
/// (and a coach's view of a program's sessions, which are templates), and an
/// anomaly's. Never content a model keeps as it came and writes back.
mixin _ExerciseNaming on Requests {
  /// The device's exercise by id, or null when it has none. A library
  /// exercise is renamed to the device's name, in the user's language. An own
  /// exercise keeps the server's name, which is its latest: the device's
  /// copy can be the older one, when its sync has not landed.
  DeviceExercise? Function(String exerciseId)? exerciseOnDevice;

  /// Told how many exercises in the account's own History or templates the
  /// device has no copy of, out of how many. The library and the account's
  /// own exercises are all on the device once it has synced, so a miss is a
  /// server name in English on screen, or an exercise someone else made (a
  /// coach's, in a session they logged or a template they shared). A coach's
  /// view of a client is renamed but not counted: the client's own exercises
  /// are never on the coach's device.
  void Function(int unnamed, int of)? onUnnamedExercises;

  /// [workout] (or a template: the same shape) with its exercises named.
  /// Changed in place: the decoded body is the caller's, and a copy would
  /// cost a second allocation of every set.
  Map _named(Map workout) {
    _nameExercises(workout, _Tally());
    return workout;
  }

  /// [_named] over a list of workouts or templates, counting what the device
  /// could not name when [counts]: the account's own, see
  /// [onUnnamedExercises].
  List _namedAll(List workouts, {bool counts = false}) {
    final tally = _Tally();
    for (final each in workouts.whereType<Map>()) {
      _nameExercises(each, tally);
    }
    if (counts && tally.unnamed.isNotEmpty) onUnnamedExercises?.call(tally.unnamed.length, tally.of.length);
    return workouts;
  }

  /// A coach's view of a client's program: its sessions are templates.
  Map _namedSessions(Map view) {
    if (view['sessions'] case final List sessions) _namedAll(sessions);
    return view;
  }

  /// An anomaly names its exercise flat, beside its id.
  Map _namedAnomaly(Map anomaly) {
    if ((anomaly['exerciseId'], exerciseOnDevice) case (final String id, final device?)) {
      if (device(id) case (:final name, own: false)) anomaly['exerciseName'] = name;
    }
    return anomaly;
  }

  void _nameExercises(Map workout, _Tally tally) {
    final device = exerciseOnDevice;
    if (device == null) return;
    for (final entry in [...?(workout['exercises'] as List?)?.whereType<Map>()]) {
      if (entry['exercise'] case {'id': final String id} && final Map exercise) {
        tally.of.add(id);
        switch (device(id)) {
          case null:
            tally.unnamed.add(id);
          case (:final name, own: false):
            exercise['name'] = name;
          case (name: _, own: true):
            break;
        }
      }
    }
  }
}

final class _Tally {
  final unnamed = <String>{};
  final of = <String>{};
}
