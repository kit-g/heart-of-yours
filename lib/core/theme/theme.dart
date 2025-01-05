import "package:flutter/material.dart";
import "package:flutter/services.dart";

const _widerRadius = Radius.circular(12);
const _widerBorderRadius = BorderRadius.all(_widerRadius);
const _widerRoundedBorder = RoundedRectangleBorder(borderRadius: _widerBorderRadius);

class MaterialTheme {
  const MaterialTheme();

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff86521a),
      surfaceTint: Color(0xff86521a),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffffdcbf),
      onPrimaryContainer: Color(0xff2d1600),
      secondary: Color(0xff735943),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffffdcbf),
      onSecondaryContainer: Color(0xff291806),
      tertiary: Color(0xff596339),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xffdde8b3),
      onTertiaryContainer: Color(0xff171e00),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff410002),
      surface: Color(0xfffff8f5),
      onSurface: Color(0xff211a14),
      onSurfaceVariant: Color(0xff51443a),
      outline: Color(0xff837469),
      outlineVariant: Color(0xffd5c3b6),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff372f28),
      inversePrimary: Color(0xfffeb876),
      primaryFixed: Color(0xffffdcbf),
      onPrimaryFixed: Color(0xff2d1600),
      primaryFixedDim: Color(0xfffeb876),
      onPrimaryFixedVariant: Color(0xff6a3b02),
      secondaryFixed: Color(0xffffdcbf),
      onSecondaryFixed: Color(0xff291806),
      secondaryFixedDim: Color(0xffe2c0a4),
      onSecondaryFixedVariant: Color(0xff59422d),
      tertiaryFixed: Color(0xffdde8b3),
      onTertiaryFixed: Color(0xff171e00),
      tertiaryFixedDim: Color(0xffc1cc99),
      onTertiaryFixedVariant: Color(0xff424b23),
      surfaceDim: Color(0xffe6d7cd),
      surfaceBright: Color(0xfffff8f5),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xfffff1e8),
      surfaceContainer: Color(0xfffaebe0),
      surfaceContainerHigh: Color(0xfff5e5db),
      surfaceContainerHighest: Color(0xffefe0d5),
    );
  }

  ThemeData light() {
    return theme(lightScheme());
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xfffeb876),
      surfaceTint: Color(0xfffeb876),
      onPrimary: Color(0xff4b2800),
      primaryContainer: Color(0xff6a3b02),
      onPrimaryContainer: Color(0xffffdcbf),
      secondary: Color(0xffe2c0a4),
      onSecondary: Color(0xff412c18),
      secondaryContainer: Color(0xff59422d),
      onSecondaryContainer: Color(0xffffdcbf),
      tertiary: Color(0xffc1cc99),
      onTertiary: Color(0xff2b340f),
      tertiaryContainer: Color(0xff424b23),
      onTertiaryContainer: Color(0xffdde8b3),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff19120c),
      onSurface: Color(0xffefe0d5),
      onSurfaceVariant: Color(0xffd5c3b6),
      outline: Color(0xff9e8e81),
      outlineVariant: Color(0xff51443a),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffefe0d5),
      inversePrimary: Color(0xff86521a),
      primaryFixed: Color(0xffffdcbf),
      onPrimaryFixed: Color(0xff2d1600),
      primaryFixedDim: Color(0xfffeb876),
      onPrimaryFixedVariant: Color(0xff6a3b02),
      secondaryFixed: Color(0xffffdcbf),
      onSecondaryFixed: Color(0xff291806),
      secondaryFixedDim: Color(0xffe2c0a4),
      onSecondaryFixedVariant: Color(0xff59422d),
      tertiaryFixed: Color(0xffdde8b3),
      onTertiaryFixed: Color(0xff171e00),
      tertiaryFixedDim: Color(0xffc1cc99),
      onTertiaryFixedVariant: Color(0xff424b23),
      surfaceDim: Color(0xff19120c),
      surfaceBright: Color(0xff403830),
      surfaceContainerLowest: Color(0xff130d07),
      surfaceContainerLow: Color(0xff211a14),
      surfaceContainer: Color(0xff261e18),
      surfaceContainerHigh: Color(0xff312822),
      surfaceContainerHighest: Color(0xff3c332c),
    );
  }

  ThemeData dark() {
    return theme(darkScheme());
  }

  ThemeData theme(ColorScheme colorScheme) {
    final textTheme = _textTheme(primaryColor: colorScheme.onSurface, secondaryColor: colorScheme.outline);
    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      fontFamily: 'Lato',
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
    );
  }
}

TextTheme _textTheme({Color? primaryColor, Color? secondaryColor}) {
  return TextTheme(
    displayLarge: TextStyle(fontSize: 96.0, fontWeight: FontWeight.w300, letterSpacing: -1.5, color: primaryColor),
    displayMedium: TextStyle(fontSize: 60.0, fontWeight: FontWeight.w300, letterSpacing: -0.5, color: primaryColor),
    displaySmall: TextStyle(fontSize: 48.0, fontWeight: FontWeight.w400, letterSpacing: 0.0, color: primaryColor),
    headlineMedium: TextStyle(fontSize: 34.0, fontWeight: FontWeight.w400, letterSpacing: 0.25, color: primaryColor),
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
