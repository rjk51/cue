import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../reminders/domain/reminder_model.dart';
import '../domain/recurrence_rule.dart';
import '../../reminders/data/reminder_service.dart';
import '../../notifications/notification_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'recurrence_rule_screen.dart';

class CreateReminderScreen extends StatefulWidget {
  const CreateReminderScreen({super.key});

  @override
  State<CreateReminderScreen> createState() => _CreateReminderScreenState();
}

class _CreateReminderScreenState extends State<CreateReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ReminderService _reminderService = ReminderService();
  final NotificationService _notificationService = NotificationService();
  DateTime _selectedDateTime = DateTime.now();
  RecurrenceRule? _recurrenceRule;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  Future<void> _openRecurrenceRule() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDateTime.isBefore(DateTime.now())) {
      context.showWarningSnackbar('Please select a future date and time');
      return;
    }

    final result = await Navigator.push<RecurrenceRule?>(
      context,
      MaterialPageRoute(
        builder: (context) => RecurrenceRuleScreen(
          initialStartDate: _selectedDateTime,
          initialTimeOfDay: TimeOfDay.fromDateTime(_selectedDateTime),
          initialRule: _recurrenceRule,
        ),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _recurrenceRule = null;
      });
      context.showInfoSnackbar('Recurrence skipped');
      return;
    }

    final nextDue = result.nextOccurrence(from: DateTime.now());
    if (nextDue == null) {
      context.showWarningSnackbar('Recurrence ends before today. Please adjust dates.');
      return;
    }

    setState(() {
      _recurrenceRule = result;
      _selectedDateTime = nextDue;
    });

    await _saveReminder(recurrenceRule: result);
  }

  Future<void> _saveReminder({RecurrenceRule? recurrenceRule}) async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;

    final recurrence = recurrenceRule ?? _recurrenceRule;
    final scheduledTime = recurrence?.nextOccurrence(from: DateTime.now()) ?? _selectedDateTime;

    if (scheduledTime.isBefore(DateTime.now())) {
      context.showWarningSnackbar('Please select a future date and time');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        time: scheduledTime,
        nextDueAt: recurrence != null ? scheduledTime : null,
        recurrence: recurrence?.toBackendConfig(),
        isCompleted: false,
        deviceToken: _notificationService.fcmToken,
        userId: 'demo_user', // Replace with actual user ID from auth
      );

      final reminderId = await _reminderService.addReminder(
        reminder,
        _notificationService.fcmToken,
      );

      final savedReminder = reminder.copyWith(id: reminderId);
      await _notificationService.scheduleReminderNotification(savedReminder);

      if (mounted) {
        Navigator.pop(context, savedReminder);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error creating reminder: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Reminder'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.r),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Reminder Name',
                  hintText: 'Enter reminder name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a reminder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Date'),
                      subtitle: Text(
                        '${_selectedDateTime.day}/${_selectedDateTime.month}/${_selectedDateTime.year}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectDate,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Time'),
                      subtitle: Text(
                        '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),
              if (_recurrenceRule != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.repeat),
                    title: const Text('Recurrence configured'),
                    subtitle: Text(_recurrenceRule!.summary()),
                    trailing: TextButton(
                      onPressed: _isSaving ? null : _openRecurrenceRule,
                      child: const Text('Edit'),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _openRecurrenceRule,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      child: Text(
                        'Next: Recurrence',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => _saveReminder(),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 20.h,
                              width: 20.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Save Reminder',
                              style: TextStyle(fontSize: 16.sp),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
