import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Shortcuts');

/// A command from outside the app (#284): what Siri, the Shortcuts app, a
/// launcher shortcut or the system assistant open Heart on. Carried as a URL on
/// the app's own scheme, `heart://app/<verb>`, so that every platform's
/// assistant layer builds a link and never touches the data itself. The verbs
/// are the contract the native layers (#285, #286) speak; Dart owns them.
///
/// The link reaches go_router as a location whose path is the verb: the host
/// (`app`) is there so the path is not empty, and nothing matches on it.
sealed class ShortcutLink {
  const new();

  /// Null for a link that is not a command — a screen's deep link, or a verb
  /// this version does not know, which is then nowhere to go.
  static ShortcutLink? parse(Uri uri) {
    return switch ((uri.path, uri.queryParameters)) {
      ('/start', {'template': String id}) when id.isNotEmpty => StartWorkoutLink(templateId: id),
      ('/start', _) => const StartWorkoutLink(),
      ('/finish', _) => const FinishWorkoutLink(),
      _ => null,
    };
  }
}

/// Start a workout: from the template [templateId] names (the user's own or a
/// sample), or a blank one.
final class StartWorkoutLink extends ShortcutLink {
  final String? templateId;

  const new({this.templateId});

  /// By value: the same link arriving twice is the same ask (see
  /// `runShortcutLink`).
  @override
  bool operator ==(Object other) => other is StartWorkoutLink && other.templateId == templateId;

  @override
  int get hashCode => Object.hash(StartWorkoutLink, templateId);
}

/// Finish the active workout — the same question the Finish button asks.
final class FinishWorkoutLink extends ShortcutLink {
  const new();

  @override
  bool operator ==(Object other) => other is FinishWorkoutLink;

  @override
  int get hashCode => (FinishWorkoutLink).hashCode;
}

/// A template as the assistant layer sees it (#285): what Siri resolves "Start
/// Push day in Heart" against, with the app possibly not running. The name is
/// the user's own, or a sample's in the app's language at the time it was
/// published.
final class ShortcutTemplate {
  final String id;
  final String name;

  const new({required this.id, required this.name});

  Map<String, String> toMap() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is ShortcutTemplate && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The rest the assistant can start, extend or skip by voice (#98): which
/// workout and exercise it belongs to, how long the exercise rests when no
/// length is said (null for one with no rest timer), and the words of the
/// "rest complete" notification the assistant schedules itself when the app
/// is not running to.
typedef ShortcutRest = ({
  String workoutId,
  String exerciseId,
  int? seconds,
  String title,
  String? body,
  String subtitle,
});

/// The set up next, for a set logged by voice (#287): which set, what it
/// takes — a weight, a count, both or neither, by its exercise's category —
/// in the unit it is shown in, with whatever it already holds, and whether
/// it can be ticked as it stands.
typedef ShortcutSet = ({
  String workoutId,
  String setId,
  String exerciseName,
  bool weighted,
  bool counted,
  String unit,
  double? weight,
  int? reps,
  bool completable,
});

/// An exercise as the assistant names it (#288): the catalogue's id and its
/// localized name, for "what's my ${exercise} record".
final class ShortcutExercise {
  final String id;
  final String name;

  const new({required this.id, required this.name});

  Map<String, String> toMap() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is ShortcutExercise && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The system's assistant layer: Siri, the Shortcuts app and Spotlight on iOS,
/// the launcher on Android. Dart tells it what it needs to know and nothing
/// more; the intents and shortcuts themselves live natively and open the app
/// on a [ShortcutLink], or hand the app a command.
abstract interface class SystemShortcuts {
  /// Whether the feature is on. Android shows the launcher's "Start a
  /// workout" only while it is — absent rather than dead, since off, its link
  /// does nothing. iOS has nothing to hide: its App Shortcuts are declared
  /// in the binary.
  Future<void> setEnabled({required bool enabled});

  /// Replaces the templates the assistant can name. Empty: none, which is what
  /// the feature switched off publishes.
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates);

  /// The rest a voice command acts on (#98); null with no workout running,
  /// or the feature off.
  Future<void> setRest(ShortcutRest? rest);

  /// The set a voice command logs (#287); null with nothing left to log, no
  /// workout running, or the feature off.
  Future<void> setNextSet(ShortcutSet? set);

  /// Whose training a question is about (#288): the session's user, or null
  /// with none — or the feature off. The questions' engine runs without the
  /// app's session, so this is how it knows.
  Future<void> setSession(String? userId);

  /// The exercises the assistant can name (#288). Empty: none.
  Future<void> setExercises(Iterable<ShortcutExercise> exercises);
}

/// Null where there is no assistant layer to speak to.
SystemShortcuts? systemShortcuts(TargetPlatform platform) {
  return switch (platform) {
    .iOS || .android => _MethodChannelShortcuts.instance,
    .fuchsia || .linux || .macOS || .windows => null,
  };
}

/// Fire-and-report, like the watch: an assistant that cannot be told is never
/// a reason to fail anything in the app.
class _MethodChannelShortcuts implements SystemShortcuts {
  static final instance = _MethodChannelShortcuts._();

  static const _channel = MethodChannel('heart/shortcuts');

  new _();

  @override
  Future<void> setEnabled({required bool enabled}) => _tell('setEnabled', enabled);

  @override
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates) {
    return _tell('setTemplates', templates.map((template) => template.toMap()).toList());
  }

  @override
  Future<void> setRest(ShortcutRest? rest) {
    return _tell('setRest', switch (rest) {
      ShortcutRest rest => {
        'workoutId': rest.workoutId,
        'exerciseId': rest.exerciseId,
        'seconds': ?rest.seconds,
        'title': rest.title,
        'body': ?rest.body,
        'subtitle': rest.subtitle,
      },
      null => null,
    });
  }

  @override
  Future<void> setNextSet(ShortcutSet? set) {
    return _tell('setNextSet', switch (set) {
      ShortcutSet set => {
        'workoutId': set.workoutId,
        'setId': set.setId,
        'exerciseName': set.exerciseName,
        'weighted': set.weighted,
        'counted': set.counted,
        'unit': set.unit,
        'weight': ?set.weight,
        'reps': ?set.reps,
        'completable': set.completable,
      },
      null => null,
    });
  }

  @override
  Future<void> setSession(String? userId) => _tell('setSession', userId);

  @override
  Future<void> setExercises(Iterable<ShortcutExercise> exercises) {
    return _tell('setExercises', exercises.map((exercise) => exercise.toMap()).toList());
  }

  Future<void> _tell(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // a build without the native side: nothing to tell
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Shortcuts $method failed', e, stacktrace);
    }
  }
}
