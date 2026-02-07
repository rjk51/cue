import 'package:flutter/material.dart';

/// Global notifier for theme changes.
/// 
/// This allows widgets to be notified when the theme or accent color changes,
/// enabling reactive UI updates across the app.
class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier _instance = ThemeNotifier._internal();
  factory ThemeNotifier() => _instance;
  ThemeNotifier._internal();

  static ThemeNotifier get instance => _instance;

  Color _accentColor = const Color(0xFFFFB4A3);
  String _themeMode = 'light';
  double _fontSizeScale = 1.0;

  Color get accentColor => _accentColor;
  String get themeMode => _themeMode;
  double get fontSizeScale => _fontSizeScale;

  bool get isDarkMode {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'system') {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return false;
  }

  /// Update the accent color and notify listeners.
  void updateAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  /// Update the theme mode and notify listeners.
  void updateThemeMode(String mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Update the font size scale and notify listeners.
  void updateFontSizeScale(double scale) {
    _fontSizeScale = scale;
    notifyListeners();
  }

  /// Initialize with stored values (call this at app startup).
  void initialize({
    required Color accentColor,
    required String themeMode,
    double fontSizeScale = 1.0,
  }) {
    _accentColor = accentColor;
    _themeMode = themeMode;
    _fontSizeScale = fontSizeScale;
  }
}
