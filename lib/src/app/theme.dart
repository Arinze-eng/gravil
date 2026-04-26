import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF0B1B3A);
  static const navy2 = Color(0xFF102A5A);
  static const accent = Color(0xFF3D7CFF);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: navy,
      primary: navy,
      secondary: accent,
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8FF),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
