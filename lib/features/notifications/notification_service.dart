import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../reminders/domain/reminder_model.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Top-level function for handling background notification responses
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  print('🔔 BACKGROUND notification tap received:');
  print('  - Payload: ${response.payload}');
  print('  - Action ID: ${response.actionId}');
  print('  - Input: ${response.input}');
  print('  - Notification ID: ${response.id}');
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Callback for when notification action is tapped
  Function(String reminderId, String action)? onNotificationAction;
  
  // Stream subscription for reminder updates
  StreamSubscription<QuerySnapshot>? _reminderSubscription;

  Future<void> initialize() async {
    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Get device timezone - Flutter provides timezone offset, we need to map to IANA name
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    
    // Try multiple methods to get correct timezone
    String? timeZoneName;
    
    // Method 1: Try to use timezone offset to find IANA name
    // For IST (India): offset is +5:30
    if (offset.inHours == 5 && offset.inMinutes % 60 == 30) {
      timeZoneName = 'Asia/Kolkata';
    } else {
      // Method 2: Calculate from offset (fallback)
      final hours = offset.inHours;
      final minutes = offset.inMinutes % 60;
      
      // Common timezone mappings
      if (hours == 0 && minutes == 0) timeZoneName = 'UTC';
      else if (hours == 5 && minutes == 30) timeZoneName = 'Asia/Kolkata';
      else if (hours == 8 && minutes == 0) timeZoneName = 'Asia/Shanghai';
      else if (hours == 9 && minutes == 0) timeZoneName = 'Asia/Tokyo';
      else if (hours == -5 && minutes == 0) timeZoneName = 'America/New_York';
      else if (hours == -8 && minutes == 0) timeZoneName = 'America/Los_Angeles';
    }
    
    try {
      if (timeZoneName != null) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        print('✅ Timezone set to: $timeZoneName (offset: ${offset.inHours}h ${offset.inMinutes % 60}m)');
      } else {
        // Fallback: Use UTC with offset
        tz.setLocalLocation(tz.getLocation('UTC'));
        print('⚠️ Using UTC (device offset: ${offset.inHours}h ${offset.inMinutes % 60}m)');
      }
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
      print('❌ Timezone error, using UTC: $e');
    }

    // Request notification permission (iOS & Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    } else {
      print('User denied notification permission');
    }

    // Request exact alarm permission for Android 12+
    await _requestExactAlarmPermission();

    // Get FCM token (iOS requires APNS token first)
    try {
      if (Platform.isIOS) {
        // For iOS, wait for APNS token first
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          print('APNS Token: $apnsToken');
          _fcmToken = await _messaging.getToken();
          print('FCM Token: $_fcmToken');
          await _saveFCMTokenToFirestore(_fcmToken);
        } else {
          print('⚠️ APNS token is null, retrying...');
          // Retry after a short delay
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            _fcmToken = await _messaging.getToken();
            print('FCM Token (retry): $_fcmToken');
            await _saveFCMTokenToFirestore(_fcmToken);
          } else {
            print('❌ Could not get APNS token after retry');
          }
        }
      } else {
        // Android can get token directly
        _fcmToken = await _messaging.getToken();
        print('FCM Token: $_fcmToken');
        await _saveFCMTokenToFirestore(_fcmToken);
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('FCM Token refreshed: $newToken');
      _saveFCMTokenToFirestore(newToken);
    });

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
    
    // Listen for reminder updates to dismiss notifications
    _listenToReminderUpdates();
    
    // For iOS: Listen for notification actions from native side
    if (Platform.isIOS) {
      _setupIOSNotificationActionListener();
    }
  }
  
  void _setupIOSNotificationActionListener() {
    // Listen for notification actions posted from iOS AppDelegate
    const EventChannel('notification_action_channel')
        .receiveBroadcastStream()
        .listen((event) {
      print('📱 Received iOS notification action: $event');
      if (event is Map) {
        final action = event['action'] as String?;
        final reminderId = event['reminderId'] as String?;
        final userInput = event['userInput'] as String?;
        
        if (action != null && reminderId != null && onNotificationAction != null) {
          print('✅ Processing iOS action: $action for reminder: $reminderId');

          // For custom snooze input, validate numeric range 1–59
          if (action == 'snooze_input') {
            final inputStr = (userInput ?? '').trim();
            final minutes = int.tryParse(inputStr);

            if (minutes == null) {
              print('❌ Invalid custom snooze input on iOS (not a number): "$inputStr"');
              return;
            }
            if (minutes < 1 || minutes > 59) {
              print('❌ Invalid custom snooze input on iOS (out of range 1-59): $minutes');
              return;
            }

            print('⏰ Custom snooze input (validated) on iOS: $minutes minutes');
            onNotificationAction!('$reminderId:$minutes', action);
          } else {
            onNotificationAction!(reminderId, action);
          }
        }
      }
    }, onError: (error) {
      print('❌ Error listening to iOS notification actions: $error');
    });
  }

  Future<void> _requestExactAlarmPermission() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      print('⚠️ Exact alarm permission not granted. Requesting...');
      final status = await Permission.scheduleExactAlarm.request();
      if (status.isGranted) {
        print('✅ Exact alarm permission granted');
      } else {
        print('❌ Exact alarm permission denied');
      }
    } else {
      print('✅ Exact alarm permission already granted');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      onDidReceiveLocalNotification: null,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    print('📱 Local notifications initialized: $initialized');
    
    // For iOS, create notification channel equivalent
    if (Platform.isIOS) {
      print('📱 iOS detected - notification categories should be registered in AppDelegate');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;
    final input = response.input;

    print('📱 Notification response received:');
    print('  - Payload: $payload');
    print('  - Action ID: $actionId');
    print('  - Input: $input');
    print('  - Notification ID: ${response.id}');

    // CRITICAL: Cancel notification IMMEDIATELY using the notification ID
    // This prevents the "loading" state on Android RemoteInput
    print('🔔 Canceling notification immediately (ID: ${response.id})');
    _localNotifications.cancel(response.id!).then((_) {
      print('✅ Notification canceled');
    });

    if (payload != null) {
      // If actionId is null, user tapped the notification body (not a button)
      if (actionId == null) {
        print('⚠️  Notification body tapped, no action');
        return;
      }

      // Handle action button tap (Done/Snooze)
      if (onNotificationAction != null) {
        print('✅ Calling onNotificationAction callback');
        
        // For Android custom snooze input, validate numeric range 1–59
        if (actionId == 'snooze_input') {
          final inputStr = (input ?? '').trim();
          final minutes = int.tryParse(inputStr);

          if (minutes == null) {
            print('❌ Invalid custom snooze input on Android (not a number): "$inputStr"');
            return;
          }
          if (minutes < 1 || minutes > 59) {
            print('❌ Invalid custom snooze input on Android (out of range 1-59): $minutes');
            return;
          }

          print('⏰ Android custom snooze input (validated): $minutes minutes');
          onNotificationAction!('$payload:$minutes', actionId);
        } else {
          onNotificationAction!(payload, actionId);
        }
      } else {
        print('❌ onNotificationAction callback is null');
      }
    } else {
      print('⚠️  Payload is null');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Foreground message received');
    print('Data: ${message.data}');
    print('Notification: ${message.notification}');
    
    // Check if this is a dismiss notification
    if (message.data.containsKey('type') && 
        message.data['type'] == 'dismiss_notification') {
      final reminderId = message.data['reminderId'] ?? '';
      if (reminderId.isNotEmpty) {
        print('📤 Dismissing notification for reminder: $reminderId');
        cancelNotification(reminderId);
      }
      return;
    }
    
    // Check if this is a reminder notification
    if (message.data.containsKey('type') && 
        message.data['type'] == 'reminder_notification') {
      
      final reminderId = message.data['reminderId'] ?? '';
      final title = message.notification?.title ?? message.data['title'] ?? 'Reminder';
      final body = message.notification?.body ?? message.data['body'] ?? 'Your reminder is due!';
      
      print('🔔 Showing foreground notification: $title');
      
      // CRITICAL: iOS doesn't show notifications when app is in foreground
      // We MUST manually show them using local notifications
      _showLocalNotificationWithActions(
        id: reminderId.hashCode,
        title: title,
        body: body,
        payload: reminderId,
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to specific screen if needed
  }

  // Public method to show notification with action buttons (used by background handler)
  Future<void> showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    return _showLocalNotificationWithActions(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> _showLocalNotificationWithActions({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    // Always use custom ringtone for reminder/snooze notifications
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Notification channel for reminders',
      importance: Importance.high,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification_ringtone'),
      playSound: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_done',
          'Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze_5',
          '5 min',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_input',
          'Custom',
          showsUserInterface: true,
          cancelNotification: false,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: '1-59 minutes',
              allowFreeFormInput: true,
            ),
          ],
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_ringtone.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Schedule a notification using Cloud Functions
  // Note: Actual scheduling now happens automatically via Firestore triggers
  // This method is kept for backward compatibility but scheduling is handled server-side
  Future<void> scheduleReminderNotification(Reminder reminder) async {
    print('=== Reminder Created ===');
    print('Reminder: ${reminder.name}');
    print('Time: ${reminder.time}');
    print('✅ Cloud Functions will automatically handle notification scheduling');
    
    // The scheduleReminderOnCreate Cloud Function trigger will automatically
    // create a pending_notification document when the reminder is saved to Firestore
    // No local scheduling needed - everything is handled server-side for iOS/Android parity
    
    return;
  }

  // Trigger Cloud Function to send notification
  Future<void> _triggerCloudNotification(String reminderId, String userId) async {
    try {
      print('🔔 Triggering cloud notification for reminder: $reminderId');
      
      final callable = _functions.httpsCallable('triggerReminderNotification');
      final result = await callable.call({
        'reminderId': reminderId,
        'userId': userId,
      });
      
      print('✅ Cloud notification result: ${result.data}');
    } catch (e) {
      print('❌ Error triggering cloud notification: $e');
    }
  }

  // Check for pending reminders on app startup
  Future<void> checkPendingReminders(String userId) async {
    try {
      print('🔍 Checking for pending reminders...');
      
      final callable = _functions.httpsCallable('checkPendingReminders');
      final result = await callable.call({'userId': userId});
      
      print('✅ Pending reminders checked: ${result.data}');
    } catch (e) {
      print('❌ Error checking pending reminders: $e');
    }
  }

  // Cancel a scheduled notification
  Future<void> cancelNotification(String reminderId) async {
    await _localNotifications.cancel(reminderId.hashCode);
    print('Cancelled notification for reminder: $reminderId');
  }
  
  // Listen to reminder updates to dismiss notifications on other devices
  void _listenToReminderUpdates() {
    print('📡 Starting listener for reminder updates...');
    
    // Get current user ID
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      print('⚠️ No user logged in, cannot listen to reminder updates');
      return;
    }
    
    _reminderSubscription = FirebaseFirestore.instance
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final reminder = change.doc.data();
          if (reminder != null) {
            final reminderId = change.doc.id;
            final isCompleted = reminder['isCompleted'] == true;
            final lastCompletedAt = reminder['lastCompletedAt'] as Timestamp?;
            
            // Dismiss notification if:
            // 1. Non-recurring reminder is marked as completed (isCompleted = true)
            // 2. Recurring reminder was just completed (lastCompletedAt updated in last 5 seconds)
            final shouldDismiss = isCompleted || 
                (lastCompletedAt != null && 
                 DateTime.now().difference(lastCompletedAt.toDate()).inSeconds < 5);
            
            if (shouldDismiss) {
              print('✅ Reminder completed, dismissing notification: $reminderId');
              cancelNotification(reminderId);
            }
          }
        }
      }
    });
  }
  
  // Dispose stream subscription
  void dispose() {
    _reminderSubscription?.cancel();
  }

  // Test notification - shows immediately
  Future<void> showTestNotification() async {
    print('🧪 Showing test notification...');
    print('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      sound: RawResourceAndroidNotificationSound('notification_ringtone'),
      playSound: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'done',
          'Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze',
          'Snooze',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_ringtone.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    print('📱 Calling show() with ID: 999');
    await _localNotifications.show(
      999,
      '🧪 Test Notification',
      'If you see this, notifications are working! Tap Done or Snooze.',
      notificationDetails,
      payload: 'test_reminder_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    print('✅ Test notification sent - check notification center');
    
    // For iOS, also log the pending notifications
    if (Platform.isIOS) {
      final pending = await _localNotifications.pendingNotificationRequests();
      print('📱 Pending iOS notifications: ${pending.length}');
    }
  }

  // Subscribe to a topic for cross-device sync
  Future<void> subscribeToUserTopic(String userId) async {
    await _messaging.subscribeToTopic('user_$userId');
    print('Subscribed to topic: user_$userId');
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromUserTopic(String userId) async {
    await _messaging.unsubscribeFromTopic('user_$userId');
    print('Unsubscribed from topic: user_$userId');
  }

  // Save FCM token to Firestore for Cloud Functions
  Future<void> _saveFCMTokenToFirestore(String? token) async {
    if (token != null) {
      try {
        // Get current user ID from Firebase Auth
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          print('⚠️ No user logged in, cannot save FCM token');
          return;
        }
        
        print('💾 Saving FCM token to devices collection...');
        print('Token: ${token.substring(0, 20)}...');
        print('User ID: $userId');
        
        // Save to devices collection with userId for user-specific notifications
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(token)
            .set({
          'fcmToken': token,
          'userId': userId,  // Link device to user account
          'lastUpdated': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'active': true,
        }, SetOptions(merge: true));
        
        print('✅ FCM Token saved to devices collection for user: $userId');
        
        // Verify it was saved
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(token)
            .get();
        
        if (doc.exists) {
          print('✅ Verified: Device document exists');
        } else {
          print('❌ Warning: Device document not found after save');
        }
      } catch (e) {
        print('❌ Error saving FCM token to Firestore: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    } else {
      print('❌ FCM token is null, cannot save to Firestore');
    }
  }
  
  /// Reactivate device after login (sets active to true)
  Future<void> reactivateDevice() async {
    final token = _fcmToken;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    
    if (token != null && userId != null) {
      try {
        print('🔄 Reactivating device...');
        print('   Token: ${token.substring(0, 20)}...');
        print('   User ID: $userId');
        
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(token)
            .update({
          'active': true,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ Device reactivated successfully');
        
        // Verify the update
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(token)
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          final isActive = data?['active'] as bool? ?? false;
          print('   Verified active status: $isActive');
        }
      } catch (e) {
        print('❌ Error reactivating device: $e');
        // If document doesn't exist, create it
        try {
          print('   Attempting to create device document...');
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(token)
              .set({
            'fcmToken': token,
            'userId': userId,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'active': true,
          }, SetOptions(merge: true));
          print('✅ Device document created and activated');
        } catch (createError) {
          print('❌ Error creating device document: $createError');
        }
      }
    } else {
      print('⚠️ Cannot reactivate device: token or userId is null');
      print('   Token: ${token != null ? "present" : "null"}');
      print('   User ID: ${userId ?? "null"}');
    }
  }
}
