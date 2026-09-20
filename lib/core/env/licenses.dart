import 'package:flutter/foundation.dart';

/// Attribution that Flutter's licence page cannot find on its own.
///
/// [LicenseRegistry] collects the `LICENSE` file of every package in the
/// dependency graph, and nothing else. `flutter_body_atlas` ships its own
/// BSD licence there, so that much shows up — but the muscle artwork inside
/// it is someone else's work under CC BY 4.0, and that credit lives in the
/// package's `CREDITS.md`, which the registry never reads. Without this the
/// attribution never reaches a user, and attribution is the whole of what
/// CC BY asks for.
///
/// Fix it upstream too when the package is next cut: the same text in
/// `flutter_body_atlas`' own `LICENSE` would reach every consumer, not just
/// this app.
void registerLicenses() {
  LicenseRegistry.addLicense(
    () => Stream.value(
      const LicenseEntryWithLineBreaks(
        ['flutter_body_atlas'],
        'The anatomical muscle artwork in this package is based on work by '
        'Ryan Graves, used under the Creative Commons Attribution 4.0 '
        'International licence (CC BY 4.0).\n'
        '\n'
        'Source: https://www.figma.com/community/file/1320468164820924031\n'
        'Licence: https://creativecommons.org/licenses/by/4.0/\n'
        '\n'
        'Changes were made: the SVG structure and element identifiers were '
        'reworked to support interactive hit-testing and stable ids, with '
        'minor edits and optimisations alongside.',
      ),
    ),
  );
}
