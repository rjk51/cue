import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/domain/suggestion_model.dart';
import '../../reminders/presentation/create_reminder_screen.dart';
import '../../reminders/presentation/recurrence_rule_screen.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/data/suggestion_service.dart';
import '../../notifications/notification_service.dart';
import '../../../services/auth_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/presentation/welcome_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ReminderService _reminderService = ReminderService();
  final SuggestionService _suggestionService = SuggestionService();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Subscribe to user topic for cross-device notifications
    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'demo_user';
    _notificationService.subscribeToUserTopic(userId);
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar('Error signing out: $e');
        }
      }
    }
  }

  void _navigateToCreateReminder() async {
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateReminderScreen(),
      ),
    );

    if (result != null && mounted) {
      context.showSuccessSnackbar('Reminder created successfully!');
    }
  }

  void _navigateToRecurrenceRule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecurrenceRuleScreen(),
      ),
    );
  }

  Future<void> _markAsCompleted(String reminderId) async {
    try {
      await _reminderService.markAsCompleted(reminderId);
      await _notificationService.cancelNotification(reminderId);
      
      if (mounted) {
        context.showSuccessSnackbar('Reminder marked as completed!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await _reminderService.deleteReminder(reminderId);
      await _notificationService.cancelNotification(reminderId);
      
      if (mounted) {
        context.showWarningSnackbar('Reminder deleted!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    }
  }

  Widget _buildSuggestionsSection(
    bool isLoading,
    Object? error,
    List<Suggestion> suggestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
          child: Text(
            'Recurrence Suggestions',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (isLoading)
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null)
          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: const Text('Could not load suggestions'),
              subtitle: Text('$error'),
            ),
          )
        else if (suggestions.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.repeat, color: Colors.grey),
              title: const Text('No recurrence suggestions yet'),
              subtitle: const Text('Create a recurring reminder to see it here.'),
            ),
          )
        else
          ...suggestions.map(_buildSuggestionCard),
      ],
    );
  }

  Widget _buildSuggestionCard(Suggestion suggestion) {
    final nextDueText = suggestion.nextDueAt != null
        ? DateFormat('MMM dd, yyyy - hh:mm a').format(suggestion.nextDueAt!)
        : 'Next occurrence not set';
    final recurrenceType = (suggestion.recurrence?['frequency'] as String? ??
        suggestion.recurrence?['type'] as String? ??
        'recurring')
      .toUpperCase();

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: const Icon(Icons.repeat, color: Colors.white),
        ),
        title: Text(
          suggestion.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4.h),
            Text('Next: $nextDueText'),
            SizedBox(height: 2.h),
            Text('Recurrence: $recurrenceType'),
          ],
        ),
        trailing: Chip(
          label: Text(
            suggestion.status.toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildRemindersSection(
    bool isLoading,
    Object? error,
    List<Reminder> reminders,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Card(
        color: Colors.red.shade50,
        child: ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Could not load reminders'),
          subtitle: Text('$error'),
        ),
      );
    }

    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 64.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              'No reminders yet.\nTap + to add one!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18.sp, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: reminders.map((reminder) {
        final isPast = reminder.time.isBefore(DateTime.now());

        return Card(
          margin: EdgeInsets.symmetric(vertical: 4.h),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPast ? Colors.orange : Colors.deepPurple,
              child: Icon(
                isPast ? Icons.notification_important : Icons.notifications,
                color: Colors.white,
              ),
            ),
            title: Text(
              reminder.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4.h),
                Text(
                  DateFormat('MMM dd, yyyy - hh:mm a').format(reminder.time),
                ),
                if (isPast)
                  const Text(
                    'Overdue',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Mark as Done',
                  onPressed: () => _markAsCompleted(reminder.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () => _deleteReminder(reminder.id),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reminders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Test Notification',
            onPressed: () async {
              await _notificationService.showTestNotification();
              if (mounted) {
                context.showInfoSnackbar('Test notification sent!');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('FCM Token'),
                  content: SelectableText(
                    _notificationService.fcmToken ?? 'Token not available',
                    style: const TextStyle(fontSize: 12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Suggestion>>(
        stream: _suggestionService.getSuggestionsStream(),
        builder: (context, suggestionSnapshot) {
          return StreamBuilder<List<Reminder>>(
            stream: _reminderService.getRemindersStream(),
            builder: (context, reminderSnapshot) {
              final suggestions = suggestionSnapshot.data ?? [];
              final reminders = reminderSnapshot.data ?? [];

              final loadingSuggestions =
                  suggestionSnapshot.connectionState == ConnectionState.waiting &&
                  suggestions.isEmpty;
              final loadingReminders =
                  reminderSnapshot.connectionState == ConnectionState.waiting &&
                  reminders.isEmpty;

              if (loadingSuggestions && loadingReminders) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: EdgeInsets.all(8.r),
                children: [
                  _buildSuggestionsSection(
                    loadingSuggestions,
                    suggestionSnapshot.hasError ? suggestionSnapshot.error : null,
                    suggestions,
                  ),
                  SizedBox(height: 12.h),
                  _buildRemindersSection(
                    loadingReminders,
                    reminderSnapshot.hasError ? reminderSnapshot.error : null,
                    reminders,
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Temporary FAB for testing Recurrence Rule screen
          FloatingActionButton(
            heroTag: 'recurrence_rule_fab',
            onPressed: _navigateToRecurrenceRule,
            tooltip: 'Recurrence Rule (Test)',
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.repeat),
          ),
          SizedBox(height: 16.h),
          FloatingActionButton(
            heroTag: 'add_reminder_fab',
            onPressed: _navigateToCreateReminder,
            tooltip: 'Add Reminder',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
