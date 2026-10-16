import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'static_content.dart';

/// Text the content CDN serves in several languages, by BCP-47 tag: what a
/// program says about itself, its research and its safety notes. Content,
/// not the app's copy, so it is picked here the way the server picks library
/// copy, rather than going through the translations flow.
extension type const ContentText._(Map<String, String> _byTag) {
  /// `{"en": …, "es": …}`, or a plain string in English with its translations
  /// beside it (a name and its `i18n`). Null when there is no English text.
  static ContentText? read(Object? text, {Object? translations}) {
    final byTag = <String, String>{
      if (translations case final Map translations)
        for (final MapEntry(:key, :value) in translations.entries)
          if (value case final String value when value.isNotEmpty) '$key': value,
      if (text case final Map text)
        for (final MapEntry(:key, :value) in text.entries)
          if (value case final String value when value.isNotEmpty) '$key': value,
      if (text case final String text when text.isNotEmpty) 'en': text,
    };
    return switch (byTag['en']) {
      String() => ContentText._(byTag),
      null => null,
    };
  }

  /// The text in [tag]'s language: the exact tag, then its bare language,
  /// then English (how `en_CA`, `es_ES` and `fr_CA` land, which the file
  /// leaves out where their copy wouldn't differ).
  String of(String tag) {
    // device tags come hyphenated (es-MX), content keys may use either
    final canonical = tag.replaceAll('-', '_');
    final language = canonical.split('_').first;
    return _byTag[tag] ?? _byTag[canonical] ?? _byTag[language] ?? _byTag['en']!;
  }
}

/// Who a library program is for: the library's groups, in the order the
/// library shows them.
enum LibraryAudience {
  startingOut('starting_out'),
  gettingBack('getting_back'),
  keepMuscle('keep_muscle'),
  gettingStronger('getting_stronger');

  final String value;

  new(this.value);

  /// Null for a group this build doesn't know: the program still reads, and
  /// shows outside the groups.
  static LibraryAudience? of(Object? value) => values.where((each) => each.value == value).firstOrNull;
}

/// What a library program needs: nothing, a pair of adjustable dumbbells, or
/// a gym.
enum LibraryEquipment {
  none('none'),
  home('home'),
  gym('gym');

  final String value;

  new(this.value);

  static LibraryEquipment? of(Object? value) => values.where((each) => each.value == value).firstOrNull;
}

/// Where a research claim belongs on a program's page.
///
/// [on] names the part: `program`, `who`, `week`, `grows`, `misses`,
/// `deload`, `phases`, `tests`, `next`, `rest`, or `rule` (one exercise's
/// growth rule, by its library [exercise] key), `session` (by its id) or
/// `exercise` (one exercise in one [session], by its template exercise id).
final class LibraryAnchor {
  final String on;
  final String? session;
  final String? exercise;

  const new({required this.on, this.session, this.exercise});

  static LibraryAnchor? read(Object? raw) {
    return switch (raw) {
      {'on': final String on} => LibraryAnchor(
        on: on,
        session: raw['session'] as String?,
        exercise: raw['exercise'] as String?,
      ),
      _ => null,
    };
  }
}

/// A sentence of research and the sources it rests on, with where it sits on
/// the program's page.
final class LibraryClaim {
  final ContentText text;

  /// Keys into [ProgramLibrary.source].
  final List<String> sources;
  final List<LibraryAnchor> about;

  const new({required this.text, required this.sources, required this.about});

  static LibraryClaim? read(Object? raw) {
    if (raw is! Map) return null;
    final text = ContentText.read(raw['text']);
    if (text == null) return null;
    return LibraryClaim(
      text: text,
      sources: _strings(raw['sources']),
      about: [
        for (final anchor in _list(raw['about']))
          if (LibraryAnchor.read(anchor) case final LibraryAnchor anchor) anchor,
      ],
    );
  }

  /// Whether this claim sits on the part [on] names.
  bool isAbout(String on, {String? session, String? exercise}) {
    return about.any((anchor) => anchor.on == on && anchor.session == session && anchor.exercise == exercise);
  }
}

/// A study or a guideline behind the library: what it is, who published it,
/// and where to read it.
final class LibrarySource {
  final String key;
  final String title;
  final String? who;
  final int? year;
  final Uri? url;

  /// What it found, in a line.
  final ContentText? finding;

