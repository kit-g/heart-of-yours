import 'package:flutter/foundation.dart';
import 'package:heart_models/heart_models.dart';

/// A feature the user opts into (#138, `docs/opt-in.md`).
///
/// Everything the app shipped as of 1.9.0 is core and is not listed here.
/// Anything after it is, unless its ticket says why it is core. [value] is the
/// storage key and never changes once shipped: renaming it would read as "never
/// asked" and ask again.
enum Feature {
  /// Sets per muscle group on the body map, on the profile (#136).
  muscleMap('muscleMap'),

  /// The workout on Apple Watch (#175). The one feature whose ask is not an
  /// in-app offer: opening Heart on the watch for the first time is the yes
  /// (`docs/opt-in.md`, *Precedent*).
  watchApp('watchApp'),

  /// How hard each set was, rated from a bar over the number pad (#234).
  /// Stored and synced whatever the answer; the switch shows it.
  rpe('rpe'),

  /// Count up in an active timed set (#171); enabled only in Settings.
  setStopwatch('setStopwatch');

  final String value;

  new(this.value);

  /// The parts of this feature the user can leave out ([FeatureOption]); none
  /// for most.
  Iterable<FeatureOption> get options => FeatureOption.values.where((option) => option.feature == this);
}

/// A part of a [Feature] the user can leave out (#213), chosen under the
/// feature's switch in Settings while it is on.
///
/// Never asked about: turning the feature on is the yes, and it turns on in
/// full — every option selected. Leaving all of a feature's options out is
/// turning the feature off. [value] is the storage key, unique within its
/// feature, and never changes once shipped.
enum FeatureOption {
  /// The body figures, shaded by sets per muscle group.
  muscleMapFigures(.muscleMap, 'figures'),

  /// The list of sets per muscle group.
  muscleMapBreakdown(.muscleMap, 'breakdown'),

  /// Sets per muscle group week by week.
  muscleMapHeatmap(.muscleMap, 'heatmap'),

  /// The body figures for a single finished workout, on its page in History
  /// and on the done screen (#223).
  muscleMapWorkout(.muscleMap, 'workout');

  final Feature feature;
  final String value;

  new(this.feature, this.value);
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
///
/// [without] is the options left out (#213). It travels with the answer, and
/// changing it is a new answer, at a new time. Off, it is kept as it was —
/// stored, unused — and turning the feature on clears it.
final class FeatureRecord {
  final bool on;
  final DateTime at;
  final Set<FeatureOption> without;

  const new({required this.on, required this.at, this.without = const {}});

  /// By value: the options are a set, which records would compare by identity.
  @override
  bool operator ==(Object other) {
    return other is FeatureRecord && other.on == on && other.at == at && setEquals(other.without, without);
  }

  @override
  int get hashCode => Object.hash(on, at, Object.hashAllUnordered(without));

  @override
  String toString() => 'FeatureRecord(on: $on, at: $at, without: $without)';
}

/// Where the answers live in the account's [Settings]: `extra.features`, one
/// entry per [Feature.value] —
/// `{"muscleMap": {"on": true, "at": "…", "without": ["heatmap"]}}`.
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
      if (stored[feature.value] case {'on': bool on, 'at': String at} && final entry)
        if (DateTime.tryParse(at) case DateTime at)
          feature: FeatureRecord(
            on: on,
            at: at,
            without: switch (entry['without']) {
              List without => {
                for (final option in feature.options)
                  if (without.contains(option.value)) option,
              },
              _ => const {},
            },
          ),
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
        for (final MapEntry(key: feature, value: FeatureRecord(:on, :at, :without)) in records.entries)
          feature.value: {
            // an entry's other keys, and options this version does not know,
            // are a newer app's and pass through
            if (stored[feature.value] case Map entry) ...entry,
            'on': on,
            'at': at.toUtc().toIso8601String(),
            'without': [
              ...without.map((option) => option.value),
              if (stored[feature.value] case {'without': List theirs})
                ...theirs.where((value) => !feature.options.any((option) => option.value == value)),
            ],
          },
      },
    },
  );
}
