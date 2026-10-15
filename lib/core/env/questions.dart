import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:heart/presentation/questions/answers.dart';
import 'package:heart_db/heart_db.dart';
import 'package:heart_language/heart_language.dart';
import 'package:heart_state/heart_state.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:logging/logging.dart';

final _logger = Logger('Questions');

/// The headless engine's half of the assistant's questions (#288): the
/// `heart/questions` channel, answered from the device's mirror in the
/// device's language. The native side runs this entrypoint in an engine of
/// its own — no widgets, no Firebase, no session of the app's — and asks
/// one question at a time:
///
///     ask: {question, userId?, locale, exerciseId?, template?} → String
///
/// Everything it opens is opened once and kept while the engine lives.
Future<void> runQuestions() async {
  WidgetsFlutterBinding.ensureInitialized();
  Future<LocalDatabase>? db;
  Future<Preferences>? prefs;

  const MethodChannel('heart/questions').setMethodCallHandler((call) async {
    if (call.method != 'ask') throw MissingPluginException('heart/questions has no ${call.method}');
    final args = switch (call.arguments) {
      Map map => map,
      _ => const <Object?, Object?>{},
    };
    final started = DateTime.now();
    try {
      db ??= LocalDatabase.init();
      prefs ??= _preferences(args['locale'] as String?);
      final locale = _locale(args['locale'] as String?);
      await initializeDateFormatting(locale.toString());
      final answers = Answers(db: await db!, l: lookupL(locale), prefs: await prefs!);
      final userId = args['userId'] as String?;
      final answer = await switch (args['question']) {
        'record' => answers.record(userId, args['exerciseId'] as String),
        'lastExercise' => answers.lastExercise(userId, args['exerciseId'] as String),
        'lastTemplate' => answers.lastTemplate(userId, args['template'] as String),
        'weekly' => answers.weekly(userId),
        final other => throw ArgumentError.value(other, 'question'),
      };
      _logger.info('${args['question']} answered in ${DateTime.now().difference(started).inMilliseconds} ms');
      return answer;
    } catch (e, stacktrace) {
      _logger.warning('${args['question']} could not be answered', e, stacktrace);
      rethrow;
    }
  });
}

/// The store the app keeps, read with the device's own region: unset, the
/// units and the first day of the week (#339) are the region's, as they are in
/// the app — the language [_locale] settles on may have dropped the region.
Future<Preferences> _preferences(String? tag) async {
  final prefs = Preferences();
  await prefs.init(locale: _region(tag));
  return prefs;
}

/// [tag] ("en-US", "zh-Hans-CN") as a locale that keeps its region, if it has one.
Locale? _region(String? tag) {
  if (tag == null) return null;
  final [language, ...rest] = tag.split(RegExp('[-_]'));
  return Locale(language, rest.where((part) => part.length == 2).firstOrNull);
}

/// The device's locale, as the native side names it ("fr-CA", "ru"), in one
/// of the app's languages — or English for one the app does not speak.
Locale _locale(String? tag) {
  final parts = (tag ?? 'en').split(RegExp('[-_]'));
  final candidate = Locale(parts.first, parts.length > 1 ? parts[1] : null);
  final supported = L.supportedLocales;
  return supported.firstWhere(
    (locale) => locale == candidate,
    orElse: () => supported.firstWhere(
      (locale) => locale.languageCode == candidate.languageCode,
      orElse: () => const Locale('en'),
    ),
  );
}