  const new({required this.key, required this.title, this.who, this.year, this.url, this.finding});

  static LibrarySource? read(String key, Object? raw) {
    return switch (raw) {
      {'title': final String title} => LibrarySource(
        key: key,
        title: title,
        who: raw['who'] as String?,
        year: (raw['year'] as num?)?.toInt(),
        url: switch (raw['url']) {
          final String url => Uri.tryParse(url),
          _ => null,
        },
        finding: ContentText.read(raw['finding']),
      ),
      _ => null,
    };
  }
}

/// One of a program's blocks, as the library writes it: its sessions by
/// their ids in the file, and for how many weeks; the last may run on.
final class LibraryPhase {
  final ContentText? name;
  final List<String> sessions;
  final int? cycles;

  const new({this.name, required this.sessions, this.cycles});
}

/// A session of a library program: a template in `static/templates`' shape,
/// its exercises by library key.
final class LibrarySession {
  /// Stable across republishes, and only the file's: a copy takes its own.
  final String id;
  final ContentText name;
  final ContentText? note;
  final int order;
  final List<Map> _exercises;

  const new _({required this.id, required this.name, this.note, required this.order, required this._exercises});

  static LibrarySession? read(Object? raw) {
    if (raw is! Map) return null;
    final name = ContentText.read(raw['name'], translations: raw['i18n']);
    return switch ((raw['id'], name)) {
      (final String id, final ContentText name) => LibrarySession._(
        id: id,
        name: name,
        note: ContentText.read(raw['note'], translations: raw['noteI18n']),
        order: (raw['order'] as num?)?.toInt() ?? 0,
        exercises: [..._list(raw['exercises']).whereType<Map>()],
      ),
      _ => null,
    };
  }

  /// The library keys of the exercises the session names, in order.
  Iterable<String> get exerciseKeys => _exercises.map(_keyOf).nonNulls;

  /// The session as a template to look at, under the file's own ids. An
  /// exercise [resolve] doesn't know — an older catalog against a newer file —
  /// is left out.
  Template preview({required Exercise? Function(String key) resolve, required String tag}) {
    return Template.fromJson({
      'id': id,
      'name': name.of(tag),
      'order': order,
      'note': note?.of(tag),
      'exercises': [
        for (final exercise in _exercises)
          if (_keyOf(exercise) case final String key)
            if (resolve(key) case final Exercise resolved) {...exercise, 'exercise': resolved.toMap()},
      ],
    });
  }

  static String? _keyOf(Map exercise) {
    return switch (exercise['exercise']) {
      {'key': final String key} => key,
      _ => null,
    };
  }
}

/// A ready-made program as the library serves it: the plan, what it says
/// about itself, the research behind it and the safety notes it shows.
final class LibraryProgram {
  /// Stable, and what a copy remembers as its `source`.
  final String key;
  final LibraryAudience? audience;
  final LibraryEquipment? equipment;
  final ContentText name;
  final ContentText? note;
  final ContentText? who;
  final ContentText? week;
  final ContentText? grows;
  final ContentText? misses;
  final List<LibraryClaim> claims;

  /// Keys into [ProgramLibrary.source], every one the program cites.
  final List<String> sources;

  /// Keys into [ProgramLibrary.safety], in the order shown.
  final List<String> safety;

  /// Keys of the programs to go on to after this one.
  final List<String> next;
  final int? perWeek;
  final int? minutes;

  /// Null runs on.
  final int? weeks;
  final Deload? deload;
  final List<LibraryPhase> phases;

  /// Test sessions, by session id.
  final Map<String, ProgramTest> tests;
  final List<LibrarySession> sessions;

  /// The oldest app version that can run this program (heart-api#276), as
  /// `[major, minor, patch]`; null for any build that reads the library.
  final List<int>? minApp;

  /// Growth rules as the file writes them: keyed by exercise key, a ladder's
  /// rungs and kinds this build doesn't know included.
  final Map<String, Map> _rules;

  const new _({
    required this.key,
    this.audience,
    this.equipment,
    required this.name,
    this.note,
    this.who,
    this.week,
    this.grows,
    this.misses,
    this.claims = const [],
    this.sources = const [],
    this.safety = const [],
    this.next = const [],
    this.perWeek,
    this.minutes,
    this.weeks,
    this.deload,
    this.phases = const [],
    this.tests = const {},
    required this.sessions,
    this.minApp,
    this._rules = const {},
  });

