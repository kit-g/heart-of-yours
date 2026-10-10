import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:heart/presentation/routes/workout/workout.dart';
import 'package:heart_language/heart_language.dart';

/// A duplicated template's name (#262): "(copy)", numbered when taken, so two
/// copies of one template can be told apart on screen and by voice.
void main() {
  final en = lookupL(const Locale('en'));
  final ru = lookupL(const Locale('ru'));

  test('the first copy is "(copy)"', () {
    expect(templateCopyName(en, 'Push Day', taken: ['Push Day']), 'Push Day (copy)');
  });

  test('a taken name gets the next free number', () {
    expect(templateCopyName(en, 'Push Day', taken: ['Push Day', 'Push Day (copy)']), 'Push Day (copy 2)');
    expect(
      templateCopyName(en, 'Push Day', taken: ['Push Day', 'Push Day (copy)', 'Push Day (copy 2)', null]),
      'Push Day (copy 3)',
    );
  });

  test('in the device\'s language', () {
    expect(templateCopyName(ru, 'Жим', taken: ['Жим', 'Жим (копия)']), 'Жим (копия 2)');
  });
}
