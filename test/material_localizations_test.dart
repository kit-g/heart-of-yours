import 'package:flutter_test/flutter_test.dart';
import 'package:heart_language/heart_language.dart';
import 'package:material_ui/material_ui.dart';

/// material_ui's widgets read material_ui's MaterialLocalizations. gen-l10n's
/// `L.localizationsDelegates` only carries flutter_localizations' — the
/// framework's type — and MaterialApp's built-in fallback speaks English only.
/// So in any other language there are none at all, and every back button,
/// dialog and date picker that asks for them throws. heart_language's
/// `localizationsDelegates` adds material_ui's and cupertino_ui's.
void main() {
  Future<MaterialLocalizations?> materialLocalizations(
    WidgetTester tester,
    List<LocalizationsDelegate<dynamic>> delegates,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: L.supportedLocales,
        localizationsDelegates: delegates,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
  }

  testWidgets('the generated list alone leaves material_ui with nothing in Russian', (tester) async {
    expect(await materialLocalizations(tester, L.localizationsDelegates), isNull);
    // the "locale not supported by all delegates" warning MaterialApp reports
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('heart_language\'s list translates it', (tester) async {
    final localizations = await materialLocalizations(tester, localizationsDelegates);
    expect(localizations?.cancelButtonLabel, isNot('Cancel'));
  });
}
