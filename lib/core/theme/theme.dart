import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/core/theme/tokens.dart';
import 'package:heart/presentation/widgets/buttons.dart';

const _widerRadius = Radius.circular(12);
const _widerBorderRadius = BorderRadius.all(_widerRadius);

const _fontFallbacks = ['Noto Sans'];

ThemeData theme(Preset preset, Brightness brightness) {
  // Deliberately not always `brightness`: a dark-only preset serves its dark
  // tokens from both slots.
  final tokens = switch (brightness) {
    .light => preset.light,
    .dark => preset.dark,
  };
  final font = preset.textFont;
  final colorScheme = tokens.colorScheme();
  final textTheme = _textTheme(
    preset: preset,
    primaryColor: colorScheme.onSurface,
    secondaryColor: colorScheme.onSurfaceVariant,
  );
  // The global textButtonTheme below is deliberately compact, which leaves the
  // date/time picker OK/Cancel cramped — restore Material's roomier action
  // padding just for those dialogs.
  final pickerActionStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    minimumSize: const Size(64, 40),
    textStyle: textTheme.bodyMedium?.copyWith(fontFamily: font),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    fontFamily: font,
    fontFamilyFallback: _fontFallbacks,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    canvasColor: colorScheme.surfaceContainerLowest,
    // Dialogs, sheets and cards are all "things the app puts in front of
    // itself", so they share the one surface token; only the ground sits
    // below it.
    // No elevation shadows anywhere — flat surfaces separated by borders
    // and the scrim. Shadows read as someone else's design system.
    dialogTheme: DialogThemeData(backgroundColor: tokens.surface, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      // No outline: the fill tone alone separates an input from the ground.
      // (Only `border` may be set at all — a theme-level `enabledBorder` or
      // `focusedBorder` would defeat `InputDecoration.collapsed` on inline
      // fields like the workout name.)
      border: OutlineInputBorder(borderRadius: .circular(8), borderSide: .none),
      filled: true,
      fillColor: tokens.fill,
      suffixStyle: textTheme.labelSmall,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 0,
      // accentInk, not accent: the accent is a fill color and on a light
      // ground it fails as an icon or label tint.
      selectedIconTheme: IconThemeData(color: tokens.accentInk, size: 28),
      selectedLabelStyle: textTheme.bodyLarge?.copyWith(color: tokens.accentInk),
      selectedItemColor: tokens.accentInk,
      showUnselectedLabels: true,
      unselectedIconTheme: IconThemeData(color: colorScheme.outline, size: 24),
      unselectedLabelStyle: textTheme.bodySmall,
      unselectedItemColor: colorScheme.outline,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: .only(topLeft: _widerRadius, topRight: _widerRadius),
      ),
      backgroundColor: tokens.surface,
      elevation: 0,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.onTertiary,
      iconSize: 24,
      enableFeedback: true,
      menuPadding: .zero,
      elevation: 0,
      // menus float with no scrim, so the border is all that defines them
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: _widerBorderRadius,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surfaceContainerLowest,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness: switch (colorScheme.brightness) {
          .dark => .light,
          .light => .dark,
        },
        statusBarBrightness: colorScheme.brightness,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.fill,
      deleteIconColor: colorScheme.outlineVariant,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: const BorderRadius.all(.circular(24)),
      ),
      brightness: colorScheme.brightness,
    ),
    toggleButtonsTheme: const ToggleButtonsThemeData(borderRadius: .all(.circular(4))),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: font,
        fontSize: 14,
        color: colorScheme.onInverseSurface,
        fontWeight: .w400,
      ),
      behavior: .floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: .all(.circular(4))),
    ),
    textButtonTheme: TextButtonThemeData(
      // Matched to PrimaryButton, which text buttons sit beside in every dialog
      // footer. It used to carry its own 4pt inset and a 4pt corner, and a
      // `compact` density on top — density shrinks the box *after* padding, so
      // the two could never line up however the padding was set.
      style: TextButton.styleFrom(
        padding: primaryButtonPadding,
        minimumSize: const Size(0, primaryButtonMinHeight),
        tapTargetSize: .shrinkWrap,
        visualDensity: .standard,
        shape: const RoundedRectangleBorder(borderRadius: .all(primaryButtonRadius)),
        // bodyMedium is what a PrimaryButton's label inherits inside a dialog,
        // so both read at the same size; the height floor above is what makes
        // them the same *box*.
        textStyle: textTheme.bodyMedium?.copyWith(fontFamily: font),
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      hourMinuteTextStyle: textTheme.displaySmall,
      confirmButtonStyle: pickerActionStyle,
      cancelButtonStyle: pickerActionStyle,
    ),
    datePickerTheme: DatePickerThemeData(
      confirmButtonStyle: pickerActionStyle,
      cancelButtonStyle: pickerActionStyle,
    ),
    listTileTheme: const ListTileThemeData(enableFeedback: true),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.titleMedium?.copyWith(fontFamily: font),
        foregroundColor: colorScheme.onSurface,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(strokeWidth: 2),
    navigationRailTheme: const NavigationRailThemeData(
      indicatorShape: CircleBorder(),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colorScheme.primary,
      selectionColor: colorScheme.primary.withValues(alpha: 0.3),
      selectionHandleColor: colorScheme.primary,
    ),
    carouselViewTheme: const CarouselViewThemeData(
      shape: RoundedRectangleBorder(borderRadius: .all(.circular(12))),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      // On a white ground a white card is invisible without its border.
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: _widerBorderRadius,
      ),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      primaryColor: colorScheme.primary,
      primaryContrastingColor: colorScheme.onPrimary,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      barBackgroundColor: colorScheme.surfaceContainerLowest,
      brightness: colorScheme.brightness,
    ),
  );
}

