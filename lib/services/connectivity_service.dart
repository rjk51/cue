import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Singleton service that monitors network connectivity.
///
/// Provides a [ValueNotifier<bool>] (`isOnline`) that widgets can listen to,
/// and a broadcast stream (`onConnectivityChanged`) that emits `true` when the
/// device comes back online and `false` when it goes offline.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Current connectivity state. Listen to this for reactive UI updates.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  /// Stream that emits only when the state *changes* (true = back online, false = went offline).
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _initialized = false;

  /// Call once at app startup (after Firebase init).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    final hasConnection = !results.contains(ConnectivityResult.none);
    if (hasConnection) {
      isOnline.value = await _checkActualConnectivity();
    } else {
      isOnline.value = false;
    }

    // Listen for changes
    _subscription =
        _connectivity.onConnectivityChanged.listen((results) async {
      final hasConnection = !results.contains(ConnectivityResult.none);
      if (hasConnection) {
        final actuallyOnline = await _checkActualConnectivity();
        _updateState(actuallyOnline);
      } else {
        _updateState(false);
      }
    });
  }

  void _updateState(bool online) {
    if (isOnline.value != online) {
      isOnline.value = online;
      _connectivityController.add(online);
    }
  }

  /// Performs a real DNS lookup to confirm internet access (not just WiFi).
  Future<bool> _checkActualConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
