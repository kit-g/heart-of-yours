import 'dart:collection';

import 'package:heart_models/heart_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'program_library.dart' show ContentText;
import 'static_content.dart';

/// Which exercises a predicate of the go-easy map names: every key it has
/// holds, each by any of its values. Keys are the exercise library's
/// fields — `groups`, `axialLoad`, `impact` and `stability` from its movement
/// data, and `category`.
///
/// Only library exercises carry movement data, so an exercise without it —
/// a custom one — answers a movement key with no, and can match only by
/// category.
final class ExerciseMatch {
  final Map<String, Set<String>> _values;

  const new _(this._values);

  static const _known = {'groups', 'axialLoad', 'impact', 'stability', 'category'};

  /// Null for a predicate with no key this build knows: one that would
  /// otherwise match every exercise. Keys it doesn't know are left out.
  static ExerciseMatch? read(Object? raw) {
    if (raw is! Map) return null;
    final values = <String, Set<String>>{
      for (final MapEntry(:key, :value) in raw.entries)
        if (_known.contains(key) && value is List) '$key': {...value.whereType<String>()},
    };
    return switch (values.isEmpty) {
      true => null,
      false => ExerciseMatch._(values),
    };
  }

  bool matches(Exercise exercise) {
    final movement = exercise.movement;
    return _values.entries.every((entry) {
      final MapEntry(:key, value: accepted) = entry;
      if (key == 'category') return accepted.contains(exercise.category.value);
      if (movement.isEmpty) return false;
      return switch (key) {
        'groups' => movement.groups.any(accepted.contains),
        'axialLoad' => accepted.contains(movement.axialLoad.value),
        'impact' => accepted.contains(movement.impact.value),
        'stability' => accepted.contains(movement.stability.value),
        _ => false,
      };
    });
  }
}

/// A body area or a movement of the go-easy map.
enum GoEasyKind { area, movement }

/// One thing a user can go easy on: a body area (a knee) or a movement
/// (jumping), what is harder on it, and what is kinder.
final class GoEasyEntry {
  /// Its content key: `knee`, `jumping`. What the user's list holds.
  final String key;
  final GoEasyKind kind;
  final ContentText name;

  /// The neutral marker: "Easier on your knee".
  final ContentText easierOn;

  /// Exercises harder on it: any of these matches.
  final List<ExerciseMatch> harder;

  /// Exercises kinder to it.
  final List<ExerciseMatch> kinder;

  const new({
    required this.key,
    required this.kind,
    required this.name,
    required this.easierOn,
    required this.harder,
    required this.kinder,
  });

  static GoEasyEntry? read(String key, GoEasyKind kind, Object? raw) {
    if (raw is! Map) return null;
    final name = ContentText.read(raw['name']);
    final easierOn = ContentText.read(raw['easierOn']);
    if (name == null || easierOn == null) return null;
    List<ExerciseMatch> matches(Object? list) => [
      if (list case final List list)
        for (final each in list)
          if (ExerciseMatch.read(each) case final ExerciseMatch match) match,
    ];
    return GoEasyEntry(
      key: key,
      kind: kind,
      name: name,
      easierOn: easierOn,
      harder: matches(raw['easier']),
      kinder: matches(raw['prefer']),
    );
  }

  bool isHarderOn(Exercise exercise) => harder.any((match) => match.matches(exercise));

  bool isKinderTo(Exercise exercise) => kinder.any((match) => match.matches(exercise));
}

/// The go-easy map read whole: its copy, and the areas and movements in the
/// file's order.
final class GoEasyContent {
  final ContentText? title;
  final ContentText? explainer;
  final ContentText? footer;
  final List<GoEasyEntry> areas;
  final List<GoEasyEntry> movements;

  const new({this.title, this.explainer, this.footer, required this.areas, required this.movements});

  /// Null for a file with nothing this build can read. An entry it can't
  /// read costs that entry, never the file; unknown keys are ignored.
  static GoEasyContent? read(Object? raw) {
    if (raw is! Map) return null;
    List<GoEasyEntry> entries(Object? map, GoEasyKind kind) => [
      if (map case final Map map)
        for (final MapEntry(:key, :value) in map.entries)
          if (GoEasyEntry.read('$key', kind, value) case final GoEasyEntry entry) entry,
    ];
    final areas = entries(raw['areas'], .area);
    final movements = entries(raw['movements'], .movement);
    if (areas.isEmpty && movements.isEmpty) return null;
    final copy = switch (raw['copy']) {
      final Map copy => copy,
      _ => const {},
    };
    return GoEasyContent(
      title: ContentText.read(copy['title']),
      explainer: ContentText.read(copy['explainer']),
      footer: ContentText.read(copy['footer']),
      areas: areas,
      movements: movements,
    );
  }
}

/// Things to go easy on (#396): a private list of body areas and movements,
/// and what Heart makes of it — a neutral marker on an exercise harder on
/// something listed, and kinder swaps for it. Never a block.
///
/// The map comes from the content CDN, the same for everyone. The list is
/// health-shaped and lives on this phone only, like health samples
/// (`docs/2026-09-05.health-data.md`): nothing here has a remote leg, and the
/// export, the sign-in replay and analytics never read it. Errors go to the
/// caller's redacting reporter, since a database error carries what it bound.
class GoEasy with ChangeNotifier {
  late final StaticContent<GoEasyContent> _file;
  final Future<Set<String>> Function(String userId) _read;
  final Future<void> Function(String userId, Set<String> keys) _store;
  final void Function(dynamic error, {dynamic stacktrace})? onError;

