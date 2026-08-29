import 'package:flutter/material.dart';

/// The app's own design vocabulary — every color the UI is allowed to use.
///
/// A preset is a hand-tuned [Tokens] pair (one per brightness); nothing is
/// derived at runtime, and Material's tonal roles are only a compatibility
/// mapping (see [Tokens.colorScheme]) for widgets the theme does not cover
/// explicitly.
class Tokens {
  final Brightness brightness;

  /// The page itself — scaffolds, app bars, the space between things.
  final Color ground;

  /// Elevated planes the app puts in front of the ground: cards, sheets,
  /// dialogs. In light this is white — never greyer than the ground — with
  /// [border] doing the separating.
  final Color surface;

  /// Inset controls that must read as "a place to put something": inputs,
  /// chips, quiet buttons. The one tone allowed to sit *below* the ground.
  final Color fill;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text — metadata, captions, unselected controls.
  final Color muted;

  /// Pending and disabled things; quieter than [muted].
  final Color faint;

  /// Hairlines and control outlines.
  final Color border;

  /// The brand color, used as a fill: primary actions, completion marks.
  final Color accent;

  /// Text and icons sitting on an [accent] fill.
  final Color onAccent;

  /// The accent as a *text* color on [ground] — the same hue kept legible,
  /// which on a light ground means darker than [accent], never the fill
  /// color itself.
  final Color accentInk;

  final Color destructive;

  const new({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.border,
    required this.accent,
    required this.onAccent,
    required this.accentInk,
    required this.destructive,
  });

  static const forgeDark = Tokens(
    brightness: .dark,
    ground: Color(0xFF0F100D),
    surface: Color(0xFF191B15),
    fill: Color(0xFF232720),
    ink: Color(0xFFF1F2E9),
    muted: Color(0xFF9BA092),
    faint: Color(0xFF6F746A),
    border: Color(0xFF2A2D24),
    accent: Color(0xFFD4F547),
    onAccent: Color(0xFF121408),
    accentInk: Color(0xFFD4F547),
    destructive: Color(0xFFFF6B57),
  );

  // Light sets are WHITE-grounded: the page is white, surfaces stay white
  // with borders doing the separating, and `fill` is the only tone below
  // the ground. Never darken the ground to create contrast — that just
  // trades one grey wash for another. `muted` clears WCAG AA (4.5:1) on
  // the ground; keep it there when tuning.
  static const forgeLight = Tokens(
    brightness: .light,
    ground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF2F3E8),
    ink: Color(0xFF14160D),
    muted: Color(0xFF5B6055),
    faint: Color(0xFF969B8C),
    border: Color(0xFFDEE1D0),
    accent: Color(0xFFD4F547),
    onAccent: Color(0xFF121408),
    accentInk: Color(0xFF55650F),
    destructive: Color(0xFFB23A28),
  );

  // Ink: paper and ink with a cobalt accent — light-first the way Forge is
  // dark-first. Warm neutrals, no green undertone. Cobalt rather than the
  // canvas's vermilion so the accent can never be confused with
  // [destructive].
  static const inkLight = Tokens(
    brightness: .light,
    ground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF4F1EA),
    ink: Color(0xFF1A1815),
    muted: Color(0xFF5D584E),
    faint: Color(0xFF948F85),
    border: Color(0xFFE2DED4),
    accent: Color(0xFF1F4EC8),
    onAccent: Color(0xFFFFFFFF),
    accentInk: Color(0xFF1B43A8),
    destructive: Color(0xFF9E2B25),
  );

  static const inkDark = Tokens(
    brightness: .dark,
    ground: Color(0xFF141311),
    surface: Color(0xFF1E1C19),
    fill: Color(0xFF2A2721),
    ink: Color(0xFFF2F0EA),
    muted: Color(0xFFA29D93),
    faint: Color(0xFF6F6B63),
    border: Color(0xFF302D27),
    accent: Color(0xFF93ADFF),
    onAccent: Color(0xFF0F1526),
    accentInk: Color(0xFF93ADFF),
    destructive: Color(0xFFFF7A66),
  );

  // Utility: the calm tool — cool neutrals where Forge is green-black and
  // Ink is warm paper, forest green for the accent, nothing raised above
  // its station.
  static const utilityLight = Tokens(
    brightness: .light,
    ground: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    fill: Color(0xFFF2F4F5),
    ink: Color(0xFF16181D),
    muted: Color(0xFF575D66),
    faint: Color(0xFF949AA4),
    border: Color(0xFFE1E4E8),
    accent: Color(0xFF2F7A5F),
    onAccent: Color(0xFFFFFFFF),
    accentInk: Color(0xFF27664E),
    destructive: Color(0xFFC03A2E),
  );

  static const utilityDark = Tokens(
    brightness: .dark,
    ground: Color(0xFF101214),
    surface: Color(0xFF1A1D21),
    fill: Color(0xFF252A2F),
    ink: Color(0xFFECEEF0),
    muted: Color(0xFF9AA1AB),
    faint: Color(0xFF6A7078),
    border: Color(0xFF2C3138),
    accent: Color(0xFF64C79B),
    onAccent: Color(0xFF0E1F18),
    accentInk: Color(0xFF64C79B),
    destructive: Color(0xFFFF7365),
  );

  /// Maps the vocabulary onto Material roles so widgets without an explicit
  /// component theme still land on token colors. The mapping is the whole
  /// contract: no tonal palettes, no seed derivation.
  ColorScheme colorScheme() {
    final onDestructive = switch (brightness) {
      .dark => onAccent,
      .light => surface,
    };
    return ColorScheme(
      brightness: brightness,
      // accentInk, not accent: primary is what widgets draw *lines* with —
      // chart bars, sliders, progress, selection — and the raw accent
      // vanishes against a light ground. Fills keep the raw accent via
      // tertiaryContainer below.
      primary: accentInk,
      onPrimary: switch (brightness) {
        .dark => onAccent,
        .light => surface,
      },
      primaryContainer: surface,
      onPrimaryContainer: ink,
      secondary: accentInk,
      onSecondary: switch (brightness) {
        .dark => onAccent,
        .light => surface,
      },
      secondaryContainer: border,
      onSecondaryContainer: ink,
      tertiary: accentInk,
      // The popup menu theme reads its background from this role.
      onTertiary: surface,
      // PrimaryButton's default fill: the accent, worn as a fill with dark
      // content, never as a text color.
      tertiaryContainer: accent,
      onTertiaryContainer: onAccent,
      error: destructive,
      onError: onDestructive,
      surface: ground,
      onSurface: ink,
      surfaceContainerLowest: ground,
      surfaceContainerLow: surface,
      surfaceContainer: fill,
      surfaceContainerHigh: surface,
      surfaceContainerHighest: fill,
      onSurfaceVariant: muted,
      outline: muted,
      outlineVariant: border,
      inverseSurface: ink,
      onInverseSurface: ground,
      inversePrimary: accent,
      surfaceTint: Colors.transparent,
    );
  }
}

