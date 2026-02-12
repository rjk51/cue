import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../services/local_storage_service.dart';

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

  // Safe helper to get notification sound with fallback
  String _getSafeNotificationSound() {
    try {
      return LocalStorageService.instance.getNotificationSound();
    } catch (e) {
      print('⚠️ LocalStorageService not initialized, using default sound');
      return 'notification_bell'; // Default sound
    }
  }

  // Safe helper to get nudge sound with fallback
  String _getSafeNudgeSound() {
    try {
      return LocalStorageService.instance.getNudgeSound();
    } catch (e) {
      print('⚠️ LocalStorageService not initialized, using default nudge sound');
      return 'notification_bell'; // Default sound
    }
  }

  Future<void> ensureDeviceRegistered() async {
    print('🔄 Ensuring device is registered...');
    if (_fcmToken != null) {
      await _saveFCMTokenToFirestore(_fcmToken);
    } else {
      try {
        if (Platform.isIOS) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            _fcmToken = await _messaging.getToken();
          }
        } else {
          _fcmToken = await _messaging.getToken();
        }
        if (_fcmToken != null) {
          print('✅ Got FCM token: ${_fcmToken!.substring(0, 20)}...');
          await _saveFCMTokenToFirestore(_fcmToken);
        }
      } catch (e) {
        print('❌ Error in ensureDeviceRegistered: $e');
      }
    }
  }

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

          // For custom snooze input, validate numeric input (any positive number)
          if (action == 'snooze_input') {
            final inputStr = (userInput ?? '').trim();
            final minutes = int.tryParse(inputStr);

            if (minutes == null) {
              print('❌ Invalid custom snooze input on iOS (not a number): "$inputStr"');
              return;
            }
            if (minutes < 1) {
              print('❌ Invalid custom snooze input on iOS (must be at least 1 minute): $minutes');
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
    
    // Create Android notification channels
    if (Platform.isAndroid) {
      await _cleanupOldNotificationChannels();
      await _createDefaultReminderChannel();
      await _createBuddyNudgeChannel();
    }
    
    // For iOS, create notification channel equivalent
    if (Platform.isIOS) {
      print('📱 iOS detected - notification categories should be registered in AppDelegate');
    }
  }

  Future<void> _createDefaultReminderChannel() async {
    try {
      print('📢 Creating default reminder notification channel...');
      
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'reminder_channel',
          'Reminders',
          description: 'Notifications for your reminders',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );
        
        await androidPlugin.createNotificationChannel(channel);
        print('✅ Default reminder channel created');
      }
    } catch (e) {
      print('⚠️ Error creating default reminder channel: $e');
    }
  }

  Future<void> _createBuddyNudgeChannel() async {
    try {
      print('📢 Creating buddy nudge notification channel...');
      
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          'buddy_nudge_channel',
          'Buddy Nudges',
          description: 'Notifications when your buddy nudges you',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        
        await androidPlugin.createNotificationChannel(channel);
        print('✅ Buddy nudge channel created');
      }
    } catch (e) {
      print('⚠️ Error creating buddy nudge channel: $e');
    }
  }

  Future<void> _cleanupOldNotificationChannels() async {
    try {
      print('🧹 Cleaning up old notification channels...');
      
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Note: Do not delete reminder_channel as it's actively used
        // Only delete truly obsolete channels here
        
        print('✅ Old notification channels cleaned up');
      }
    } catch (e) {
      print('⚠️ Error cleaning up notification channels: $e');
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
        
        // For Android custom snooze input, validate numeric input (any positive number)
        if (actionId == 'snooze_input') {
          final inputStr = (input ?? '').trim();
          final minutes = int.tryParse(inputStr);

          if (minutes == null) {
            print('❌ Invalid custom snooze input on Android (not a number): "$inputStr"');
            return;
          }
          if (minutes < 1) {
            print('❌ Invalid custom snooze input on Android (must be at least 1 minute): $minutes');
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
    
    // Check if this is a buddy nudge notification
    if (message.data.containsKey('type') && 
        message.data['type'] == 'buddy_nudge') {
      
      final title = message.notification?.title ?? message.data['title'] ?? '👋 Buddy Nudge';
      final body = message.notification?.body ?? message.data['body'] ?? 'Your buddy sent you a nudge!';
      
      print('👋 Buddy nudge received in foreground');
      
      // CRITICAL: When app is in foreground, FCM does NOT automatically display notifications
      // on either platform. We MUST manually show them using local notifications.
      final selectedSound = _getSafeNudgeSound();
      print('🔔 Showing buddy nudge notification with sound: $selectedSound');
      
      _showBuddyNudgeNotification(
        title: title,
        body: body,
        sound: selectedSound,
      );
      return;
    }
    
    // Check if this is a reminder notification
    if (message.data.containsKey('type') && 
        message.data['type'] == 'reminder_notification') {
      
      final reminderId = message.data['reminderId'] ?? '';
      final title = message.notification?.title ?? message.data['title'] ?? 'Reminder';
      final body = message.notification?.body ?? message.data['body'] ?? 'Your reminder is due!';
      
      // Extract icon and color data
      final customIconUrl = message.data['customIconUrl'] ?? '';
      final iconCodePoint = message.data['iconCodePoint'] ?? '';
      final colorValue = message.data['colorValue'] ?? '';
      
      print('🔔 Showing foreground notification: $title');
      print('🎨 Icon data - customUrl: $customIconUrl, iconCode: $iconCodePoint, color: $colorValue');
      
      // CRITICAL: iOS doesn't show notifications when app is in foreground
      // We MUST manually show them using local notifications
      _showLocalNotificationWithActions(
        id: reminderId.hashCode,
        title: title,
        body: body,
        payload: reminderId,
        customIconUrl: customIconUrl.isNotEmpty ? customIconUrl : null,
        iconCodePoint: iconCodePoint.isNotEmpty ? int.tryParse(iconCodePoint) : null,
        colorValue: colorValue.isNotEmpty ? int.tryParse(colorValue) : null,
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    // Navigate to specific screen if needed
  }

  Future<void> _showBuddyNudgeNotification({
    required String title,
    required String body,
    required String sound,
  }) async {
    print('👋 Showing buddy nudge with sound: $sound');
    
    if (Platform.isAndroid) {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'buddy_nudge_channel',
        'Buddy Nudges',
        channelDescription: 'Notifications when your buddy nudges you',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_ringtone'),
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
        title,
        body,
        notificationDetails,
        payload: 'buddy_nudge',
      );
      print('✅ Android buddy nudge notification shown');
    } else {
      // iOS: Show notification using local notifications
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch % 100000, // Unique ID
        title,
        body,
        notificationDetails,
        payload: 'buddy_nudge',
      );
      print('✅ iOS buddy nudge notification shown');
    }
  }

  // Helper method to generate a bitmap from a Flutter icon
  Future<List<int>?> _generateIconBitmap(int iconCodePoint, Color color) async {
    try {
      // Import dart:ui for image generation
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = 192.0; // Notification large icon size
      
      // Draw circular background
      final backgroundPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size / 2, size / 2),
        size / 2,
        backgroundPaint,
      );
      
      // Draw the icon
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconCodePoint),
        style: TextStyle(
          fontSize: size * 0.5, // Icon takes up 50% of the circle
          fontFamily: 'MaterialIcons',
          color: color,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size - textPainter.width) / 2,
          (size - textPainter.height) / 2,
        ),
      );
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('❌ Error generating icon bitmap: $e');
      return null;
    }
  }

  // Public method to show notification with action buttons (used by background handler)
  Future<void> showNotificationWithActions({
    required int id,
    required String title,
    required String body,
    required String payload,
    String? customIconUrl,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    return _showLocalNotificationWithActions(
      id: id,
      title: title,
      body: body,
      payload: payload,
      customIconUrl: customIconUrl,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
    );
  }

  Future<void> _showLocalNotificationWithActions({
    required int id,
    required String title,
    required String body,
    required String payload,
    String? customIconUrl,
    int? iconCodePoint,
    int? colorValue,
  }) async {
    // Determine color for notification (use reminder color if available)
    Color? notificationColor;
    if (colorValue != null) {
      notificationColor = Color(colorValue);
      print('🎨 Using reminder color: ${notificationColor.value.toRadixString(16)}');
    }

    // Generate or download large icon
    ByteArrayAndroidBitmap? largeIcon;
    if (Platform.isAndroid) {
      // Priority 1: Use custom image URL if provided
      if (customIconUrl != null && customIconUrl.isNotEmpty) {
        try {
          print('📥 Downloading custom icon from: $customIconUrl');
          final response = await http.get(Uri.parse(customIconUrl));
          if (response.statusCode == 200) {
            largeIcon = ByteArrayAndroidBitmap(response.bodyBytes);
            print('✅ Custom icon downloaded successfully');
          } else {
            print('❌ Failed to download icon: ${response.statusCode}');
          }
        } catch (e) {
          print('❌ Error downloading custom icon: $e');
        }
      }
      // Priority 2: Generate icon from iconCodePoint if no custom URL
      else if (iconCodePoint != null) {
        try {
          print('🎨 Generating icon from codePoint: $iconCodePoint');
          final iconBitmap = await _generateIconBitmap(
            iconCodePoint, 
            notificationColor ?? const Color(0xFFFFB4A3),
          );
          if (iconBitmap != null) {
            largeIcon = ByteArrayAndroidBitmap(Uint8List.fromList(iconBitmap));
            print('✅ Icon generated successfully');
          }
        } catch (e) {
          print('❌ Error generating icon: $e');
        }
      }
    }

    // Generate or download icon for iOS attachment
    String? iosAttachmentPath;
    if (Platform.isIOS) {
      try {
        // Priority 1: Use custom image URL
        if (customIconUrl != null && customIconUrl.isNotEmpty) {
          print('📥 [iOS] Downloading custom icon for attachment');
          final response = await http.get(Uri.parse(customIconUrl));
          if (response.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/notification_icon_$id.png');
            await file.writeAsBytes(response.bodyBytes);
            iosAttachmentPath = file.path;
            print('✅ [iOS] Custom icon saved to: $iosAttachmentPath');
          }
        }
        // Priority 2: Generate from iconCodePoint
        else if (iconCodePoint != null) {
          print('🎨 [iOS] Generating icon for attachment');
          final iconBitmap = await _generateIconBitmap(
            iconCodePoint,
            notificationColor ?? const Color(0xFFFFB4A3),
          );
          if (iconBitmap != null) {
            final tempDir = await getTemporaryDirectory();
            final file = File('${tempDir.path}/notification_icon_$id.png');
            await file.writeAsBytes(iconBitmap);
            iosAttachmentPath = file.path;
            print('✅ [iOS] Icon generated and saved to: $iosAttachmentPath');
          }
        }
      } catch (e) {
        print('❌ [iOS] Error preparing icon attachment: $e');
      }
    }

    // Get user's preferred notification sound
    final soundName = _getSafeNotificationSound();
    
    // Always use custom ringtone for reminder/snooze notifications
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'reminder_channel',
      'Reminders',
      channelDescription: 'Notification channel for reminders',
      importance: Importance.high,
      priority: Priority.high,
      sound: soundName == 'default' ? null : RawResourceAndroidNotificationSound(soundName),
      playSound: true,
      largeIcon: largeIcon, // Show custom icon as large icon
      color: notificationColor, // Set notification accent color
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'mark_done',
          'Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze_5',
          '5 min Snooze',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_input',
          'Custom Snooze',
          showsUserInterface: true,
          cancelNotification: false,
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: 'Enter minutes',
              allowFreeFormInput: true,
            ),
          ],
        ),
      ],
    );

    // iOS details with attachment
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: soundName == 'default' ? 'default' : '$soundName.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
      attachments: iosAttachmentPath != null
          ? [DarwinNotificationAttachment(iosAttachmentPath)]
          : null,
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
      sound: RawResourceAndroidNotificationSound(_getSafeNotificationSound()),
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

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'reminder_category',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '${_getSafeNotificationSound()}.wav',
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

  // Get device name/model
  Future<String> _getDeviceName() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // e.g., "Samsung Galaxy S21" or "Pixel 6"
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // e.g., "iPhone 13 Pro"
        return iosInfo.name;
      }
      return 'Unknown Device';
    } catch (e) {
      print('❌ Error getting device name: $e');
      return 'Unknown Device';
    }
  }

  // Save FCM token to Firestore for Cloud Functions
  Future<void> _saveFCMTokenToFirestore(String? token) async {
    if (token == null) {
      print('❌ FCM token is null, cannot save to Firestore');
      return;
    }
    
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) {
          if (attempt < 4) {
            print('⚠️ No user logged in (attempt ${attempt + 1}/5), retrying...');
            await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
            continue;
          } else {
            print('⚠️ No user logged in after 5 attempts');
            return;
          }
        }
        
        final deviceInfo = DeviceInfoPlugin();
        String deviceId;
        String deviceName;
        
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
          deviceName = '${androidInfo.brand} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? token;
          deviceName = iosInfo.name;
        } else {
          deviceId = token;
          deviceName = 'Unknown Device';
        }
        
        print('💾 Saving FCM token to devices collection...');
        print('Device ID: $deviceId');
        print('Device Name: $deviceName');
        print('Token: ${token.substring(0, 20)}...');
        print('User ID: $userId');
        
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .set({
          'deviceId': deviceId,
          'deviceName': deviceName,
          'fcmToken': token,
          'userId': userId,
          'lastUpdated': FieldValue.serverTimestamp(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
          'active': true,
        }, SetOptions(merge: true));
        
        print('✅ FCM Token saved to devices collection for user: $userId');
        
        final doc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .get();
        
        if (doc.exists) {
          print('✅ Verified: Device document exists');
        } else {
          print('❌ Warning: Device document not found after save');
        }
        
        break;
      } catch (e) {
        if (attempt < 4) {
          print('❌ Error saving FCM token (attempt ${attempt + 1}/5): $e');
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        } else {
          print('❌ Error saving FCM token after 5 attempts: $e');
        }
      }
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
        
        // Get device name
        final deviceName = await _getDeviceName();
        
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(token)
            .update({
          'active': true,
          'userId': userId,
          'deviceName': deviceName,
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
          print('   Device name: ${data?['deviceName']}');
        }
      } catch (e) {
        print('❌ Error reactivating device: $e');
        // If document doesn't exist, create it
        try {
          print('   Attempting to create device document...');
          final deviceName = await _getDeviceName();
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(token)
              .set({
            'fcmToken': token,
            'userId': userId,
            'lastUpdated': FieldValue.serverTimestamp(),
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'deviceName': deviceName,
            'active': true,
          });
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
