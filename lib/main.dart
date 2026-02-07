import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/notifications/notification_service.dart';
import 'features/reminders/data/reminder_service.dart';
import 'features/reminders/presentation/create_reminder_screen.dart';
import 'features/snooze/presentation/snooze_screen.dart';
import 'services/local_storage_service.dart';
import 'services/theme_service.dart';
import 'services/theme_notifier.dart';
import 'services/revenue_cat_service.dart';
import 'shared/widgets/onboarding_gate.dart';

// Global navigator key for navigation from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Navigation channel for widget interactions
const MethodChannel navigationChannel = MethodChannel('navigation_channel');

// Device deletion listener subscription
StreamSubscription<DocumentSnapshot>? _deviceListenerSubscription;

// Listen for device removal and navigate to sign-in screen
Future<void> _listenForDeviceRemoval(String userId) async {
  try {
    final deviceInfo = DeviceInfoPlugin();
    String deviceId;
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? '';
    } else {
      return;
    }
    
    if (deviceId.isEmpty) return;
    
    await _deviceListenerSubscription?.cancel();
    
    _deviceListenerSubscription = FirebaseFirestore.instance
        .collection('devices')
        .doc(deviceId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists || snapshot.data()?['active'] == false) {
        print('🚨 Device removed or deactivated - signing out');
        await FirebaseAuth.instance.signOut();
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      }
    }, onError: (error) {
      print('❌ Error listening to device: $error');
    });
  } catch (e) {
    print('❌ Error setting up device listener: $e');
  }
}

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');
  print('Data: ${message.data}');

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Check if it's a dismissal notification
  if (message.data.containsKey('type') &&
      message.data['type'] == 'dismiss_notification') {
    final reminderId = message.data['reminderId'] ?? '';
    if (reminderId.isNotEmpty) {
      print('Dismissing notification for reminder: $reminderId');
      await notificationService.cancelNotification(reminderId);
    }
    return;
  }

  // Show notification with action buttons when app is in background
  if (message.data.containsKey('type') &&
      message.data['type'] == 'reminder_notification') {
    final reminderId = message.data['reminderId'] ?? '';
    final title = message.data['title'] ?? 'Reminder';
    final body = message.data['body'] ?? 'Your reminder is due!';
    
    // Extract icon and color data
    final customIconUrl = message.data['customIconUrl'] ?? '';
    final iconCodePoint = message.data['iconCodePoint'] ?? '';
    final colorValue = message.data['colorValue'] ?? '';

    // Import flutter_local_notifications to show notification
    await notificationService.showNotificationWithActions(
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize theme notifier with saved preferences
  final themeService = ThemeService();
  final savedColor = await themeService.getAccentColor();
  final savedTheme = await themeService.getThemePreference();
  final savedFontSize = await themeService.getFontSizeScale();
  ThemeNotifier.instance.initialize(
    accentColor: savedColor,
    themeMode: savedTheme,
    fontSizeScale: savedFontSize,
  );

  // Set background message handler (needs to be set early)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize RevenueCat (optional: pass userId if user is logged in)
  // Using configured API keys in RevenueCatService
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await RevenueCatService().initialize(userId: user.uid);
  } else {
    await RevenueCatService().initialize();
  }

  // Set up navigation channel handler for Android widgets
  navigationChannel.setMethodCallHandler((call) async {
    if (call.method == 'navigateToCreateReminder') {
      print('📱 Received navigateToCreateReminder from widget');
      final context = navigatorKey.currentContext;
      if (context != null && FirebaseAuth.instance.currentUser != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const NewReminderScreen()),
        );
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeNotifier.instance;

    return ScreenUtilInit(
      designSize: const Size(484, 1048),
      useInheritedMediaQuery: true,
      minTextAdapt: true,
      splitScreenMode: true,
      child: AnimatedBuilder(
        animation: themeNotifier,
        builder: (context, _) {
          final isDark = themeNotifier.isDarkMode;
          final bgColor = isDark ? const Color(0xFF121212) : Colors.white;

          // Map stored string to Flutter ThemeMode
          final modeString = themeNotifier.themeMode;
          final themeMode = modeString == 'dark'
              ? ThemeMode.dark
              : modeString == 'system'
                  ? ThemeMode.system
                  : ThemeMode.light;

          final lightColorScheme = ColorScheme.fromSeed(
            seedColor: themeNotifier.accentColor,
            brightness: Brightness.light,
          );

          final darkColorScheme = ColorScheme.fromSeed(
            seedColor: themeNotifier.accentColor,
            brightness: Brightness.dark,
            surface: bgColor,
          );

          return MaterialApp(
            title: 'Cue',
            navigatorKey: navigatorKey,
            themeMode: themeMode,
            builder: (context, child) {
              // Apply global text scale factor based on user preference
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaleFactor: themeNotifier.fontSizeScale,
                ),
                child: child!,
              );
            },
            theme: ThemeData(
              colorScheme: lightColorScheme.copyWith(
                surface: bgColor,
              ),
              scaffoldBackgroundColor: bgColor,
              canvasColor: bgColor,
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: darkColorScheme,
              scaffoldBackgroundColor: bgColor,
              canvasColor: bgColor,
              useMaterial3: true,
            ),
            debugShowCheckedModeBanner: false,
            home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Show loading while checking auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF4A4458),
                body: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFFB4A3)),
                ),
              );
            }

            // Show home screen if user is logged in, otherwise show welcome screen
            if (snapshot.hasData) {
              _listenForDeviceRemoval(snapshot.data!.uid);
              
              // Initialize notifications after user is authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final notificationService = NotificationService();
                  await notificationService.initialize();
                  
                  await notificationService.ensureDeviceRegistered();

                  // Check for any pending reminders that might have been missed
                  await notificationService.checkPendingReminders(snapshot.data!.uid);

                  // Set up notification action handler
                  notificationService.onNotificationAction = (reminderId, action) async {
                    print('🎯 Notification action handler called:');
                    print('  - Action: $action');
                    print('  - Reminder ID: $reminderId');

                    // Declare variables outside try block so they're accessible in catch
                    String actualReminderId = reminderId;
                    int? customMinutes;

                    try {
                      final reminderService = ReminderService();
                      
                      // Check if reminderId contains custom input (format: reminderId:minutes)
                      if (reminderId.contains(':')) {
                        final parts = reminderId.split(':');
                        actualReminderId = parts[0];
                        customMinutes = int.tryParse(parts[1]);
                        print('  - Parsed custom minutes: $customMinutes from input: ${parts[1]}');
                      }

                      if (action == 'mark_done' || action == 'done') {
                        print('✅ Handling mark_done/done action');
                        // Mark reminder as completed
                        if (!actualReminderId.startsWith('test_reminder')) {
                          await reminderService.markAsCompleted(actualReminderId);
                        }
                      } else if (action == 'snooze_input') {
                        print('⏰ Handling custom snooze input');
                        print('  - customMinutes value: $customMinutes');
                        
                        if (customMinutes != null && customMinutes > 0) {
                          // Valid input (any positive number)
                          print('✅ Valid input, snoozing for $customMinutes minutes');
                          if (!actualReminderId.startsWith('test_reminder')) {
                            await reminderService.snoozeReminder(actualReminderId, minutes: customMinutes);
                          }
                        } else {
                          print('❌ Invalid custom minutes: $customMinutes (must be at least 1)');
                        }
                      } else if (action == 'snooze_5') {
                        print('⏰ Handling 5-minute snooze');
                        if (!actualReminderId.startsWith('test_reminder')) {
                          await reminderService.snoozeReminder(actualReminderId, minutes: 5);
                        }
                      } else if (action == 'snooze_10') {
                        print('⏰ Handling 10-minute snooze');
                        if (!actualReminderId.startsWith('test_reminder')) {
                          await reminderService.snoozeReminder(actualReminderId, minutes: 10);
                        }
                      } else if (action == 'snooze_15') {
                        print('⏰ Handling 15-minute snooze');
                        if (!actualReminderId.startsWith('test_reminder')) {
                          await reminderService.snoozeReminder(actualReminderId, minutes: 15);
                        }
                      } else if (action == 'snooze' || action == 'snooze_custom') {
                      print('⏰ Handling custom snooze action - opening snooze screen');
                      // Navigate to snooze screen for custom time
                      final context = navigatorKey.currentContext;
                      print('  - Navigator context: ${context != null ? "available" : "null"}');

                      if (context != null) {
                        String reminderTitle = '🧪 Test Reminder';

                        // Get reminder details if it's a real reminder
                        if (!actualReminderId.startsWith('test_reminder')) {
                          final reminder = await reminderService.getReminder(actualReminderId);
                          if (reminder != null) {
                            reminderTitle = reminder.name;
                          }
                        }

                        print('  - Navigating to SnoozeScreen with title: $reminderTitle');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SnoozeScreen(
                              reminderId: actualReminderId,
                              reminderTitle: reminderTitle,
                            ),
                          ),
                        );
                      } else {
                        print('❌ Cannot navigate: context is null');
                      }
                    } else {
                      print('⚠️ Unknown action: $action');
                    }
                    print('✅ Action handler completed successfully');
                  } catch (e, stackTrace) {
                    print('❌ Error in notification action handler:');
                    print('  - Error: $e');
                    print('  - Stack trace: $stackTrace');
                    // Cancel notification even on error to prevent "loading" state
                    try {
                      await notificationService.cancelNotification(actualReminderId);
                    } catch (cancelError) {
                      print('❌ Failed to cancel notification: $cancelError');
                    }
                  }
                  };
                } catch (e, stackTrace) {
                  print('❌ Error initializing notification service: $e');
                  print('Stack trace: $stackTrace');
                  // Continue anyway - the app will work without notifications
                }
              });

              return const OnboardingGate();
            } else {
              return const WelcomeScreen();
            }
          },
        ),
      );},
      ),
    );
  }
}