/// A theme preset: one identity worn by both brightnesses.
///
/// The enum name is the stored identifier — display names are copy and live
/// in the translations.
enum Preset {
  forge(
    light: Tokens.forgeLight,
    dark: Tokens.forgeDark,
    textFont: 'Onest',
    titleFont: 'Onest',
    displayFont: 'Unbounded',
    // Unbounded runs much wider than a text face: the page title trades
    // size for presence.
    headlineSize: 26,
    headlineWeight: .w700,
  ),
  ink(
    light: Tokens.inkLight,
    dark: Tokens.inkDark,
    textFont: 'IBM Plex Sans',
    titleFont: 'Literata',
    displayFont: 'Literata',
    headlineSize: 30,
    headlineWeight: .w600,
  ),
  // One family carrying everything is the point: the quiet preset.
  utility(
    light: Tokens.utilityLight,
    dark: Tokens.utilityDark,
    textFont: 'Golos Text',
    titleFont: 'Golos Text',
    displayFont: 'Golos Text',
    headlineSize: 28,
    headlineWeight: .w700,
  );

  final Tokens light;
  final Tokens dark;

  /// Everything that reads — body, labels, controls.
  final String textFont;

  /// Page and dialog titles (`titleLarge`) — where a preset may hand
  /// headlines to a second face without shouting everywhere [displayFont]
  /// does.
  final String titleFont;

  /// Headlines and numbers worth a shout, nothing else.
  final String displayFont;

  /// The page-title size and weight, tuned per display face — different
  /// faces fill the same box very differently at one size.
  final double headlineSize;
  final FontWeight headlineWeight;

  new({
    required this.light,
    required this.dark,
    required this.textFont,
    required this.titleFont,
    required this.displayFont,
    required this.headlineSize,
    required this.headlineWeight,
  });

  /// Resolves a stored preference: a preset name round-trips, and a legacy
  /// seed-color hex (the retired free picker) maps by hue — greens land on
  /// [forge], everything else on [ink].
  static Preset fromStored(String? stored) {
    for (final preset in values) {
      if (preset.name == stored) return preset;
    }
    return switch (_legacyHue(stored)) {
      double hue when hue >= 45 && hue <= 180 => .forge,
      double() => .ink,
      null => .forge,
    };
  }

  static double? _legacyHue(String? hex) {
    if (hex == null) return null;
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('FF');
    buffer.write(hex.replaceFirst('#', ''));
    final value = int.tryParse(buffer.toString(), radix: 16);
    if (value == null) return null;
    return HSLColor.fromColor(Color(value)).hue;
  }
}