TextTheme _textTheme({required Preset preset, Color? primaryColor, Color? secondaryColor}) {
  final regular = !kIsWeb && Platform.isMacOS ? FontWeight.w200 : FontWeight.w400;
  final bold = !kIsWeb && Platform.isMacOS ? FontWeight.w500 : FontWeight.w700;

  return TextTheme(
    displayLarge: TextStyle(fontSize: 96.0, fontWeight: .w300, letterSpacing: -1.5, color: primaryColor),
    displayMedium: TextStyle(fontSize: 60.0, fontWeight: .w300, letterSpacing: -0.5, color: primaryColor),
    displaySmall: TextStyle(fontSize: 48.0, fontWeight: regular, letterSpacing: 0.0, color: primaryColor),
    // The page title wears the preset's display face; size and weight are
    // the preset's own, because different faces fill the same box very
    // differently.
    headlineMedium: TextStyle(
      fontFamily: preset.displayFont,
      fontSize: preset.headlineSize,
      fontWeight: preset.headlineWeight,
      letterSpacing: 0.5,
      color: primaryColor,
    ),
    headlineSmall: TextStyle(fontSize: 24.0, fontWeight: regular, letterSpacing: 0.0, color: primaryColor),
    // FlexibleSpaceBar draws the big page titles from this slot (scaled up
    // as the bar expands), so the preset's title face lands here.
    titleLarge: TextStyle(
      fontFamily: preset.titleFont,
      fontSize: 20.0,
      fontWeight: bold,
      letterSpacing: 0.15,
      color: primaryColor,
    ),
    titleMedium: TextStyle(fontSize: 16.0, fontWeight: bold, letterSpacing: 0.15, color: primaryColor),
    titleSmall: TextStyle(fontSize: 14.0, fontWeight: bold, letterSpacing: 0.1, color: primaryColor),
    bodyLarge: TextStyle(fontSize: 16.0, fontWeight: regular, letterSpacing: 0.5, color: primaryColor),
    bodyMedium: TextStyle(fontSize: 14.0, fontWeight: regular, letterSpacing: 0.25, color: primaryColor),
    bodySmall: TextStyle(fontSize: 12.0, fontWeight: regular, letterSpacing: 0.4, color: secondaryColor),
    labelLarge: TextStyle(fontSize: 14.0, fontWeight: bold, letterSpacing: 0.25, color: secondaryColor),
    labelSmall: TextStyle(fontSize: 10.0, fontWeight: regular, letterSpacing: 1.5, color: secondaryColor),
  );
}
