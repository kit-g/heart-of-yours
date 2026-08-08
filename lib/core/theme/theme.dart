import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart/presentation/widgets/buttons.dart';

const _widerRadius = Radius.circular(12);
const _widerBorderRadius = BorderRadius.all(_widerRadius);
const _widerRoundedBorder = RoundedRectangleBorder(borderRadius: _widerBorderRadius);

const _font = 'Lato';
const _fontFallbacks = ['Noto Sans'];

ThemeData theme(ColorScheme colorScheme) {
  final textTheme = _textTheme(primaryColor: colorScheme.onSurface, secondaryColor: colorScheme.onSurfaceVariant);
  // The global textButtonTheme below is deliberately compact, which leaves the
  // date/time picker OK/Cancel cramped — restore Material's roomier action
  // padding just for those dialogs.
  final pickerActionStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    minimumSize: const Size(64, 40),
    textStyle: textTheme.bodyMedium?.copyWith(fontFamily: _font),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    fontFamily: _font,
    fontFamilyFallback: _fontFallbacks,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    canvasColor: colorScheme.surfaceContainerLowest,
    // Material's default dialog surface is `surfaceContainerHigh`, which under a
    // tinted scheme reads as grey against the near-white the app sits on.
    // `surfaceContainerLowest` is the lightest tone in the light scheme — the
    // same one the scaffold uses — so a dialog is as bright as the app gets
    // rather than a grey slab floating on it.
    dialogTheme: DialogThemeData(backgroundColor: colorScheme.surfaceContainerLowest),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(borderRadius: .circular(6), borderSide: .none),
      filled: true,
      suffixStyle: textTheme.labelSmall,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 1,
      selectedIconTheme: IconThemeData(color: colorScheme.primary, size: 28),
      selectedLabelStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.primary),
      selectedItemColor: colorScheme.onSurface,
      showUnselectedLabels: true,
      unselectedIconTheme: IconThemeData(color: colorScheme.outline, size: 24),
      unselectedLabelStyle: textTheme.bodySmall,
      unselectedItemColor: colorScheme.outline,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: .only(topLeft: _widerRadius, topRight: _widerRadius),
      ),
      // matches dialogs: a sheet is a surface the app puts in front of itself,
      // and it was reading a shade greyer than everything around it
      backgroundColor: colorScheme.surfaceContainerLowest,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.onTertiary,
      iconSize: 24,
      enableFeedback: true,
      menuPadding: .zero,
      shape: _widerRoundedBorder,
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
      backgroundColor: colorScheme.surfaceContainer,
      deleteIconColor: colorScheme.outlineVariant,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.transparent),
        borderRadius: .all(.circular(24)),
      ),
      brightness: colorScheme.brightness,
    ),
    toggleButtonsTheme: const ToggleButtonsThemeData(borderRadius: .all(.circular(4))),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        color: colorScheme.onInverseSurface,
        fontWeight: .w400,
      ),
      behavior: .floating,
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
        textStyle: textTheme.bodyMedium?.copyWith(fontFamily: _font),
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
        textStyle: textTheme.titleMedium?.copyWith(fontFamily: _font),
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
      color: colorScheme.surfaceContainerLowest,
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

TextTheme _textTheme({Color? primaryColor, Color? secondaryColor}) {
  final regular = !kIsWeb && Platform.isMacOS ? FontWeight.w200 : FontWeight.w400;
  final bold = !kIsWeb && Platform.isMacOS ? FontWeight.w500 : FontWeight.w700;

  return TextTheme(
    displayLarge: TextStyle(fontSize: 96.0, fontWeight: .w300, letterSpacing: -1.5, color: primaryColor),
    displayMedium: TextStyle(fontSize: 60.0, fontWeight: .w300, letterSpacing: -0.5, color: primaryColor),
    displaySmall: TextStyle(fontSize: 48.0, fontWeight: regular, letterSpacing: 0.0, color: primaryColor),
    headlineMedium: TextStyle(fontSize: 34.0, fontWeight: bold, letterSpacing: 0.25, color: primaryColor),
    headlineSmall: TextStyle(fontSize: 24.0, fontWeight: regular, letterSpacing: 0.0, color: primaryColor),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: bold, letterSpacing: 0.15, color: primaryColor),
    titleMedium: TextStyle(fontSize: 16.0, fontWeight: bold, letterSpacing: 0.15, color: primaryColor),
    titleSmall: TextStyle(fontSize: 14.0, fontWeight: bold, letterSpacing: 0.1, color: primaryColor),
    bodyLarge: TextStyle(fontSize: 16.0, fontWeight: regular, letterSpacing: 0.5, color: primaryColor),
    bodyMedium: TextStyle(fontSize: 14.0, fontWeight: regular, letterSpacing: 0.25, color: primaryColor),
    bodySmall: TextStyle(fontSize: 12.0, fontWeight: regular, letterSpacing: 0.4, color: secondaryColor),
    labelLarge: TextStyle(fontSize: 14.0, fontWeight: bold, letterSpacing: 0.25, color: secondaryColor),
    labelSmall: TextStyle(fontSize: 10.0, fontWeight: regular, letterSpacing: 1.5, color: secondaryColor),
  );
}
