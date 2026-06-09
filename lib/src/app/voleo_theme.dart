import 'package:flutter/material.dart';

ThemeData buildVoleoTheme({Brightness brightness = Brightness.light}) {
  const seed = Color(0xff0c7c59);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    secondary: const Color(0xff355c7d),
    tertiary: const Color(0xffd98c3a),
    surface: brightness == Brightness.dark
        ? const Color(0xff12141a) // very dark gray/slate
        : const Color(0xfffbfcfb),
  );
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xff181b22) : scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: isDark ? const Color(0xff181b22) : null,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xff222733) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isDark ? const Color(0xff2f3545) : scheme.outlineVariant,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
