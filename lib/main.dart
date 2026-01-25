import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/notifications/notification_service.dart';
import 'features/reminders/data/reminder_service.dart';
import 'features/snooze/presentation/snooze_screen.dart';

// Global navigator key for navigation from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('🔔 [Background] Handling background message: ${message.messageId}');
  print('📦 [Background] Data: ${message.data}');

  final notificationService = NotificationService();
  await notificationService.initialize();

  // Check if it's a dismissal notification
  if (message.data.containsKey('type') &&
      message.data['type'] == 'dismiss_notification') {
    final reminderId = message.data['reminderId'] ?? '';
    if (reminderId.isNotEmpty) {
      print('🗑️ [Background] Dismissing notification for reminder: $reminderId');
      await notificationService.cancelNotification(reminderId);
      print('✅ [Background] Notification dismissed');
    } else {
      print('⚠️ [Background] Dismiss notification missing reminderId');
    }
    return;
  }

  // Show notification with action buttons when app is in background
  if (message.data.containsKey('type') &&
      message.data['type'] == 'reminder_notification') {
    final reminderId = message.data['reminderId'] ?? '';
    final title = message.data['title'] ?? 'Reminder';
    final body = message.data['body'] ?? 'Your reminder is due!';

    print('📨 [Background] Showing reminder notification: $title');

    // Import flutter_local_notifications to show notification
    await notificationService.showNotificationWithActions(
      id: reminderId.hashCode,
      title: title,
      body: body,
      payload: reminderId,
    );
    
    print('✅ [Background] Notification shown');
  } else {
    print('ℹ️ [Background] Non-reminder notification or missing data');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service with error handling
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Check for any pending reminders that might have been missed
    await notificationService.checkPendingReminders('demo_user');

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Set up notification action handler
    notificationService.onNotificationAction = (reminderId, action) async {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🎯 [main.dart] Notification action handler called');
      print('📝 Action: $action');
      print('📝 Reminder ID: $reminderId');
      print('🕐 Timestamp: ${DateTime.now().toIso8601String()}');
      print('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');

      final reminderService = ReminderService();

      if (action == 'mark_done' || action == 'done') {
        print('✅ [main.dart] Handling mark_done/done action');
        // Mark reminder as completed
        if (!reminderId.startsWith('test_reminder')) {
          print('💾 [main.dart] Calling reminderService.markAsCompleted()...');
          await reminderService.markAsCompleted(reminderId);
          print('🗑️ [main.dart] Calling notificationService.cancelNotification()...');
          await notificationService.cancelNotification(reminderId);
          print('✅ [main.dart] Reminder marked as done and notification cancelled');
        } else {
          print('⏭️ [main.dart] Skipping test reminder');
        }
      } else if (action == 'snooze') {
        print('⏰ [main.dart] Handling snooze action');
        // Navigate to snooze screen
        final context = navigatorKey.currentContext;
        print('🧭 [main.dart] Navigator context: ${context != null ? "available" : "null"}');

        if (context != null) {
          String reminderTitle = '🧪 Test Reminder';

          // Get reminder details if it's a real reminder
          if (!reminderId.startsWith('test_reminder')) {
            print('📖 [main.dart] Fetching reminder details...');
            final reminder = await reminderService.getReminder(reminderId);
            if (reminder != null) {
              reminderTitle = reminder.name;
              print('📝 [main.dart] Reminder title: $reminderTitle');
            } else {
              print('⚠️ [main.dart] Reminder not found');
            }
          }

          print('🧭 [main.dart] Navigating to SnoozeScreen with title: $reminderTitle');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SnoozeScreen(
                reminderId: reminderId,
                reminderTitle: reminderTitle,
              ),
            ),
          );
        } else {
          print('❌ [main.dart] Cannot navigate: context is null');
        }
      } else {
        print('⚠️ [main.dart] Unknown action: $action');
      }
      
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    };
  } catch (e, stackTrace) {
    print('❌ Error initializing notification service: $e');
    print('Stack trace: $stackTrace');
    // Continue anyway - the app will work without notifications
  }

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
              return const HomeScreen();
            } else {
              return const WelcomeScreen();
            }
          },
        ),
      ),
    );
  }
}
