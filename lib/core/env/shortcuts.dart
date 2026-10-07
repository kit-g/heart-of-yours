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

/// The system's assistant layer: Siri, the Shortcuts app and Spotlight on iOS,
/// the launcher on Android. Dart tells it what it needs to know and nothing
/// more; the intents and shortcuts themselves live natively and open the app
/// on a [ShortcutLink].
abstract interface class SystemShortcuts {
  /// Replaces the templates the assistant can name. Empty: none, which is what
  /// the feature switched off publishes.
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates);
}

/// Null where there is no assistant layer to speak to.
SystemShortcuts? systemShortcuts(TargetPlatform platform) {
  return switch (platform) {
    .iOS => _MethodChannelShortcuts.instance,
    _ => null,
  };
}

/// Fire-and-report, like the watch: an assistant that cannot be told is never
/// a reason to fail anything in the app.
class _MethodChannelShortcuts implements SystemShortcuts {
  static final instance = _MethodChannelShortcuts._();

  static const _channel = MethodChannel('heart/shortcuts');

  new _();

  @override
  Future<void> setTemplates(Iterable<ShortcutTemplate> templates) async {
    try {
      await _channel.invokeMethod<void>('setTemplates', templates.map((template) => template.toMap()).toList());
    } on MissingPluginException {
      // a build without the native side: nothing to tell
    } on PlatformException catch (e, stacktrace) {
      _logger.warning('Shortcuts setTemplates failed', e, stacktrace);
    }
  }
}
