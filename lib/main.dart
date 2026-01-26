import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/notifications/notification_service.dart';
import 'features/reminders/data/reminder_service.dart';
import 'features/snooze/presentation/snooze_screen.dart';
import 'services/local_storage_service.dart';
import 'services/theme_service.dart';
import 'services/theme_notifier.dart';
import 'shared/widgets/onboarding_gate.dart';

// Global navigator key for navigation from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

    // Import flutter_local_notifications to show notification
    await notificationService.showNotificationWithActions(
      id: reminderId.hashCode,
      title: title,
      body: body,
      payload: reminderId,
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
  ThemeNotifier.instance.initialize(
    accentColor: savedColor,
    themeMode: savedTheme,
  );

  // Set background message handler (needs to be set early)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(484, 1048),
      useInheritedMediaQuery: true,
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        title: 'Cue',
        navigatorKey: navigatorKey,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
              // Initialize notifications after user is authenticated
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final notificationService = NotificationService();
                  await notificationService.initialize();

                  // Check for any pending reminders that might have been missed
                  await notificationService.checkPendingReminders(snapshot.data!.uid);

                  // Set up notification action handler
                  notificationService.onNotificationAction = (reminderId, action) async {
                    print('🎯 Notification action handler called:');
                    print('  - Action: $action');
                    print('  - Reminder ID: $reminderId');

                    final reminderService = ReminderService();
                    
                    // Check if reminderId contains custom input (format: reminderId:minutes)
                    String actualReminderId = reminderId;
                    int? customMinutes;
                    
                    if (reminderId.contains(':')) {
                      final parts = reminderId.split(':');
                      actualReminderId = parts[0];
                      customMinutes = int.tryParse(parts[1]);
                      print('  - Parsed custom minutes: $customMinutes');
                    }

                    if (action == 'mark_done' || action == 'done') {
                      print('✅ Handling mark_done/done action');
                      // Mark reminder as completed
                      if (!actualReminderId.startsWith('test_reminder')) {
                        await reminderService.markAsCompleted(actualReminderId);
                        await notificationService.cancelNotification(actualReminderId);
                      }
                    } else if (action == 'snooze_input') {
                      print('⏰ Handling custom snooze input');
                      if (customMinutes != null && customMinutes > 0 && customMinutes <= 1440) {
                        // Valid input (1-1440 minutes = 24 hours max)
                        if (!actualReminderId.startsWith('test_reminder')) {
                          await reminderService.snoozeReminder(actualReminderId, minutes: customMinutes);
                          await notificationService.cancelNotification(actualReminderId);
                        }
                      } else {
                        print('❌ Invalid custom minutes: $customMinutes');
                      }
                    } else if (action == 'snooze_5') {
                      print('⏰ Handling snooze 5 minutes action');
                      if (!actualReminderId.startsWith('test_reminder')) {
                        await reminderService.snoozeReminder(actualReminderId, minutes: 5);
                        await notificationService.cancelNotification(actualReminderId);
                      }
                    } else if (action == 'snooze_10') {
                      print('⏰ Handling snooze 10 minutes action');
                      if (!actualReminderId.startsWith('test_reminder')) {
                        await reminderService.snoozeReminder(actualReminderId, minutes: 10);
                        await notificationService.cancelNotification(actualReminderId);
                      }
                    } else if (action == 'snooze_15') {
                      print('⏰ Handling snooze 15 minutes action');
                      if (!actualReminderId.startsWith('test_reminder')) {
                        await reminderService.snoozeReminder(actualReminderId, minutes: 15);
                        await notificationService.cancelNotification(actualReminderId);
                        // Dismiss notification on all devices (Done button logic)
                        // await reminderService.dismissOnAllDevices(actualReminderId);
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
      ),
    );
  }
}