  /// Whether a build at [version] (`1.15.0`, a build suffix ignored) can run
  /// this program. An unknown version runs only what any build can.
  bool runsOn(String version) {
    final needed = minApp;
    if (needed == null) return true;
    final running = _version(version);
    if (running == null) return false;
    for (final (index, part) in needed.indexed) {
      if (running[index] != part) return running[index] > part;
    }
    return true;
  }

  /// Null for an entry that isn't a program at all. Anything else this build
  /// doesn't know — a key, a rule kind, a group — is passed over, never a
  /// failed read.
  static LibraryProgram? read(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'];
    final name = ContentText.read(raw['name'], translations: raw['i18n']);
    final sessions = [
      for (final session in _list(raw['sessions']))
        if (LibrarySession.read(session) case final LibrarySession session) session,
    ]..sort((a, b) => a.order.compareTo(b.order));
    if (key is! String || name == null || sessions.isEmpty) return null;
    // a version this build can't read is one it can't promise to run: the
    // program goes, as one too new would
    final minApp = switch (raw['minApp']) {
      null => const <int>[],
      final String version => _version(version),
      _ => null,
    };
    if (minApp == null) return null;

    return LibraryProgram._(
      key: key,
      audience: LibraryAudience.of(raw['audience']),
      equipment: LibraryEquipment.of(raw['equipment']),
      name: name,
      note: ContentText.read(raw['note'], translations: raw['noteI18n']),
      who: ContentText.read(raw['who']),
      week: ContentText.read(raw['week']),
      grows: ContentText.read(raw['grows']),
      misses: ContentText.read(raw['misses']),
      claims: [
        for (final claim in _list(raw['why']))
          if (LibraryClaim.read(claim) case final LibraryClaim claim) claim,
      ],
      sources: _strings(raw['sources']),
      safety: _strings(raw['safety']),
      next: _strings(raw['next']),
      perWeek: (raw['perWeek'] as num?)?.toInt(),
      minutes: (raw['minutes'] as num?)?.toInt(),
      weeks: (raw['weeks'] as num?)?.toInt(),
      deload: switch (raw['deload']) {
        final Map deload => _tryRead(() => Deload.fromJson(deload)),
        _ => null,
      },
      phases: [
        for (final phase in _list(raw['phases']))
          if (phase case {'sessions': final List sessions})
            LibraryPhase(
              name: ContentText.read(phase['name']),
              sessions: _strings(sessions),
              cycles: (phase['cycles'] as num?)?.toInt(),
            ),
      ],
      tests: {
        if (raw['tests'] case final Map tests)
          for (final MapEntry(:key, :value) in tests.entries)
            if (value is Map)
              if (_tryRead(() => ProgramTest.fromJson(value)) case final ProgramTest test) '$key': test,
      },
      sessions: sessions,
      minApp: switch (minApp) {
        [] => null,
        _ => minApp,
      },
      rules: {
        if (raw['rules'] case final Map rules)
          for (final MapEntry(:key, :value) in rules.entries)
            if (value is Map) '$key': value,
      },
    );
  }

  /// The library keys of the exercises whose growth rule the file states.
  Iterable<String> get ruled => _rules.keys;

  /// The claims that sit on the part [on] names.
  Iterable<LibraryClaim> claimsAbout(String on, {String? session, String? exercise}) {
    return claims.where((claim) => claim.isAbout(on, session: session, exercise: exercise));
  }

