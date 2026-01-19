import 'package:flutter/material.dart';

class AppTheme {
  // 1. Original Teal (Professional & Trustworthy)
  static final ThemeData originalTealLight = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2D7A78),
      surface: Color(0xFFF7F9F9),
      surfaceContainerHighest: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1A1C1E),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F9F9),
    cardColor: const Color(0xFFFFFFFF),
  );

  static final ThemeData originalTealDark = ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4DB6AC),
      surface: Color(0xFF121212),
      surfaceContainerHighest: Color(0xFF1E1E1E),
      onSurface: Color(0xFFE0E0E0),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    cardColor: const Color(0xFF1E1E1E),
  );

  // 2. Warm Earthy (Calm & Organic)
  static final ThemeData warmEarthyLight = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFBC542A),
      surface: Color(0xFFFAF7F2),
      surfaceContainerHighest: Color(0xFFFFFFFF),
      onSurface: Color(0xFF3C2F2F),
    ),
    scaffoldBackgroundColor: const Color(0xFFFAF7F2),
    cardColor: const Color(0xFFFFFFFF),
  );

  static final ThemeData warmEarthyDark = ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFE68A5C),
      surface: Color(0xFF2C2621),
      surfaceContainerHighest: Color(0xFF3D352E),
      onSurface: Color(0xFFF5F2EF),
    ),
    scaffoldBackgroundColor: const Color(0xFF2C2621),
    cardColor: const Color(0xFF3D352E),
  );

  // 3. Cool Serene (Modern & Focused)
  static final ThemeData coolSereneLight = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7B61FF),
      surface: Color(0xFFF0F4F8),
      surfaceContainerHighest: Color(0xFFFFFFFF),
      onSurface: Color(0xFF24292E),
    ),
    scaffoldBackgroundColor: const Color(0xFFF0F4F8),
    cardColor: const Color(0xFFFFFFFF),
  );

  static final ThemeData coolSereneDark = ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFB0A0FF),
      surface: Color(0xFF1B1D21),
      surfaceContainerHighest: Color(0xFF25282E),
      onSurface: Color(0xFFECEFF4),
    ),
    scaffoldBackgroundColor: const Color(0xFF1B1D21),
    cardColor: const Color(0xFF25282E),
  );

  // 4. Sunrise
  static final ThemeData sunriseLight = ThemeData(
    colorScheme: ColorScheme.light(
      primary: const Color(0xFFFF8E6E),
      secondary: const Color(0xFFE0C38C),
      surface: const Color(0xFFFCFAF7),
      surfaceContainerHighest: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF3D3445),
    ),
    scaffoldBackgroundColor: const Color(0xFFFCFAF7),
    cardColor: const Color(0xFFFFFFFF),
  );

  static final ThemeData sunriseDark = ThemeData(
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFFFFAD87),
      secondary: const Color(0xFFC5A059),
      surface: const Color(0xFF2A262E),
      surfaceContainerHighest: const Color(0xFF352F3C),
      onSurface: const Color(0xFFFDFCF0),
    ),
    scaffoldBackgroundColor: const Color(0xFF2A262E),
    cardColor: const Color(0xFF352F3C),
  );
}
