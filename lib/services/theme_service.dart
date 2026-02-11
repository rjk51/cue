import 'package:cue/services/theme_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'local_storage_service.dart';

/// Service to manage theme preferences with dual storage (Hive + Firestore).
///
/// Stores theme preference locally for offline access and syncs with Firestore
/// for cross-device availability.
class ThemeService {
  final LocalStorageService _localStorage = LocalStorageService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _themeKey = 'theme_preference';
  static const String _accentColorKey = 'accent_color';
  static const String _fontSizeKey = 'font_size_scale';
  static const String _backgroundColorKey = 'background_color';
  static const String _textColorKey = 'text_color';

  /// Get the current theme preference.
  ///
  /// Returns 'light', 'dark', or 'system'.
  /// Defaults to 'light' if not set.
  Future<String> getThemePreference() async {
    // Try to get from local storage first (faster, works offline)
    final localTheme = _localStorage.get<String>(_themeKey);
    if (localTheme != null) {
      return localTheme;
    }

    // Try to get from Firestore if online
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final firestoreTheme = userDoc.data()?['themePreference'] as String?;
          if (firestoreTheme != null) {
            // Cache it locally for future offline access
            await _localStorage.set(_themeKey, firestoreTheme);
            return firestoreTheme;
          }
        }
      }
    } catch (e) {
      // Network error or Firestore unavailable, use local storage
      print('Error fetching theme from Firestore: $e');
    }

    // Default to light theme
    return 'light';
  }

  /// Set the theme preference.
  ///
  /// Saves to both local storage (Hive) and Firestore.
  /// Valid values: 'light', 'dark', 'system'
  Future<void> setThemePreference(String theme) async {
    await setThemePreferenceQuiet(theme);
    // Notify all listeners of the theme change
    ThemeNotifier.instance.updateThemeMode(theme);
  }

  /// Save theme preference without notifying listeners.
  /// Used during onboarding to avoid rebuilding the widget tree mid-navigation.
  Future<void> setThemePreferenceQuiet(String theme) async {
    if (!['light', 'dark', 'system'].contains(theme)) {
      throw ArgumentError('Invalid theme: $theme. Must be light, dark, or system.');
    }

    // Save locally first (fast, always works)
    await _localStorage.set(_themeKey, theme);

    // Try to sync with Firestore
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set(
          {
            'themePreference': theme,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error saving theme to Firestore: $e');
    }
  }


  /// Check if user has completed onboarding (has theme preference set).
  Future<bool> hasCompletedOnboarding() async {
    try {
      // Check if both theme and accent color are set locally
      final localTheme = _localStorage.get<String>(_themeKey);
      final localColor = _localStorage.get<int>(_accentColorKey);
      
      if (localTheme != null && localColor != null) {
        return true;
      }

      // Check Firestore
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final hasTheme = data?['themePreference'] != null;
          final hasColor = data?['accentColor'] != null;
          
          if (hasTheme && hasColor) {
            // Cache them locally
            await _localStorage.set(_themeKey, data!['themePreference'] as String);
            await _localStorage.set(_accentColorKey, data['accentColor'] as int);
            return true;
          }
        }
      }
    } catch (e) {
      print('Error checking onboarding status: $e');
    }

    return false;
  }

  /// Get the accent color preference.
  ///
  /// Returns the user's chosen accent color.
  /// Defaults to coral (#FFB4A3) if not set.
  Future<Color> getAccentColor() async {
    // Try to get from local storage first
    final localColorValue = _localStorage.get<int>(_accentColorKey);
    if (localColorValue != null) {
      return Color(localColorValue);
    }

    // Try to get from Firestore if online
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final firestoreColor = userDoc.data()?['accentColor'] as int?;
          if (firestoreColor != null) {
            // Cache it locally
            await _localStorage.set(_accentColorKey, firestoreColor);
            return Color(firestoreColor);
          }
        }
      }
    } catch (e) {
      print('Error fetching accent color from Firestore: $e');
    }

    // Default coral color
    return const Color(0xFFFFB4A3);
  }

  /// Set the accent color preference.
  ///
  /// Saves to both local storage (Hive) and Firestore.
  Future<void> setAccentColor(Color color) async {
    final colorValue = color.value;

    // Save locally first
    await _localStorage.set(_accentColorKey, colorValue);

    // Notify all listeners of the color change
    ThemeNotifier.instance.updateAccentColor(color);

    // Try to sync with Firestore
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set(
          {
            'accentColor': colorValue,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error saving accent color to Firestore: $e');
      // Don't throw - local storage is sufficient
    }
  }

  /// Get the font size scale preference.
  ///
  /// Returns a scale multiplier for font sizes:
  /// - 1.0 = Default (normal)
  /// - 1.15 = Medium (larger)
  /// - 1.3 = Large (largest)
  /// Defaults to 1.0 if not set.
  Future<double> getFontSizeScale() async {
    // Try to get from local storage first
    final localScale = _localStorage.get<double>(_fontSizeKey);
    if (localScale != null) {
      return localScale;
    }

    // Try to get from Firestore if online
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final firestoreScale = userDoc.data()?['fontSizeScale'] as double?;
          if (firestoreScale != null) {
            // Cache it locally
            await _localStorage.set(_fontSizeKey, firestoreScale);
            return firestoreScale;
          }
        }
      }
    } catch (e) {
      print('Error fetching font size scale from Firestore: $e');
    }

    // Default to 1.0 (normal size)
    return 1.0;
  }

  /// Set the font size scale preference.
  ///
  /// Valid values: 1.0 (default), 1.15 (medium), 1.3 (large)
  Future<void> setFontSizeScale(double scale) async {
    if (![1.0, 1.15, 1.3].contains(scale)) {
      throw ArgumentError('Invalid font scale: $scale. Must be 1.0, 1.15, or 1.3.');
    }

    // Save locally first
    await _localStorage.set(_fontSizeKey, scale);

    // Notify all listeners of the font size change
    ThemeNotifier.instance.updateFontSizeScale(scale);

    // Try to sync with Firestore
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set(
          {
            'fontSizeScale': scale,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error saving font size scale to Firestore: $e');
      // Don't throw - local storage is sufficient
    }
  }

  /// Get the background color preference.
  ///
  /// Returns the user's chosen background color.
  /// Defaults to null (uses default gradient) if not set.
  Future<Color?> getBackgroundColor() async {
    // Try to get from local storage first
    final localColorValue = _localStorage.get<int>(_backgroundColorKey);
    if (localColorValue != null) {
      return Color(localColorValue);
    }

    // Try to get from Firestore if online
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final firestoreColor = userDoc.data()?['backgroundColor'] as int?;
          if (firestoreColor != null) {
            // Cache it locally
            await _localStorage.set(_backgroundColorKey, firestoreColor);
            return Color(firestoreColor);
          }
        }
      }
    } catch (e) {
      print('Error fetching background color from Firestore: $e');
    }

    // Default to null (uses default gradient)
    return null;
  }

  /// Set the background color preference.
  ///
  /// Saves to both local storage (Hive) and Firestore.
  /// Pass null to reset to default gradient.
  Future<void> setBackgroundColor(Color? color) async {
    final colorValue = color?.value;

    // Save locally first
    if (colorValue != null) {
      await _localStorage.set(_backgroundColorKey, colorValue);
    } else {
      await _localStorage.remove(_backgroundColorKey);
    }

    // Notify all listeners of the color change
    ThemeNotifier.instance.updateBackgroundColor(color);

    // Try to sync with Firestore
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set(
          {
            'backgroundColor': colorValue,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error saving background color to Firestore: $e');
      // Don't throw - local storage is sufficient
    }
  }

  /// Get the text color preference.
  ///
  /// Returns the user's chosen text color.
  /// Defaults to null (uses default theme-based colors) if not set.
  Future<Color?> getTextColor() async {
    // Try to get from local storage first
    final localColorValue = _localStorage.get<int>(_textColorKey);
    if (localColorValue != null) {
      return Color(localColorValue);
    }

    // Try to get from Firestore if online
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final firestoreColor = userDoc.data()?['textColor'] as int?;
          if (firestoreColor != null) {
            // Cache it locally
            await _localStorage.set(_textColorKey, firestoreColor);
            return Color(firestoreColor);
          }
        }
      }
    } catch (e) {
      print('Error fetching text color from Firestore: $e');
    }

    // Default to null (uses theme-based colors)
    return null;
  }

  /// Set the text color preference.
  ///
  /// Saves to both local storage (Hive) and Firestore.
  /// Pass null to reset to default theme-based colors.
  Future<void> setTextColor(Color? color) async {
    final colorValue = color?.value;

    // Save locally first
    if (colorValue != null) {
      await _localStorage.set(_textColorKey, colorValue);
    } else {
      await _localStorage.remove(_textColorKey);
    }

    // Notify all listeners of the color change
    ThemeNotifier.instance.updateTextColor(color);

    // Try to sync with Firestore
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set(
          {
            'textColor': colorValue,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (e) {
      print('Error saving text color to Firestore: $e');
      // Don't throw - local storage is sufficient
    }
  }
}
