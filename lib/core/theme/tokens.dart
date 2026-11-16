import 'package:heart_design/heart_design.dart' as design;
import 'package:heart_state/heart_state.dart' show MuscleFamily;
import 'package:material_ui/material_ui.dart';

/// The app's own design vocabulary — every color the UI is allowed to use.
///
/// A preset is a hand-tuned [Tokens] pair (one per brightness), from
/// `heart_design`, the one source of them in heart-api; nothing is derived at
/// runtime, and Material's tonal roles are only a compatibility
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

  /// A brightness of a preset, as `heart_design` holds it (#458): that package
  /// is the one source of the values, and this the app's way of wearing them.
  factory from(design.Palette palette, Brightness brightness) {
    return Tokens(
      brightness: brightness,
      ground: Color(palette.ground),
      surface: Color(palette.surface),
      fill: Color(palette.fill),
      ink: Color(palette.ink),
      muted: Color(palette.muted),
      faint: Color(palette.faint),
      border: Color(palette.border),
      accent: Color(palette.accent),
      onAccent: Color(palette.onAccent),
      accentInk: Color(palette.accentInk),
      destructive: Color(palette.destructive),
    );
  }

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
  forge(design.Preset.forge),
  ink(design.Preset.ink),
  utility(design.Preset.utility),
  ember(design.Preset.ember);

  final design.Preset _design;

  new(this._design);

  static final Map<Preset, ({Tokens light, Tokens dark})> _tokens = {
    for (final preset in values)
      preset: (
        light: Tokens.from(preset._design.light, .light),
        dark: Tokens.from(preset._design.dark, .dark),
      ),
  };

  Tokens get light => _tokens[this]!.light;

  Tokens get dark => _tokens[this]!.dark;

  /// Everything that reads — body, labels, controls.
  String get textFont => _design.textFont;

  /// Page and dialog titles (`titleLarge`) — where a preset may hand
  /// headlines to a second face without shouting everywhere [displayFont]
  /// does.
  String get titleFont => _design.titleFont;

  /// Headlines and numbers worth a shout, nothing else.
  String get displayFont => _design.displayFont;

  /// The page-title size and weight, tuned per display face — different
  /// faces fill the same box very differently at one size.
  double get headlineSize => _design.headlineSize;

  FontWeight get headlineWeight {
    return FontWeight.values.firstWhere((weight) => weight.value == _design.headlineWeight);
  }

  /// Resolves a stored preference: a preset name round-trips, and a legacy
  /// seed-color hex (the retired free picker) maps by hue — greens land on
  /// [forge], everything else on [ink].
  static Preset fromStored(String? stored) {
    for (final preset in values) {
      if (preset.name == stored) return preset;
    }
    return switch (_legacyHue(stored)) {
      // a stored legacy seed still maps to whichever preset it was closest to
      double hue when hue >= 45 && hue <= 180 => .forge,
      double() => .ink,
      // nothing stored at all is a first launch, and that is the house style
      null => .ink,
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

/// The colour of a muscle family (#617), the same in every preset: a family
/// means one colour on every screen and in every theme, so it cannot follow
/// the preset's accent.
///
/// Chosen, not derived. Each holds 3:1 against every preset's ground,
/// surface and fill in its brightness (WCAG 1.4.11), and every pair stays
/// apart: CIELAB ΔE ≥ 34 for typical vision in both brightnesses, and under
/// simulated protanopia, deuteranopia and tritanopia (Machado 2009) ≥ 14 in
/// light and ≥ 36 in dark. Light has less room — every colour must stay dark
/// enough for a white ground — and its closest pair under colour blindness is
/// back and arms. The hues keep their identity across brightness (chest red,
/// back blue, shoulders amber, arms magenta, core teal, lower body violet);
/// only lightness moves.
Color muscleFamilyColor(MuscleFamily family, Brightness brightness) {
  return switch ((family, brightness)) {
    (.chest, .light) => const Color(0xFF990300),
    (.back, .light) => const Color(0xFF15517A),
    (.shoulders, .light) => const Color(0xFFDA6C19),
    (.arms, .light) => const Color(0xFFA8329C),
    (.core, .light) => const Color(0xFF109D80),
    (.lowerBody, .light) => const Color(0xFF6D16E9),
    (.chest, .dark) => const Color(0xFFEF2938),
    (.back, .dark) => const Color(0xFF1F67F9),
    (.shoulders, .dark) => const Color(0xFFFFB91A),
    (.arms, .dark) => const Color(0xFFD45487),
    (.core, .dark) => const Color(0xFF8FFFF8),
    (.lowerBody, .dark) => const Color(0xFFBC9AF3),
  };
}
