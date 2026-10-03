import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:heart_state/heart_state.dart';

/// Where the release notes live: one file per locale, `en` complete, every
/// other locale a subset of it.
///
/// Bundled rather than fetched on purpose: the list can never describe a
/// feature the installed build does not have, and the links items will carry
/// point at routes, which exist only in the build that shipped them.
const whatsNewDirectory = 'assets/whats_new';

/// One version's entry in What's new.
class Release {
  final String version;

  /// When the version's first prod build ran. `null` for the release being
  /// cut: its entry is committed before the tag, and the date is stamped into
  /// the bundle by the prod workflow — a dev build never gets one.
  final DateTime? date;
  final List<ReleaseNote> notes;

  const new({required this.version, required this.notes, this.date});

  static Release? _parse(Object? raw) {
    return switch (raw) {
      {'version': String version, 'items': List items} when _Version.parse(version) != null => Release(
        version: version,
        date: switch (raw['date']) {
          String date => DateTime.tryParse(date),
          _ => null,
        },
        notes: items.map(ReleaseNote._parse).nonNulls.toList(),
      ),
      _ => null,
    };
  }
}

/// One thing a version brought: a plain-text [title] and a markdown [body].
class ReleaseNote {
  /// Stable within its version; a translation replaces the `en` note with the
  /// same version and id.
  final String id;
  final String title;
  final String body;

  /// Where the note applies — `ios`, `android` — or null for everywhere. Set
  /// in `en` only, like the date; a translation follows its `en` note.
  final Set<String>? platforms;

  /// The opt-in feature the note is about, if any (#239): the note carries a
  /// button to its row on the Features page. Set in `en` only, like
  /// [platforms]. A value this build does not know reads as none.
  final Feature? feature;

  const new({required this.id, required this.title, required this.body, this.platforms, this.feature});

  static ReleaseNote? _parse(Object? raw) {
    return switch (raw) {
      {'id': String id, 'title': String title, 'body': String body} => ReleaseNote(
        id: id,
        title: title,
        body: body,
        platforms: switch (raw['platforms']) {
          List platforms => platforms.whereType<String>().toSet(),
          _ => null,
        },
        feature: Feature.values.where((feature) => feature.value == raw['feature']).firstOrNull,
      ),
      _ => null,
    };
  }

  /// Whether a user on [platform] can use what this note describes.
  bool appliesTo(TargetPlatform platform) {
    return switch (platforms) {
      null => true,
      Set<String> platforms => platforms.contains(switch (platform) {
        .iOS => 'ios',
        .android => 'android',
        TargetPlatform other => other.name,
      }),
    };
  }
}

/// [releases] with only the notes a user on [platform] can use: an Android
/// user never reads about the watch. A release left with none is dropped.
List<Release> forPlatform(List<Release> releases, TargetPlatform platform) {
  return [
    for (final release in releases)
      if (release.notes.where((note) => note.appliesTo(platform)).toList() case final notes when notes.isNotEmpty)
        Release(version: release.version, date: release.date, notes: notes),
  ];
}

/// Parses one locale file. Entries that do not parse are dropped rather than
/// costing the file: the content test in `test/whats_new_content_test.dart`
/// is what keeps them out of a build.
///
/// Throws [FormatException] when [source] is not a JSON list at all.
List<Release> parseReleases(String source) {
  return switch (jsonDecode(source)) {
    List entries => entries.map(Release._parse).nonNulls.toList(),
    Object? other => throw FormatException('not a list of releases', other),
  };
}

/// [base] (the `en` file) with every note [localized] has a translation for
/// swapped in, newest version first.
///
/// The fallback is per note, not per file or per version: a locale that has
/// caught up on one note of a version still reads the rest of it in English
/// rather than losing it. Notes [localized] carries that `en` does not are
/// ignored — `en` is the list of what exists.
List<Release> mergeReleases(List<Release> base, List<Release> localized) {
  final translations = {
    for (final release in localized)
      for (final note in release.notes) (release.version, note.id): note,
  };
  return [
    for (final release in base)
      Release(
        version: release.version,
        date: release.date,
        notes: [
          for (final note in release.notes)
            switch (translations[(release.version, note.id)]) {
              // the words are the translation's; what the note is about is en's
              ReleaseNote(:final title, :final body) => ReleaseNote(
                id: note.id,
                title: title,
                body: body,
                platforms: note.platforms,
                feature: note.feature,
              ),
              null => note,
            },
        ],
      ),
  ]..sort((a, b) => compareVersions(b.version, a.version));
}

