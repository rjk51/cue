import 'package:hive_flutter/hive_flutter.dart';

/// A simple abstraction over Hive for storing and retrieving local preferences.
///
/// This service provides a clean interface for storing primitives and simple values
/// without exposing Hive directly to the rest of the application.
///
/// Supported types: bool, String, int, double, List, Map, and null.
///
/// Usage:
/// ```dart
/// final storage = LocalStorageService.instance;
///
/// // Set values
/// await storage.set('theme_mode', 'dark');
/// await storage.set('onboarding_complete', true);
/// await storage.set('user_age', 25);
///
/// // Get values
/// final themeMode = storage.get<String>('theme_mode');
/// final hasCompletedOnboarding = storage.get<bool>('onboarding_complete') ?? false;
///
/// // Remove values
/// await storage.remove('theme_mode');
/// ```
class LocalStorageService {
  static const String _boxName = 'app_box';
  Box? _box;

  // Singleton pattern
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  static LocalStorageService get instance => _instance;
  LocalStorageService._internal();

  /// Initialize the service. Must be called before using get/set/remove.
  ///
  /// This is typically called during app startup in main.dart.
  Future<void> initialize() async {
    if (_box != null && _box!.isOpen) {
      return; // Already initialized
    }
    _box = await Hive.openBox(_boxName);
  }

  /// Get a value from local storage by key.
  ///
  /// Returns the value if it exists, or null if not found.
  ///
  /// Example:
  /// ```dart
  /// final username = storage.get<String>('username');
  /// final isDarkMode = storage.get<bool>('dark_mode') ?? false;
  /// ```
  T? get<T>(String key) {
    _ensureInitialized();
    final value = _box!.get(key);
    return value as T?;
  }

  /// Store a value in local storage.
  ///
  /// Supported types: bool, String, int, double, List, Map, and null.
  ///
  /// Example:
  /// ```dart
  /// await storage.set('username', 'john_doe');
  /// await storage.set('login_count', 42);
  /// await storage.set('is_premium', true);
  /// ```
  Future<void> set<T>(String key, T value) async {
    _ensureInitialized();
    await _box!.put(key, value);
  }

  /// Remove a value from local storage by key.
  ///
  /// Example:
  /// ```dart
  /// await storage.remove('temp_data');
  /// ```
  Future<void> remove(String key) async {
    _ensureInitialized();
    await _box!.delete(key);
  }

  /// Check if a key exists in local storage.
  ///
  /// Example:
  /// ```dart
  /// if (storage.containsKey('user_id')) {
  ///   // User is logged in
  /// }
  /// ```
  bool containsKey(String key) {
    _ensureInitialized();
    return _box!.containsKey(key);
  }

  /// Get all keys stored in local storage.
  ///
  /// Example:
  /// ```dart
  /// final allKeys = storage.getAllKeys();
  /// print('Stored keys: $allKeys');
  /// ```
  Iterable<dynamic> getAllKeys() {
    _ensureInitialized();
    return _box!.keys;
  }

  // Notification sound preference
  static const String _notificationSoundKey = 'notification_sound';
  
  Future<void> setNotificationSound(String soundName) async {
    await set(_notificationSoundKey, soundName);
  }
  
  String getNotificationSound() {
    return get<String>(_notificationSoundKey) ?? 'notification_ringtone'; // Default sound
  }

  // Nudge sound preference
  static const String _nudgeSoundKey = 'nudge_sound';
  
  Future<void> setNudgeSound(String soundId) async {
    await set(_nudgeSoundKey, soundId);
  }
  
  String getNudgeSound() {
    return get<String>(_nudgeSoundKey) ?? 'default'; // Default sound
  }

  // Nudge message preference
  static const String _nudgeMessageKey = 'nudge_message';
  
  Future<void> setNudgeMessage(String message) async {
    await set(_nudgeMessageKey, message);
  }
  
  String getNudgeMessage() {
    return get<String>(_nudgeMessageKey) ?? 'Don\'t forget your reminders'; // Default message (4 words)
  }

  /// Get all keys stored in local storage.
  ///
  /// Returns an iterable of all keys currently stored.
  Iterable<dynamic> get keys {
    _ensureInitialized();
    return _box!.keys;
  }

  /// Clear all data from local storage.
  ///
  /// Use with caution - this will delete all stored preferences.
  ///
  /// Example:
  /// ```dart
  /// await storage.clear(); // Reset all app preferences
  /// ```
  Future<void> clear() async {
    _ensureInitialized();
    await _box!.clear();
  }

  /// Close the storage box.
  ///
  /// This is typically only needed when shutting down the app
  /// or during testing cleanup.
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }

  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'LocalStorageService is not initialized. '
        'Call initialize() before using this service.',
      );
    }
  }
}
