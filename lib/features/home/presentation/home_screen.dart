import 'package:flutter/material.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/presentation/create_reminder_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Reminder> _reminders = [];

  void _navigateToCreateReminder() async {
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateReminderScreen(),
      ),
    );

    if (result != null) {
      setState(() {
        _reminders.add(result);
      });
    }
  }

  void _deleteReminder(String id) {
    setState(() {
      _reminders.removeWhere((reminder) => reminder.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reminders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _reminders.isEmpty
          ? const Center(
              child: Text(
                'No reminders yet.\nTap + to add one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _reminders.length,
              itemBuilder: (context, index) {
                final reminder = _reminders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.deepPurple),
                    title: Text(
                      reminder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy - hh:mm a').format(reminder.time),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteReminder(reminder.id),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateReminder,
        tooltip: 'Add Reminder',
        child: const Icon(Icons.add),
      ),
    );
  }
}
