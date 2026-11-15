import 'package:heart_models/heart_models.dart';

/// What History opens on (#609): the list of workouts, or the calendar. The
/// list is what History always was, and stays the default.
///
/// [value] is the storage key, on the device and in the account, and never
/// changes once shipped.
enum HistoryView {
  list('list'),
  calendar('calendar');

  final String value;

  new(this.value);

  static HistoryView? fromValue(String? value) => values.where((view) => view.value == value).firstOrNull;
}

/// A choice of how one of the app's screens shows itself, kept with when it
/// was made: what travels between devices. Like an opt-in answer
/// ([FeatureRecord]), the time settles two devices that disagree, and the
/// later choice wins.
///
/// [value] is the choice's own storage value ([HistoryView.value]), kept as
/// a string so a value from a newer app passes through an older one.
final class ScreenChoiceRecord {
  final String value;
  final DateTime at;

  const new({required this.value, required this.at});

  @override
  bool operator ==(Object other) => other is ScreenChoiceRecord && other.value == value && other.at == at;

  @override
  int get hashCode => Object.hash(value, at);

  @override
  String toString() => 'ScreenChoiceRecord(value: $value, at: $at)';
}

/// The screen choices there are, by their storage key.
enum ScreenChoice {
  /// [HistoryView] (#609).
  historyView('historyView');

  final String value;

  new(this.value);
}

/// Where the choices live in the account's [Settings]: `extra.screens`, one
/// entry per [ScreenChoice.value] —
/// `{"historyView": {"value": "calendar", "at": "…"}}`.
const _settingsKey = 'screens';

/// The choices [settings] carries. Lenient: an entry this app cannot read —
/// malformed, or a choice from a newer version — is skipped, never a throw.
Map<ScreenChoice, ScreenChoiceRecord> screenChoicesOf(Settings settings) {
  final stored = switch (settings.extra[_settingsKey]) {
    Map stored => stored,
    _ => const {},
  };
  return {
    for (final choice in ScreenChoice.values)
      if (stored[choice.value] case {'value': String value, 'at': String at})
        if (DateTime.tryParse(at) case DateTime at) choice: ScreenChoiceRecord(value: value, at: at),
  };
}

/// [settings] with [records] written into it. Every other entry is kept as it
/// was, so a newer app's choices pass through an older one untouched.
Settings withScreenChoices(Settings settings, Map<ScreenChoice, ScreenChoiceRecord> records) {
  final stored = switch (settings.extra[_settingsKey]) {
    Map stored => stored,
    _ => const {},
  };
  return settings.copyWith(
    extra: {
      ...settings.extra,
      _settingsKey: {
        ...stored,
        for (final MapEntry(key: choice, value: ScreenChoiceRecord(:value, :at)) in records.entries)
          choice.value: {
            if (stored[choice.value] case Map entry) ...entry,
            'value': value,
            'at': at.toUtc().toIso8601String(),
          },
      },
    },
  );
}
