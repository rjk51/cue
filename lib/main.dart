import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/notifications/notification_service.dart';
import 'features/reminders/data/reminder_service.dart';

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling background message: ${message.messageId}');
  print('Data: ${message.data}');
  
  // Show notification with action buttons when app is in background
  if (message.data.containsKey('type') && 
      message.data['type'] == 'reminder_notification') {
    final notificationService = NotificationService();
    await notificationService.initialize();
    
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
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  // Check for any pending reminders that might have been missed
  await notificationService.checkPendingReminders('demo_user');
  
  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Set up notification action handler
  notificationService.onNotificationAction = (reminderId, action) async {
    print('Notification action: $action for reminder: $reminderId');
    
    final reminderService = ReminderService();
    
    if (action == 'mark_done') {
      // Mark reminder as completed
      await reminderService.markAsCompleted(reminderId);
      await notificationService.cancelNotification(reminderId);
    } else if (action == 'snooze') {
      // Snooze reminder for 10 minutes
      await reminderService.snoozeReminder(reminderId);
      await notificationService.cancelNotification(reminderId);
      
      // Get updated reminder and reschedule
      final reminder = await reminderService.getReminder(reminderId);
      if (reminder != null) {
        await notificationService.scheduleReminderNotification(reminder);
      }
    }
  };
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cue',
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
                child: CircularProgressIndicator(
                  color: Color(0xFFFFB4A3),
                ),
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
    );
  }
}
