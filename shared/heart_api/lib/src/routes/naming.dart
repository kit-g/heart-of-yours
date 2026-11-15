part of '../api.dart';

/// Exercise names in what the server sends back (heart-of-yours#612).
///
/// The server names the exercises inside a workout, a template or a program
/// from its base rows, which are English and never translated
/// (heart-api#447), so a Russian phone's History and templates read in
/// English while its library reads in Russian. Every payload that nests
/// exercises is renamed through [exerciseName] before it is read.
mixin _ExerciseNaming on Requests {
  /// The device's own name for an exercise, by id: the library's in the
  /// user's language, or an own exercise's latest (#616). Null, or a null
  /// answer, keeps the server's name.
  String? Function(String exerciseId)? exerciseName;

  /// Told how many exercises in the account's own history or templates
  /// [exerciseName] could not name, out of how many. Every one of the
  /// account's exercises is in the device's catalog, the library's and its
  /// own, so a miss is a server name in English reaching the screen: the
  /// catalog lacks it, or is not loaded yet. Other people's workouts (a
  /// coach's view of a client's) are renamed but not counted: their own
  /// exercises are never on this device.
  void Function(int unnamed, int of)? onUnnamedExercises;

  /// [json] with every exercise in it named by [exerciseName]: any map under
  /// an `exercise` key that carries an `id`, however deep, which is how
  /// workouts, templates and programs (whose sessions are templates) all hold
  /// theirs. Without a namer the payload is returned as it came.
  Map _named(Map json) => _namedAll([json]).single as Map;

  /// [_named] over a whole response list, counting what it could not name
  /// when [counts]: the account's own payloads, see [onUnnamedExercises].
  List _namedAll(List payloads, {bool counts = false}) {
    final name = exerciseName;
    if (name == null) return payloads;
    final tally = (unnamed: <String>{}, of: <String>{});
    final renamed = [for (final each in payloads) _renamed(each, name, tally)];
    if (counts && tally.unnamed.isNotEmpty) onUnnamedExercises?.call(tally.unnamed.length, tally.of.length);
    return renamed;
  }

  static Object? _renamed(Object? json, String? Function(String id) name, _Tally tally) {
    return switch (json) {
      Map map => {
        for (final MapEntry(:key, :value) in map.entries)
          key: switch ((key, value)) {
            ('exercise', {'id': String id} && Map exercise) => {
              ...exercise,
              'name': _nameOf(exercise, id, name, tally),
            },
            _ => _renamed(value, name, tally),
          },
      },
      List list => [for (final each in list) _renamed(each, name, tally)],
      _ => json,
    };
  }

  static Object? _nameOf(Map exercise, String id, String? Function(String id) name, _Tally tally) {
    tally.of.add(id);
    if (name(id) case String named) return named;
    tally.unnamed.add(id);
    return exercise['name'];
  }
}

typedef _Tally = ({Set<String> unnamed, Set<String> of});
