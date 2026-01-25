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
      print('🎯 Notification action handler called:');
      print('  - Action: $action');
      print('  - Reminder ID: $reminderId');

      final reminderService = ReminderService();

      if (action == 'mark_done' || action == 'done') {
        print('✅ Handling mark_done/done action');
        // Mark reminder as completed
        if (!reminderId.startsWith('test_reminder')) {
          await reminderService.markAsCompleted(reminderId);
          await notificationService.cancelNotification(reminderId);
        }
      } else if (action == 'snooze') {
        print('⏰ Handling snooze action');
        // Navigate to snooze screen
        final context = navigatorKey.currentContext;
        print('  - Navigator context: ${context != null ? "available" : "null"}');

        if (context != null) {
          String reminderTitle = '🧪 Test Reminder';

          // Get reminder details if it's a real reminder
          if (!reminderId.startsWith('test_reminder')) {
            final reminder = await reminderService.getReminder(reminderId);
            if (reminder != null) {
              reminderTitle = reminder.name;
            }
          }

          print('  - Navigating to SnoozeScreen with title: $reminderTitle');
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