  new({
    required Future<({String body, String? etag})?> Function({String? etag}) fetch,
    required Future<({String body, String? etag})?> Function(String key) readContent,
    required Future<void> Function(String key, {required String body, String? etag}) storeContent,
    required this._read,
    required this._store,
    this.onError,
  }) {
    _file = StaticContent(
      key: 'static/go-easy',
      fetch: fetch,
      read: readContent,
      store: storeContent,
      parse: GoEasyContent.read,
      onChanged: notifyListeners,
      onError: onError,
    );
  }

  static GoEasy of(BuildContext context) => Provider.of<GoEasy>(context, listen: false);

  static GoEasy watch(BuildContext context) => Provider.of<GoEasy>(context, listen: true);

  String? _userId;
  Set<String> _keys = const {};

  /// The signed-in uid: the list is read again for it, and forgotten in
  /// memory when there is none.
  set userId(String? value) {
    if (value == _userId) return;
    _userId = value;
    _keys = const {};
    notifyListeners();
    if (value case final String id) _load(id);
  }

  Future<void> _load(String userId) async {
    try {
      final keys = await _read(userId);
      if (userId != _userId) return;
      _keys = keys;
      notifyListeners();
    } catch (e, s) {
      onError?.call(e, stacktrace: s);
    }
  }

  /// Reads the map once a launch: see [StaticContent.ensure].
  Future<void> ensure() => _file.ensure();

  GoEasyContent? get content => _file.value;

  /// Whether there is a map to choose from. Until it is published there is
  /// nothing to ask, mark or suggest.
  bool get available => content != null;

  /// What the user listed, by key, as far as the map still knows it.
  Set<String> get keys => UnmodifiableSetView(_keys);

  /// Every area and movement of the map, areas first, in the map's order:
  /// what a program's constraint (#355) is chosen from.
  List<GoEasyEntry> get entries => [...?content?.areas, ...?content?.movements];

  /// The map's entry for [key], when the map is published and still has it.
  /// A program's constraint is read through here, never through [keys]: the
  /// user's list and a program's constraint are separate things.
  GoEasyEntry? entryFor(String? key) => entries.where((entry) => entry.key == key).firstOrNull;

  /// The listed entries the map knows, areas first, in the map's order.
  List<GoEasyEntry> get listed => [
    for (final entry in entries)
      if (_keys.contains(entry.key)) entry,
  ];

  /// Makes [keys] the user's whole list, on this phone only.
  Future<void> set(Set<String> keys) async {
    final userId = _userId;
    if (userId == null) return;
    final before = _keys;
    _keys = {...keys};
    notifyListeners();
    try {
      await _store(userId, _keys);
    } catch (e, s) {
      _keys = before;
      notifyListeners();
      onError?.call(e, stacktrace: s);
    }
  }

  /// The listed entries [exercise] is harder on; empty for none, and always
  /// empty with nothing listed or no map.
  List<GoEasyEntry> harderOn(Exercise exercise) => [
    for (final entry in listed)
      if (entry.isHarderOn(exercise)) entry,
  ];

  /// Kinder swaps for [exercise] among [candidates], harder on nothing
  /// listed: exercises of the same movement pattern first, then ones the map
  /// calls kinder to what [exercise] is harder on and that work the same
  /// target — a lunge on a knee has few kinder lunges, but a bridge works the
  /// legs too. Within each, the kinder and then the closest by movement come
  /// first. At most [limit].
  List<Exercise> kinderSwaps(Exercise exercise, Iterable<Exercise> candidates, {int limit = 5}) {
    final listed = this.listed;
    final concerns = [
      for (final entry in listed)
        if (entry.isHarderOn(exercise)) entry,
    ];
    if (concerns.isEmpty) return const [];

    final movement = exercise.movement;
    bool samePattern(Exercise candidate) => !movement.isEmpty && movement.sharesPatternWith(candidate.movement);
    int kindness(Exercise candidate) => concerns.where((entry) => entry.isKinderTo(candidate)).length;
    int distance(Exercise candidate) => switch (movement.isEmpty || candidate.movement.isEmpty) {
      true => 0,
      false => movement.distanceTo(candidate.movement),
    };

    final swaps = [
      for (final candidate in candidates)
        if (candidate.id != exercise.id &&
            !candidate.isArchived &&
            !listed.any((entry) => entry.isHarderOn(candidate)) &&
            (samePattern(candidate) || (kindness(candidate) > 0 && candidate.target == exercise.target)))
          candidate,
    ];
    int byPatternFirst(Exercise candidate) => switch (samePattern(candidate)) {
      true => 0,
      false => 1,
    };
    swaps.sort((a, b) {
      final byPattern = byPatternFirst(a).compareTo(byPatternFirst(b));
      if (byPattern != 0) return byPattern;
      final byKindness = kindness(b).compareTo(kindness(a));
      if (byKindness != 0) return byKindness;
      return distance(a).compareTo(distance(b));
    });
    return swaps.take(limit).toList();
  }
}
