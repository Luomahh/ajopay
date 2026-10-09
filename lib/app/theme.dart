import 'package:flutter/material.dart';

abstract final class AjoColors {
  static const forest = Color(0xFF123F35);
  static const emerald = Color(0xFF176B53);
  static const mint = Color(0xFFD9F3E5);
  static const canvas = Color(0xFFF5F7F3);
  static const ink = Color(0xFF192E28);
  static const muted = Color(0xFF607269);
  static const line = Color(0xFFDFE6DF);
}

ThemeData buildAjoTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AjoColors.emerald).copyWith(
    primary: AjoColors.emerald,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AjoColors.ink,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: AjoColors.line),
  );
  final button = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 54)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        fontFamily: 'Roboto',
      ),
    ),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: AjoColors.canvas,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 34,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: AjoColors.ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
        color: AjoColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AjoColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AjoColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AjoColors.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: AjoColors.muted),
      bodySmall: TextStyle(fontSize: 12, height: 1.5, color: AjoColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AjoColors.canvas,
      foregroundColor: AjoColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AjoColors.emerald, width: 2),
      ),
      contentPadding: const EdgeInsets.all(18),
      helperMaxLines: 3,
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(style: button),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: button.copyWith(
        backgroundColor: const WidgetStatePropertyAll(AjoColors.emerald),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: button),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AjoColors.line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AjoColors.forest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
