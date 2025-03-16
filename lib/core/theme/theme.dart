import "package:flutter/material.dart";
import "package:flutter/services.dart";

const _widerRadius = Radius.circular(12);
const _widerBorderRadius = BorderRadius.all(_widerRadius);
const _widerRoundedBorder = RoundedRectangleBorder(borderRadius: _widerBorderRadius);

const _font = 'Lato';

ThemeData theme(ColorScheme colorScheme) {
  final textTheme = _textTheme(primaryColor: colorScheme.onSurface, secondaryColor: colorScheme.outline);
  return ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    fontFamily: _font,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      filled: true,
      suffixStyle: textTheme.labelSmall,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      elevation: 1,
      selectedIconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: 28,
      ),
      selectedLabelStyle: textTheme.bodyLarge,
      selectedItemColor: colorScheme.onSurface,
      showUnselectedLabels: true,
      unselectedIconTheme: IconThemeData(
        color: colorScheme.outline,
        size: 24,
      ),
      unselectedLabelStyle: textTheme.bodySmall,
      unselectedItemColor: colorScheme.outline,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: _widerRadius,
          topRight: _widerRadius,
        ),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      iconSize: 24,
      enableFeedback: true,
      menuPadding: EdgeInsets.zero,
      shape: _widerRoundedBorder,
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness: switch (colorScheme.brightness) {
          Brightness.dark => Brightness.light,
          Brightness.light => Brightness.dark,
        },
        statusBarBrightness: colorScheme.brightness,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceContainer,
      deleteIconColor: colorScheme.outlineVariant,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      brightness: colorScheme.brightness,
    ),
    toggleButtonsTheme: const ToggleButtonsThemeData(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(
        fontFamily: _font,
        fontSize: 14,
        color: colorScheme.onInverseSurface,
        fontWeight: FontWeight.w400,
      ),
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(4),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(fontFamily: _font),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: textTheme.titleMedium?.copyWith(fontFamily: _font),
        foregroundColor: colorScheme.onSurface,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(strokeWidth: 2),
  );
}

TextTheme _textTheme({Color? primaryColor, Color? secondaryColor}) {
  return TextTheme(
    displayLarge: TextStyle(fontSize: 96.0, fontWeight: FontWeight.w300, letterSpacing: -1.5, color: primaryColor),
    displayMedium: TextStyle(fontSize: 60.0, fontWeight: FontWeight.w300, letterSpacing: -0.5, color: primaryColor),
    displaySmall: TextStyle(fontSize: 48.0, fontWeight: FontWeight.w400, letterSpacing: 0.0, color: primaryColor),
    headlineMedium: TextStyle(fontSize: 34.0, fontWeight: FontWeight.w700, letterSpacing: 0.25, color: primaryColor),
    headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w400, letterSpacing: 0.0, color: primaryColor),
    titleLarge: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w700, letterSpacing: 0.15, color: primaryColor),
    titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w700, letterSpacing: 0.15, color: primaryColor),
    titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: primaryColor),
    bodyLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w400, letterSpacing: 0.5, color: primaryColor),
    bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: primaryColor),
    bodySmall: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w400, letterSpacing: 0.4, color: secondaryColor),
    labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: 1.25, color: secondaryColor),
    labelSmall: TextStyle(fontSize: 10.0, fontWeight: FontWeight.w400, letterSpacing: 1.5, color: secondaryColor),
  );
}
