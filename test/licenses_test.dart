import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart/core/env/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every bundled font and the body atlas artwork reach the licence page', () async {
    registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((each) => each.packages).toSet();

    expect(
      packages,
      containsAll([
        'DM Sans',
        'Golos Text',
        'IBM Plex Sans',
        'Lato',
        'Literata',
        'Noto Sans',
        'Onest',
        'Rubik',
        'Unbounded',
        'flutter_body_atlas',
      ]),
    );

    final lato = entries.firstWhere((each) => each.packages.contains('Lato'));
    final text = lato.paragraphs.map((each) => each.text).join('\n');
    expect(text, contains('SIL Open Font License'));
    expect(text, contains('Lukasz Dziedzic'));
  });
}
