import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

Future<L> _load(Locale locale) async {
  await initializeDateFormatting(locale.toString());
  return L.delegate.load(locale);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every supported locale loads', () async {
    for (final locale in L.supportedLocales) {
      final l = await _load(locale);
      expect(l.localeName, isNotEmpty, reason: '$locale');
    }
  });

  test('defaultWorkoutName names the current part of the day', () async {
    for (final locale in L.supportedLocales) {
      final l = await _load(locale);
      final now = DateTime.now();
      final when = intl.DateFormat('EEE, MMM d', l.localeName).format(now);
      final expected = switch (now.hour) {
        >= 5 && < 12 => l.morningWorkout(when),
        >= 12 && < 17 => l.afternoonWorkout(when),
        >= 17 && < 21 => l.eveningWorkout(when),
        _ => l.nightWorkout(when),
      };
      expect(l.defaultWorkoutName(), expected, reason: '$locale');
      expect(l.defaultWorkoutName(), contains(when), reason: '$locale');
    }
  });

  test('ru is actually translated, not a copy of en', () async {
    final en = await _load(const Locale('en'));
    final ru = await _load(const Locale('ru'));
    expect(ru.morningWorkout('x'), isNot(en.morningWorkout('x')));
  });
}
