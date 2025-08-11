## Heart Language

Shared localization strings and helpers for the Heart app. This package provides:
- A typed L localization class with all user‑facing strings used across the app.
- A LocalizationsDelegate (LocsDelegate) and intl wiring for loading messages.
- Generated message lookups for supported locales.

### Why this package exists
- Centralize copy in one place so UI code stays clean and consistent.
- Enable translation to multiple locales with the Intl package and ARB files.
- Keep localization independent from UI/state packages; any app target can consume the same strings.

### What it includes
- L class exposing getters for all strings (labels, tooltips, errors, etc.).
- LocsDelegate to plug into Flutter's localization system.
- Generated messages under lib/l10n (messages_*.dart) and Intl initialization glue.
- Currently supported locales: en, fr

### Relationship to other packages
- heart_models: no direct dependency; strings reference concepts defined there (exercises, workouts).
- heart_state: UI/state modules call L.of(context) to render user‑facing text and hints.
- heart_api/heart_db: do not depend on localization; they remain transport/persistence only.

This separation keeps business logic free of copy and makes language changes safe and testable.

### Quick start
1. Add heart_language as a dependency within the monorepo.
2. Register delegates and supported locales in your MaterialApp:

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:heart_language/heart_language.dart';

MaterialApp(
  localizationsDelegates: const [
    LocsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('en'),
    Locale('fr'),
  ],
  // ...
);
```

3. Use strings in widgets:

```dart
Text(L.of(context).motto); // "Every beat counts."
TextButton(onPressed: ..., child: Text(L.of(context).toDarkMode));
```

### Adding or updating strings
- Add a new getter to L in lib/src/locales.dart using Intl.message with a unique name and description.
- Provide translations in ARB files (if you maintain ARBs) and regenerate message code.

Generation helpers (from comments in locales.dart):
- Extract to ARB:
  flutter pub pub run intl_translation:extract_to_arb --output-dir=lib/l10n lib/src/locales.dart
- Generate from ARB (example for en and fr):
  flutter pub pub run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/src/locales.dart lib/l10n/intl_en.arb lib/l10n/intl_fr.arb

Note: This package already contains generated files (messages_*.dart). If you are not adding locales, you typically do not need to run generation.

### Design notes
- Typed accessors avoid stringly‑typed keys and give IDE auto‑complete.
- Descriptions on Intl.message improve translator context.
- Delegate only reloads when locale changes; no runtime I/O.

### Versioning and installation
- Follows the monorepo's Dart/Flutter constraints; see pubspec for SDK bounds.
- Internal to the Heart monorepo (publish_to: none). Depend via path or workspace resolution within this repo.

### Testing
- Widget tests can verify copy renders by pumping widgets and calling L.of(context).key.
- Keep copy logic simple; avoid business logic in localization getters.

### License and contributions
This package is internal to the Heart project. File issues and contributions within this repository.
