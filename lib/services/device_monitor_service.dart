import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Import for global navigator key
import '../features/auth/presentation/welcome_screen.dart';
import '../features/notifications/notification_service.dart';

class DeviceMonitorService {
  static final DeviceMonitorService _instance = DeviceMonitorService._internal();
  factory DeviceMonitorService() => _instance;
  DeviceMonitorService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  StreamSubscription<DocumentSnapshot>? _deviceSubscription;
  String? _currentDeviceId;
  bool _isMonitoring = false;
  bool? _lastKnownActiveState; // Track the last known state

  /// Start monitoring the current device's status
  Future<void> startMonitoring(BuildContext context) async {
    if (_isMonitoring) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final fcmToken = _notificationService.fcmToken;

    if (userId == null || fcmToken == null) {
      print('Cannot start device monitoring: userId or fcmToken is null');
      return;
    }

    try {
      // Find the current device document
      final devicesSnapshot = await _firestore
          .collection('devices')
          .where('userId', isEqualTo: userId)
          .where('fcmToken', isEqualTo: fcmToken)
          .limit(1)
          .get();

      if (devicesSnapshot.docs.isEmpty) {
        print('No device document found for current device');
        return;
      }

      _currentDeviceId = devicesSnapshot.docs.first.id;
      _isMonitoring = true;
      
      // Get initial state
      final initialData = devicesSnapshot.docs.first.data() as Map<String, dynamic>;
      _lastKnownActiveState = initialData['active'] as bool? ?? true;
      print('✅ Starting device monitoring...');
      print('   Initial active state: $_lastKnownActiveState');

      // Listen to changes in the device document
      _deviceSubscription = _firestore
          .collection('devices')
          .doc(_currentDeviceId)
          .snapshots()
          .listen(
        (snapshot) {
          if (!snapshot.exists) {
            print('📱 Device document deleted');
            _handleDeviceRemoved();
            return;
          }

          final data = snapshot.data();
          if (data != null) {
            final isActive = data['active'] as bool? ?? true;
            
            // Only trigger logout if state CHANGED from active to inactive
            if (_lastKnownActiveState == true && isActive == false) {
              print('📱 Device changed from active to inactive');
              _handleDeviceDeactivated();
            }
            
            // Update the last known state
            _lastKnownActiveState = isActive;
          }
        },
        onError: (error) {
          print('Error monitoring device: $error');
        },
      );

      print('Device monitoring started for device: $_currentDeviceId');
    } catch (e) {
      print('Error starting device monitoring: $e');
    }
  }

  /// Stop monitoring the device
  void stopMonitoring() {
    _deviceSubscription?.cancel();
    _deviceSubscription = null;
    _currentDeviceId = null;
    _lastKnownActiveState = null;
    _isMonitoring = false;
    print('Device monitoring stopped');
  }

  /// Handle when device is deactivated from another device
  void _handleDeviceDeactivated() {
    print('🚨 Device was deactivated remotely - initiating logout...');
    
    // Stop monitoring immediately to prevent multiple triggers
    _deviceSubscription?.cancel();
    _isMonitoring = false;
    
    // Execute logout immediately without waiting for next frame
    _performLogout();
  }

  /// Handle when device document is deleted
  void _handleDeviceRemoved() {
    print('🚨 Device document was removed - initiating logout...');
    
    // Stop monitoring immediately to prevent multiple triggers
    _deviceSubscription?.cancel();
    _isMonitoring = false;
    
    // Execute logout immediately without waiting for next frame
    _performLogout();
  }
  
  /// Perform the actual logout and navigation
  Future<void> _performLogout() async {
    try {
      print('🔐 Signing out from Firebase Auth...');
      
      // Check if user is actually logged in
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      
      if (!isLoggedIn) {
        print('ℹ️ User already logged out, skipping');
        return;
      }
      
      // Get context before signing out
      final context = navigatorKey.currentContext;
      
      // Sign out
      await FirebaseAuth.instance.signOut();
      print('✅ Signed out successfully');
      
      // Navigate to welcome screen
      if (context != null && context.mounted) {
        print('🧭 Navigating to welcome screen...');
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        print('✅ Navigation completed');
      }
    } catch (e, stackTrace) {
      print('❌ Error during logout: $e');
      print('Stack trace: $stackTrace');
    } finally {
      _currentDeviceId = null;
      _lastKnownActiveState = null;
      print('✅ Device monitoring cleanup complete');
    }
  }

  /// Check if monitoring is active
  bool get isMonitoring => _isMonitoring;
}
