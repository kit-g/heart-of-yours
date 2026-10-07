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