  /// The program as the user's own: a [Program] remembering this one as its
  /// source, and its sessions as templates, all under fresh ids, so the same
  /// program can be started twice and never shares a row with anyone else's
  /// copy. Every library key becomes the id [resolve] finds for it: the rules,
  /// a ladder's rungs, a share's `of`. Phases and tests follow the sessions to
  /// their new ids, and so do an occurrence's own rule and a share of one
  /// occurrence's base (`ofSlot`, heart-api#256, #257) the template exercises.
  ///
  /// What [resolve] doesn't know — an older catalog against a newer file — is
  /// left out: the exercise, its rule, a rung (a ladder left with one is no
  /// ladder), and a share of it, which would otherwise read as a share of
  /// the set's own exercise. An occurrence left out takes its own rule with
  /// it, and a share of its base falls back to its exercise's. A session left with nothing goes too, and null
  /// is a program with no sessions left at all.
  ///
  /// The sessions are numbered from [order], and filed under [folder].
  ({Program program, List<Template> sessions})? copy({
    required Exercise? Function(String key) resolve,
    required String tag,
    TemplateFolder? folder,
    int order = 0,
  }) {
    String? idOf(Object? key) => switch (key) {
      final String key => resolve(key)?.id,
      _ => null,
    };

    // every occurrence the copy keeps, by its id in the file: a share of one
    // may name an occurrence in a later session
    final slots = <String, String>{
      for (final session in sessions)
        for (final exercise in session._exercises)
          if ((exercise['id'], LibrarySession._keyOf(exercise)) case (final String id, final String key))
            if (resolve(key) != null) id: uuidV7(),
    };

    Map? target(Object? raw) {
      final mapped = switch (raw) {
        {'of': final Object of} => switch (idOf(of)) {
          final String id => {...raw, 'of': id},
          null => {...raw}..removeWhere((key, _) => key == 'of' || key == 'share' || key == 'ofSlot'),
        },
        final Map raw => raw,
        _ => null,
      };
      return switch (mapped) {
        {'ofSlot': final Object slot} => switch (slots[slot]) {
          final String id => {...mapped, 'ofSlot': id},
          null => {...mapped}..remove('ofSlot'),
        },
        _ => mapped,
      };
    }

    final ids = <String, String>{};
    final templates = <Template>[];
    for (final session in sessions) {
      final exercises = [
        for (final exercise in session._exercises)
          if (LibrarySession._keyOf(exercise) case final String key)
            if (resolve(key) case final Exercise resolved)
              {
                ...exercise,
                'id': slots[exercise['id']] ?? uuidV7(),
                'exercise': resolved.toMap(),
                'sets': [
                  for (final set in _list(exercise['sets']))
                    if (set is Map) {...set, 'id': uuidV7(), 'target': target(set['target'])},
                ],
              },
      ];
      if (exercises.isEmpty) continue;
      final id = ids[session.id] = uuidV7();
      templates.add(
        Template.fromJson({
          'id': id,
          'name': session.name.of(tag),
          'order': order + templates.length,
          'folder': folder?.toMap(),
          'note': session.note?.of(tag),
          'exercises': exercises,
        }),
      );
    }
    if (templates.isEmpty) return null;

    final rules = <String, Map>{};
    for (final MapEntry(:key, value: rule) in _rules.entries) {
      // an occurrence's own rule, else an exercise's
      final id = slots[key] ?? idOf(key);
      if (id == null) continue;
      switch (rule) {
        case {'rungs': final List rungs}:
          final ids = [for (final rung in rungs) ?idOf(rung)];
          if (ids.length >= 2) rules[id] = {...rule, 'rungs': ids};
        default:
          rules[id] = rule;
      }
    }

    final phases = [
      for (final phase in this.phases)
        if ([for (final session in phase.sessions) ?ids[session]] case final List<String> sessions
            when sessions.isNotEmpty)
          {'name': ?phase.name?.of(tag), 'sessions': sessions, 'cycles': ?phase.cycles},
    ];

    final program = Program.fromJson({
      'name': name.of(tag),
      'note': note?.of(tag),
      'source': key,
      'perWeek': perWeek,
      'weeks': weeks,
      'deload': deload?.toMap(),
      'phases': phases,
      'tests': {
        for (final MapEntry(key: session, value: test) in tests.entries)
          if (ids[session] case final String id) id: test.toMap(),
      },
      'rules': rules,
    });
    return (program: program, sessions: templates);
  }
}

/// A safety note a program shows, as the library words it.
final class LibrarySafety {
  final String key;
  final ContentText text;

  /// Keys into [ProgramLibrary.source].
  final List<String> sources;

  const new({required this.key, required this.text, this.sources = const []});

  static LibrarySafety? read(String key, Object? raw) {
    if (raw is! Map) return null;
    return switch (ContentText.read(raw['text'])) {
      final ContentText text => LibrarySafety(key: key, text: text, sources: _strings(raw['sources'])),
      null => null,
    };
  }
}

