import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';

Directory _root() {
  for (final root in [Directory.current, Directory('${Directory.current.path}/shared/heart_language')]) {
    if (File('${root.path}/lib/l10n/intl_en.arb').existsSync()) return root;
  }
  throw StateError('Cannot find heart_language');
}

/// gen-l10n turns an ICU `=1` into Intl's `one`, and Intl answers `one` by the
/// locale's plural rule, not by the number: Russian's `one` is also 21, 31,
/// 41…, French's is also 0. A `=1` branch that spells out "1" therefore says
/// "1" for those too.
void main() {
  test('no Russian or French plural spells out the 1 its branch is chosen for', () {
    final literal = RegExp(r'=1\{[^{}]*(?<![\d{])1(?![\d}])');
    for (final locale in ['ru', 'fr']) {
      final arb = File('${_root().path}/lib/l10n/intl_$locale.arb');
      final strings = (jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>).entries.where(
        (entry) => !entry.key.startsWith('@') && entry.value is String,
      );
      final offenders = [
        for (final MapEntry(:key, :value) in strings)
          if (literal.hasMatch(value as String)) key,
      ];
      expect(offenders, isEmpty, reason: '$locale: write one{{count} …}, not =1{1 …}');
    }
  });

  test('Russian counts of 21 and French counts of 0 say their number', () {
    final ru = lookupL(const Locale('ru'));
    expect(ru.programWeeks(21), contains('21'));
    expect(ru.goEasySessionMarked(21), contains('21'));
    expect(ru.upsyncSkipped(21), contains('21'));
    expect(ru.askWeekly(21), contains('21'));
    expect(ru.libraryPerWeek(21), contains('21'));

    final fr = lookupL(const Locale('fr'));
    expect(fr.lensSets(0), contains('0'));
    expect(fr.lensSessions(0), contains('0'));
    expect(fr.workoutRecords(0), contains('0'));
    expect(fr.programWeeks(0), contains('0'));
  });
}
