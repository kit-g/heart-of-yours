import 'package:flutter/foundation.dart';
import 'package:heart/core/env/shortcuts.dart';
import 'package:heart_models/heart_models.dart';
import 'package:heart_state/heart_state.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the system's assistant layer told what it can name (#285): the
/// templates, the user's own first and then the samples, as [ShortcutTemplate]s
/// — so "Start Push day in Heart" resolves with the app not running. Published
/// again whenever they change, and only when they changed.
///
/// Switched off, the feature publishes nothing: the assistant then knows no
/// template, and a bare "start a workout" opens the app to do nothing, as
/// #284 has it. Never asked and on both publish, since reaching for a
/// shortcut is the yes.
class SystemShortcutsPresenter extends StatefulWidget {
  final Widget child;

  /// The platform's layer, or null where there is none (tests, the web).
  final SystemShortcuts? shortcuts;

  const new({super.key, required this.child, this.shortcuts});

  @override
  State<SystemShortcutsPresenter> createState() => _SystemShortcutsPresenterState();
}

class _SystemShortcutsPresenterState extends State<SystemShortcutsPresenter> {
  Templates? _templates;
  Preferences? _preferences;

  /// What was last told, so the same list is not sent again on every repaint.
  List<ShortcutTemplate>? _published;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final templates = Templates.of(context);
    if (!identical(templates, _templates)) {
      _templates?.removeListener(_sync);
      _templates = templates..addListener(_sync);
    }
    final preferences = Preferences.of(context);
    if (!identical(preferences, _preferences)) {
      _preferences?.removeListener(_sync);
      _preferences = preferences..addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _templates?.removeListener(_sync);
    _preferences?.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _sync() {
    final shortcuts = widget.shortcuts;
    if (shortcuts == null) return;
    final list = switch ((_preferences?.featureAnswer(.shortcuts), _templates)) {
      (FeatureAnswer.off, _) || (_, null) => const <ShortcutTemplate>[],
      (_, Templates templates) => [...templates, ...templates.samples].map(_named).nonNulls.toList(),
    };
    if (_published case List<ShortcutTemplate> published when listEquals(published, list)) return;
    _published = list;
    shortcuts.setTemplates(list);
  }

  /// A template without a name is nothing to say to Siri.
  static ShortcutTemplate? _named(Template template) {
    return switch (template.name?.trim()) {
      String name when name.isNotEmpty => ShortcutTemplate(id: template.id, name: name),
      _ => null,
    };
  }
}
