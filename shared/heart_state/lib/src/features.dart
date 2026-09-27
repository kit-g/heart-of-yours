import 'package:heart_models/heart_models.dart';

/// A feature the user opts into (#138, `docs/opt-in.md`).
///
/// Everything the app shipped as of 1.9.0 is core and is not listed here.
/// Anything after it is, unless its ticket says why it is core. [value] is the
/// storage key and never changes once shipped: renaming it would read as "never
/// asked" and ask again.
enum Feature {
  /// Sets per muscle group on the body map, on the profile (#136).
  muscleMap('muscleMap');

  final String value;

  new(this.value);
}

/// What the user said about a [Feature].
///
/// Three answers rather than a bool, because "said no" and "never asked" have
/// to stay apart: only the second may ever be asked.
enum FeatureAnswer {
  /// Never offered. The feature is off, and the one ask is still to come.
  unasked,

  /// Offered and not answered. Off, and never asked again: leaving the offer
  /// unanswered counts as no. The offer stays up for the rest of the session
  /// it was first shown in, so a user who looks away and back can still take
  /// it.
  pending,
  on,
  off,
  ;

  static FeatureAnswer fromString(String? v) {
    return switch (v) {
      'pending' => pending,
      'on' => on,
      'off' => off,
      _ => unasked,
    };
  }
}

/// A real answer about a feature, on or off, and when it was given — the unit
/// that travels between devices. The time is what settles two devices that
/// disagree: the later answer wins.
typedef FeatureRecord = ({bool on, DateTime at});

/// Where the answers live in the account's [Settings]: `extra.features`, one
/// entry per [Feature.value] — `{"muscleMap": {"on": true, "at": "…"}}`.
const _settingsKey = 'features';

/// The answers [settings] carries. Lenient: an entry this app cannot read —
/// malformed, or a feature from a newer version — is skipped, never a throw.
Map<Feature, FeatureRecord> featureRecordsOf(Settings settings) {
  final stored = switch (settings.extra[_settingsKey]) {
    Map stored => stored,
    _ => const {},
  };
  return {
    for (final feature in Feature.values)
      if (stored[feature.value] case {'on': bool on, 'at': String at})
        if (DateTime.tryParse(at) case DateTime at) feature: (on: on, at: at),
  };
}

/// [settings] with [records] written into it. Every other entry is kept as it
/// was, including features this version does not know: a newer app's answers
/// have to pass through an older one untouched.
Settings withFeatureRecords(Settings settings, Map<Feature, FeatureRecord> records) {
  final stored = switch (settings.extra[_settingsKey]) {
    Map stored => stored,
    _ => const {},
  };
  return settings.copyWith(
    extra: {
      ...settings.extra,
      _settingsKey: {
        ...stored,
        for (final MapEntry(key: feature, value: (:on, :at)) in records.entries)
          feature.value: {'on': on, 'at': at.toUtc().toIso8601String()},
      },
    },
  );
}