/// The library file read whole: its programs, and the sources and safety
/// notes they name.
final class LibraryContent {
  final List<LibraryProgram> programs;
  final Map<String, LibrarySource> sources;
  final Map<String, LibrarySafety> safety;

  const new({required this.programs, this.sources = const {}, this.safety = const {}});

  /// Null for a file with no program this build can read. One entry it can't
  /// read costs that entry, never the file.
  static LibraryContent? read(Object? raw) {
    if (raw is! Map) return null;
    final programs = [
      for (final program in _list(raw['programs']))
        if (_tryRead(() => LibraryProgram.read(program)) case final LibraryProgram program) program,
    ];
    if (programs.isEmpty) return null;
    return LibraryContent(
      programs: programs,
      sources: {
        if (raw['sources'] case final Map sources)
          for (final MapEntry(:key, :value) in sources.entries)
            if (_tryRead(() => LibrarySource.read('$key', value)) case final LibrarySource source) '$key': source,
      },
      safety: {
        if (raw['safety'] case final Map notes)
          for (final MapEntry(:key, :value) in notes.entries)
            if (_tryRead(() => LibrarySafety.read('$key', value)) case final LibrarySafety note) '$key': note,
      },
    );
  }
}

/// Heart's ready-made programs (#352, #162): content from the CDN, kept on
/// the device between launches, and read again only when the CDN has a newer
/// copy than the one kept.
///
/// Nobody's data, and public: the same file for every account, kept through
/// sign-out. Until the file is first published every read fails, and the
/// library is simply not [available] — no error, no empty page.
class ProgramLibrary with ChangeNotifier {
  late final StaticContent<LibraryContent> _file;

  /// The running build's version, read on use: it arrives after this is made.
  final String Function() _appVersion;

  new({
    required Future<({String body, String? etag})?> Function({String? etag}) fetch,
    required Future<({String body, String? etag})?> Function(String key) read,
    required Future<void> Function(String key, {required String body, String? etag}) store,
    void Function(dynamic error, {dynamic stacktrace})? onError,
    String Function()? appVersion,
  }) : _appVersion = appVersion ?? (() => '') {
    _file = StaticContent(
      key: 'static/programs',
      fetch: fetch,
      read: read,
      store: store,
      parse: LibraryContent.read,
      onChanged: notifyListeners,
      onError: onError,
    );
  }

  static ProgramLibrary of(BuildContext context) => Provider.of<ProgramLibrary>(context, listen: false);

  static ProgramLibrary watch(BuildContext context) => Provider.of<ProgramLibrary>(context, listen: true);

  LibraryContent? get _content => _file.value;

  /// Whether there is a library to show.
  bool get available => _content != null;

  /// Every program this build can run, in the file's order. One newer than
  /// the build is left out rather than offered as an update: an older build
  /// has nothing to say about it but "update", which is noise until the user
  /// updates anyway (heart-api#276).
  List<LibraryProgram> get programs => UnmodifiableListView(_runnable);

  LibraryProgram? lookup(String key) => _runnable.where((program) => program.key == key).firstOrNull;

  Iterable<LibraryProgram> get _runnable {
    final version = _appVersion();
    return (_content?.programs ?? const <LibraryProgram>[]).where((program) => program.runsOn(version));
  }

  LibrarySource? source(String key) => _content?.sources[key];

  LibrarySafety? safety(String key) => _content?.safety[key];

  /// Reads the library once a launch, however many places ask: see
  /// [StaticContent.ensure].
  Future<void> ensure() => _file.ensure();
}

List<Object?> _list(Object? raw) => switch (raw) {
  final List list => list,
  _ => const [],
};

List<String> _strings(Object? raw) => [..._list(raw).whereType<String>()];

/// `1.15.0` (and `1.15.0+212`) as `[1, 15, 0]`; null for anything else.
List<int>? _version(String raw) {
  return switch (RegExp(r'^(\d+)\.(\d+)\.(\d+)(\+.*)?$').firstMatch(raw)) {
    final RegExpMatch match => [
      for (final group in [1, 2, 3]) int.parse(match.group(group)!),
    ],
    null => null,
  };
}

/// [read], or null where it throws: one entry this build can't read costs that
/// entry alone.
T? _tryRead<T>(T? Function() read) {
  try {
    return read();
  } on ArgumentError {
    return null;
  } on TypeError {
    return null;
  } on FormatException {
    return null;
  }
}
