import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

import '../domain/recurrence_rule.dart';
import '../domain/reminder_model.dart';
import '../data/reminder_service.dart';
import '../../notifications/notification_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'widgets/icon_picker_sheet.dart';

class NewReminderScreen extends StatefulWidget {
  const NewReminderScreen({super.key});

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen> {
  final ThemeService _themeService = ThemeService();
  final ReminderService _reminderService = ReminderService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _reminderController = TextEditingController();

  Color _accentColor = const Color(0xFFFFB4A3);
  bool _isDarkMode = false;
  bool _isSaving = false;

  // Reminder fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now());
  bool _repeatEnabled = false;

  // Recurrence fields (only used when repeat is enabled)
  RecurrenceFrequency _selectedFrequency = RecurrenceFrequency.weekly;
  Set<int> _selectedDays = {};
  DateTime? _endDate;
  bool _endDateEnabled = false;

  // Icon and color
  IconData _selectedIcon = Icons.notification_important_outlined;
  Color _selectedColor = const Color(0xFFFFB4A3);

  // Map day indices to abbreviated names
  final List<String> _dayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selectedDays = {_selectedDate.weekday};
    _loadThemeSettings();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _reminderController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _accentColor = ThemeNotifier.instance.accentColor;
        _isDarkMode = ThemeNotifier.instance.isDarkMode;
      });
    }
  }

  Future<void> _loadThemeSettings() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();
    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _selectedColor = accentColor;
        if (themePreference == 'system') {
          _isDarkMode =
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark;
        } else {
          _isDarkMode = themePreference == 'dark';
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _selectedDate.add(const Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      if (_selectedDays.contains(dayIndex)) {
        _selectedDays.remove(dayIndex);
      } else {
        _selectedDays.add(dayIndex);
      }
    });
  }

  Future<void> _openIconPicker() async {
    final result = await showModalBottomSheet<IconData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IconPickerSheet(
        accentColor: _accentColor,
        isDarkMode: _isDarkMode,
        initialIcon: _selectedIcon,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedIcon = result;
      });
    }
  }

  Future<void> _openColorPicker() async {
    Color pickedColor = _selectedColor;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode
            ? const Color.fromARGB(255, 33, 36, 39)
            : Colors.white,
        title: Text(
          'Choose Color',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: pickedColor,
            onColorChanged: (Color color) {
              pickedColor = color;
            },
            width: 40.w,
            height: 40.h,
            borderRadius: 20.r,
            spacing: 5.w,
            runSpacing: 5.h,
            wheelDiameter: 250.w,
            heading: Text(
              'Select color',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            subheading: Text(
              'Select color shade',
              style: TextStyle(
                fontSize: 14.sp,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            pickersEnabled: const {
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedColor = pickedColor;
              });
              Navigator.pop(context);
            },
            child: Text(
              'Select',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _generateNextOccurrences() {
    if (!_repeatEnabled) return [];
    
    final rule = _buildRule();
    final occurrences = <Map<String, String>>[];
    DateTime? cursor = rule.nextOccurrence(from: DateTime.now());
    int safety = 0;

    while (cursor != null && occurrences.length < 3 && safety < 12) {
      occurrences.add({
        'title': DateFormat('EEEE, MMM dd').format(cursor),
        'subtitle': _relativeSubtitle(cursor),
        'time': DateFormat('hh:mm a').format(cursor),
      });

      cursor = rule.nextOccurrence(from: cursor.add(const Duration(minutes: 1)));
      safety++;
    }

    return occurrences;
  }

  String _relativeSubtitle(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    final days = diff.inDays;
    if (days <= 0) {
      final hours = diff.inHours;
      if (hours <= 0) {
        return 'In less than 1 hour';
      }
      return 'In $hours hour${hours == 1 ? '' : 's'}';
    }
    return 'In $days day${days == 1 ? '' : 's'}';
  }

  List<TextSpan> _buildSummaryTextSpans(Color textColor) {
    final List<TextSpan> spans = [];
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    // "Remind me to"
    spans.add(TextSpan(
      text: 'Remind me to ',
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
    ));

    // [Reminder name]
    final reminderText = _reminderController.text.trim().isEmpty
        ? '.....'
        : _reminderController.text.trim();
    spans.add(TextSpan(
      text: reminderText,
      style:  TextStyle(
        color: _accentColor,
        fontWeight: FontWeight.w600,
        decoration: reminderText == '.....' ? TextDecoration.none : TextDecoration.underline,
        decorationColor: _accentColor,
      ),
    ));

    // " at"
    spans.add(TextSpan(
      text: ' at ',
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
    ));

    // Time
    final hour = _selectedTime.hourOfPeriod == 0 ? 12 : _selectedTime.hourOfPeriod;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    spans.add(TextSpan(
      text: '$hour:$minute $period',
      style:  TextStyle(
        color: _accentColor,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline,
        decorationColor: _accentColor,
      ),
    ));

    // Date part
    if (_repeatEnabled) {
      spans.add(TextSpan(
        text: ' starting from ',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ));
    } else {
      spans.add(TextSpan(
        text: isToday ? ' today' : ' on ',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ));
    }

    if (!isToday || _repeatEnabled) {
      final dateText = DateFormat('MMM dd, yyyy').format(_selectedDate);
      spans.add(TextSpan(
        text: dateText,
        style:  TextStyle(
          color: _accentColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _accentColor,
        ),
      ));
    }

    // Repeat part
    if (_repeatEnabled) {
      String frequencyText = '';
      switch (_selectedFrequency) {
        case RecurrenceFrequency.daily:
          frequencyText = 'daily';
          break;
        case RecurrenceFrequency.weekly:
          frequencyText = 'weekly';
          break;
        case RecurrenceFrequency.monthly:
          frequencyText = 'monthly';
          break;
        case RecurrenceFrequency.yearly:
          frequencyText = 'yearly';
          break;
      }

      spans.add(TextSpan(
        text: ', repeating ',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ));

      spans.add(TextSpan(
        text: frequencyText,
        style:  TextStyle(
          color: _accentColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _accentColor,
        ),
      ));

      if (_endDateEnabled && _endDate != null) {
        spans.add(TextSpan(
          text: ' until ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ));

        spans.add(TextSpan(
          text: DateFormat('MMM dd, yyyy').format(_endDate!),
          style:  TextStyle(
            color: _accentColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _accentColor,
          ),
        ));
      }
    }

    spans.add(TextSpan(
      text: '.',
      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
    ));

    return spans;
  }

  RecurrenceRule _buildRule() {
    return RecurrenceRule(
      frequency: _selectedFrequency,
      selectedWeekDays: _selectedDays,
      timeOfDay: _selectedTime,
      startDate: _selectedDate,
      endDate: _endDateEnabled ? _endDate : null,
    );
  }

  Future<void> _saveReminder() async {
    if (_isSaving) return;

    final reminderText = _reminderController.text.trim();
    if (reminderText.isEmpty) {
      context.showWarningSnackbar('Please enter a reminder name');
      return;
    }

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    RecurrenceRule? recurrenceRule;
    DateTime finalScheduledTime = scheduledDateTime;

    if (_repeatEnabled) {
      recurrenceRule = _buildRule();
      final nextOccurrence = recurrenceRule.nextOccurrence(from: DateTime.now());
      
      if (nextOccurrence == null) {
        context.showWarningSnackbar('Recurrence ends before today. Please adjust dates.');
        return;
      }
      
      finalScheduledTime = nextOccurrence;
    }

    if (finalScheduledTime.isBefore(DateTime.now())) {
      context.showWarningSnackbar('Please select a future date and time');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: reminderText,
        time: finalScheduledTime,
        nextDueAt: recurrenceRule != null ? finalScheduledTime : null,
        recurrence: recurrenceRule?.toBackendConfig(),
        isCompleted: false,
        deviceToken: _notificationService.fcmToken,
        userId: 'demo_user',
        iconCodePoint: _selectedIcon.codePoint,
        colorValue: _selectedColor.value,
      );

      final reminderId = await _reminderService.addReminder(
        reminder,
        _notificationService.fcmToken,
      );

      final savedReminder = reminder.copyWith(id: reminderId);
      await _notificationService.scheduleReminderNotification(savedReminder);

      if (mounted) {
        Navigator.pop(context, savedReminder);
        context.showSuccessSnackbar('Reminder created successfully!');
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
    // Match home screen colors
    final backgroundColor = _isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!;

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor = _isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);
    
    final dividerColor = _isDarkMode
        ? const Color.fromARGB(255, 44, 48, 53)
        : Colors.grey.withOpacity(0.2);
    
    final inputBgColor = _isDarkMode
        ? const Color(0xFF1A1F2E)
        : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Icon(Icons.close, color: textColor, size: 24.sp),
        ),
        centerTitle: true,
        title: Text(
          'New Reminder',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveReminder,
            child: _isSaving
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accentColor,
                    ),
                  )
                : Text(
                    'Save',
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Summary Text
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 22.sp,
                    height: 1.4,
                    color: textColor,
                  ),
                  children: _buildSummaryTextSpans(textColor),
                ),
              ),

              SizedBox(height: 32.h),

              // Main container for all controls
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reminder Name
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: TextField(
                        cursorColor: _accentColor,
                        controller: _reminderController,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 24.sp,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What needs your attention?',
                          hintStyle: TextStyle(
                            color: subtitleColor.withOpacity(0.5),
                            fontSize: 24.sp,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),

                    Divider(color: dividerColor, height: 1.h),

                    // Date Selector
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: inputBgColor,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(_selectedDate),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.calendar_today,
                                    color: subtitleColor,
                                    size: 16.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: dividerColor, height: 1.h),

                    // Time Selector
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          InkWell(
                            onTap: _selectTime,
                            borderRadius: BorderRadius.circular(20.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 8.h, horizontal: 16.w),
                              decoration: BoxDecoration(
                                color: inputBgColor,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    () {
                                      final hour = _selectedTime.hourOfPeriod == 0
                                          ? 12
                                          : _selectedTime.hourOfPeriod;
                                      final minute = _selectedTime.minute
                                          .toString()
                                          .padLeft(2, '0');
                                      final period =
                                          _selectedTime.period == DayPeriod.am
                                              ? 'AM'
                                              : 'PM';
                                      return '$hour:$minute $period';
                                    }(),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.access_time,
                                    color: subtitleColor,
                                    size: 18.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: dividerColor, height: 1.h),

                    // Icon & Color - Combined in one row
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Icon & Color',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              // Icon Button
                              InkWell(
                                onTap: _openIconPicker,
                                borderRadius: BorderRadius.circular(20.r),
                                child: Container(
                                  padding: EdgeInsets.all(12.r),
                                  decoration: BoxDecoration(
                                    color: inputBgColor,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                  child: Icon(
                                    _selectedIcon,
                                    color: _selectedColor,
                                    size: 24.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Color Button
                              InkWell(
                                onTap: _openColorPicker,
                                borderRadius: BorderRadius.circular(20.r),
                                child: Container(
                                  width: 48.w,
                                  height: 48.h,
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    borderRadius: BorderRadius.circular(20.r),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Divider(color: dividerColor, height: 1.h),

                    // Repeat Switch
                    Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Repeat',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _repeatEnabled,
                            onChanged: (value) {
                              setState(() {
                                _repeatEnabled = value;
                              });
                            },
                            activeColor: _accentColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Recurrence Options Container (separate container when repeat is enabled)
              if (_repeatEnabled) ...[
                SizedBox(height: 20.h),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Frequency Selector
                      Padding(
                        padding: EdgeInsets.all(18.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FREQUENCY',
                              style: TextStyle(
                                color: subtitleColor.withOpacity(0.7),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                _buildFrequencyChip('Daily', RecurrenceFrequency.daily, cardColor, textColor, subtitleColor, inputBgColor),
                                SizedBox(width: 8.w),
                                _buildFrequencyChip('Weekly', RecurrenceFrequency.weekly, cardColor, textColor, subtitleColor, inputBgColor),
                                SizedBox(width: 8.w),
                                _buildFrequencyChip('Monthly', RecurrenceFrequency.monthly, cardColor, textColor, subtitleColor, inputBgColor),
                                SizedBox(width: 8.w),
                                _buildFrequencyChip('Yearly', RecurrenceFrequency.yearly, cardColor, textColor, subtitleColor, inputBgColor),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Days Selector (only for weekly)
                      if (_selectedFrequency == RecurrenceFrequency.weekly) ...[
                        Divider(color: dividerColor, height: 1.h),
                        Padding(
                          padding: EdgeInsets.all(16.r),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ON THESE DAYS',
                                style: TextStyle(
                                  color: subtitleColor.withOpacity(0.7),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(7, (index) {
                                  final dayIndex = index + 1;
                                  final isSelected = _selectedDays.contains(dayIndex);
                                  return _buildDayButton(
                                    _dayAbbreviations[index],
                                    dayIndex,
                                    isSelected,
                                    inputBgColor,
                                    textColor,
                                    subtitleColor,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // End Date Section
                      Divider(color: dividerColor, height: 1.h),
                      Padding(
                        padding: EdgeInsets.all(16.r),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'End Date',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                if (_endDateEnabled) ...[
                                  InkWell(
                                    onTap: _selectEndDate,
                                    borderRadius: BorderRadius.circular(20.r),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          vertical: 8.h, horizontal: 16.w),
                                      decoration: BoxDecoration(
                                        color: inputBgColor,
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _endDate != null
                                                ? DateFormat('MMM dd, yyyy')
                                                    .format(_endDate!)
                                                : 'Select Date',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14.sp,
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Icon(
                                            Icons.calendar_today,
                                            color: subtitleColor,
                                            size: 16.sp,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                ],
                                Switch(
                                  value: _endDateEnabled,
                                  onChanged: (value) {
                                    setState(() {
                                      _endDateEnabled = value;
                                      if (value && _endDate == null) {
                                        _endDate = _selectedDate
                                            .add(const Duration(days: 30));
                                      }
                                    });
                                  },
                                  activeColor: _accentColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Next 3 Occurrences (only shown when repeat is enabled)
              if (_repeatEnabled) ...[
                SizedBox(height: 32.h),
                Text(
                  'NEXT 3 OCCURRENCES',
                  style: TextStyle(
                    color: subtitleColor.withOpacity(0.7),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Column(
                    children: () {
                      final occurrences = _generateNextOccurrences();
                      if (occurrences.isEmpty) {
                        return [
                          Padding(
                            padding: EdgeInsets.all(16.r),
                            child: Text(
                              'No occurrences found',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ];
                      }
                      return occurrences.asMap().entries.map((entry) {
                        final index = entry.key;
                        final occurrence = entry.value;
                        final isLast = index == occurrences.length - 1;

                        return Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(16.r),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        occurrence['title']!,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        occurrence['subtitle']!,
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 6.h, horizontal: 12.w),
                                    decoration: BoxDecoration(
                                      color: inputBgColor,
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      occurrence['time']!,
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Divider(color: dividerColor, height: 1.h),
                          ],
                        );
                      }).toList();
                    }(),
                  ),
                ),
              ],

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChip(
    String label,
    RecurrenceFrequency frequency,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color inputBgColor,
  ) {
    final isSelected = _selectedFrequency == frequency;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFrequency = frequency;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : inputBgColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : subtitleColor,
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayButton(
    String label,
    int dayIndex,
    bool isSelected,
    Color inputBgColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return GestureDetector(
      onTap: () => _toggleDay(dayIndex),
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: isSelected ? _accentColor.withOpacity(0.3) : inputBgColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: _accentColor,
                  width: 2.w,
                )
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : subtitleColor,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