/// Reads What's new for [locale] from [bundle].
///
/// The locale file is looked up by exact tag, then bare language — `en_CA`
/// has no file of its own and lands on `en`, like library content does. A
/// missing locale file is ordinary; a malformed one is a bug in bundled
/// content, reported through [onError] and answered with the `en` copy, and a
/// malformed `en` with an empty list, never a crash. Only the notes for
/// [platform] are kept ([forPlatform]).
Future<List<Release>> loadReleases(
  AssetBundle bundle,
  Locale locale, {
  required TargetPlatform platform,
  void Function(dynamic error, {dynamic stacktrace})? onError,
}) async {
  Future<List<Release>?> read(String name) async {
    final String source;
    try {
      source = await bundle.loadString('$whatsNewDirectory/$name.json');
    } catch (_) {
      return null;
    }
    try {
      return parseReleases(source);
    } catch (error, stacktrace) {
      onError?.call(error, stacktrace: stacktrace);
      return null;
    }
  }

  // filtered before merging: platforms are set in en, and a translation
  // carries none of its own
  final base = switch (await read('en')) {
    List<Release> base => forPlatform(base, platform),
    null => null,
  };
  if (base == null) return const [];

  final candidates = {
    if (locale.countryCode case String country when country.isNotEmpty) '${locale.languageCode}_$country',
    locale.languageCode,
  }.where((name) => name != 'en');

  for (final name in candidates) {
    if (await read(name) case List<Release> localized) return mergeReleases(base, localized);
  }
  return mergeReleases(base, const []);
}

/// Orders two `major.minor.patch` versions numerically, so 1.10.0 sorts after
/// 1.9.0. An unparseable version sorts before every parseable one.
int compareVersions(String a, String b) {
  return switch ((_Version.parse(a), _Version.parse(b))) {
    (List<int> a, List<int> b) => _compareParts(a, b),
    (null, null) => 0,
    (null, _) => -1,
    (_, null) => 1,
  };
}

/// The release [running] should mark as "this version": the newest one not
/// newer than it.
///
/// Not an exact match, because most builds are fix-only releases, which get
/// no entry — 1.8.5 is running what 1.8.0 introduced. `null` when [running]
/// does not parse (an unknown version marks nothing rather than guessing).
Release? currentRelease(List<Release> releases, String running) {
  if (_Version.parse(running) == null) return null;
  final candidates = releases.where((release) => compareVersions(release.version, running) <= 0).toList()
    ..sort((a, b) => compareVersions(b.version, a.version));
  return candidates.firstOrNull;
}

int _compareParts(List<int> a, List<int> b) {
  return a.indexed.map((part) => part.$2.compareTo(b[part.$1])).firstWhere((order) => order != 0, orElse: () => 0);
}

/// Whether What's new holds notes this device has not shown (#216): the one
/// quiet dot on Settings, and on its What's new row.
///
/// Counted against the `en` notes, which are the list of what exists — a
/// locale only changes their words. A note counts once the running build has
/// shipped its version. A fresh install starts caught up: the first time this
/// has both the notes and the version, and nothing was ever recorded, it
/// records them all as read.
class WhatsNewBadge with ChangeNotifier {
  final Preferences _preferences;
  final AppInfo _info;
  List<Release>? _releases;
  bool _unread = false;

  new({required this._preferences, required this._info, required Future<List<Release>> releases}) {
    _preferences.addListener(_update);
    _info.addListener(_update);
    releases.then((releases) {
      _releases = releases;
      _update();
    });
  }

  @override
  void dispose() {
    _preferences.removeListener(_update);
    _info.removeListener(_update);
    super.dispose();
  }

  bool get unread => _unread;

  /// `version/id` for every note the running build has shipped; null until
  /// both are known.
  Set<String>? get _notes {
    final running = _info.version;
    if (_releases == null || _Version.parse(running) == null) return null;
    return {
      for (final release in _releases!)
        if (compareVersions(release.version, running) <= 0)
          for (final note in release.notes) '${release.version}/${note.id}',
    };
  }

  void _update() {
    if (!_preferences.isInitialized) return;
    final notes = _notes;
    if (notes == null) return;
    switch (_preferences.whatsNewRead) {
      case null:
        // a fresh install: caught up, and recorded so a later update is not
        _preferences.markWhatsNewRead(notes);
      case Set<String> read when !read.containsAll(notes) != _unread:
        _unread = !_unread;
        notifyListeners();
      case _:
        break;
    }
  }

  /// What's new was opened: every note it lists is read.
  void markRead() {
    if (_notes case Set<String> notes) _preferences.markWhatsNewRead(notes);
  }

  static WhatsNewBadge watch(BuildContext context) => Provider.of<WhatsNewBadge>(context);

  static WhatsNewBadge of(BuildContext context) => Provider.of<WhatsNewBadge>(context, listen: false);
}

abstract final class _Version {
  static final _shape = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

  static List<int>? parse(String version) {
    return switch (_shape.firstMatch(version)) {
      RegExpMatch match => [1, 2, 3].map((group) => int.parse(match.group(group)!)).toList(),
      null => null,
    };
  }
}
