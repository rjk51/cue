import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/presentation/reminder_details_screen.dart';
import '../../../services/theme_service.dart';
import '../../../shared/widgets/cupertino_pickers.dart';

class ReminderListScreen extends StatefulWidget {
  const ReminderListScreen({super.key});

  @override
  State<ReminderListScreen> createState() => _ReminderListScreenState();
}

class _ReminderListScreenState extends State<ReminderListScreen> {
  final ReminderService _reminderService = ReminderService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Color _accentColor = const Color(0xFF2D7A78);
  bool _isDarkMode = false;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedDay = 'Today';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadThemeSettings() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();

    if (mounted) {
      setState(() {
        _accentColor = accentColor;
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

  void _selectDay(String day) {
    setState(() {
      _selectedDay = day;
      final now = DateTime.now();
      if (day == 'Today') {
        _selectedDate = now;
      } else if (day == 'Tomorrow') {
        _selectedDate = now.add(const Duration(days: 1));
      }
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _matchesSearchQuery(Reminder reminder) {
    if (_searchQuery.isEmpty) return true;

    // Search in reminder name/title
    if (reminder.name.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    // Search in notes
    if (reminder.notes != null &&
        reminder.notes!.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    return false;
  }

  bool _shouldShowRecurringReminderOnDate(
    Reminder reminder,
    DateTime selectedDate,
  ) {
    if (reminder.recurrence == null) return false;

    final selectedDateStr =
        '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

    // Check if the reminder was completed on this specific date
    // If so, it should be shown in the completed section
    // Check override completion (for hourly reminders)
    final override = reminder.getOverrideForDate(selectedDateStr);
    if (override != null && override['completedTimes'] != null) {
      final completedTimes = override['completedTimes'] as List<dynamic>?;
      if (completedTimes != null && completedTimes.isNotEmpty) {
        return true;
      }
    }

    if (reminder.consistency != null) {
      if (reminder.consistency!.wasCompletedOnDate(selectedDateStr)) {
        return true; // Always show if it was completed on this date
      }
    }

    // Check if nextDueAt is for this date or a recent missed date
    // This handles missed occurrences - show them until they're completed or skipped
    if (reminder.nextDueAt != null) {
      final nextDueDate = reminder.nextDueAt!;
      final nextDueDateStr =
          '${nextDueDate.year.toString().padLeft(4, '0')}-${nextDueDate.month.toString().padLeft(2, '0')}-${nextDueDate.day.toString().padLeft(2, '0')}';

      // If nextDueAt matches selected date and hasn't been completed/skipped, show it
      if (nextDueDateStr == selectedDateStr) {
        final isCompleted =
            reminder.consistency != null &&
            reminder.consistency!.wasCompletedOnDate(selectedDateStr);
        final isSkipped = reminder.isSkippedOnDate(selectedDateStr);

        if (!isCompleted && !isSkipped) {
          return true; // Show missed occurrence
        }
      }

      // Also show missed reminders: if nextDueAt is within last 24 hours and we're viewing today
      final now = DateTime.now();
      final todayStr =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      if (selectedDateStr == todayStr) {
        final hoursDiff = now.difference(nextDueDate).inHours;
        // Show if nextDueAt was within last 24 hours and hasn't been completed/skipped
        if (hoursDiff >= 0 && hoursDiff < 24) {
          final isCompleted =
              reminder.consistency != null &&
              reminder.consistency!.wasCompletedOnDate(nextDueDateStr);
          final isSkipped = reminder.isSkippedOnDate(nextDueDateStr);

          if (!isCompleted && !isSkipped) {
            return true; // Show missed reminder on today's list
          }
        }
      }
    }

    final recurrence = reminder.recurrence!;
    final type = recurrence['type'] as String?;

    // Don't show completed reminders on future dates
    if (reminder.isCompleted && selectedDate.isAfter(DateTime.now())) {
      return false;
    }

    // Get the start date (either nextDueAt or time)
    final startDate = reminder.nextDueAt ?? reminder.time;

    // Don't show if selected date is before the start date
    if (selectedDate.isBefore(
      DateTime(startDate.year, startDate.month, startDate.day),
    )) {
      return false;
    }

    // Check end date - don't show if selected date is after the end date
    if (recurrence['endDate'] != null) {
      final endDate = (recurrence['endDate'] as Timestamp).toDate();
      if (selectedDate.isAfter(
        DateTime(endDate.year, endDate.month, endDate.day),
      )) {
        return false;
      }
    }

    switch (type) {
      case 'interval':
        final unit = recurrence['unit'] as String?;
        final every = recurrence['every'] as int? ?? 1;

        if (unit == 'days') {
          // For daily reminders, check if the day difference is a multiple of 'every'
          final daysDiff = selectedDate
              .difference(
                DateTime(startDate.year, startDate.month, startDate.day),
              )
              .inDays;
          return daysDiff >= 0 && daysDiff % every == 0;
        } else if (unit == 'hours' || unit == 'minutes') {
          // For hourly/minute reminders, show on any day within the recurrence range
          return true;
        }
        return false;

      case 'weekly':
        final days = recurrence['days'] as List<dynamic>?;
        if (days == null || days.isEmpty) return false;

        // Map day names to weekday numbers (1 = Monday, 7 = Sunday)
        final dayMap = {
          'mon': 1,
          'tue': 2,
          'wed': 3,
          'thu': 4,
          'fri': 5,
          'sat': 6,
          'sun': 7,
        };

        final selectedWeekday = selectedDate.weekday;
        return days.any(
          (day) => dayMap[day.toString().toLowerCase()] == selectedWeekday,
        );

      case 'monthly':
        // Show on the same day of each month
        return selectedDate.day == startDate.day;

      case 'yearly':
        // Show on the same day and month each year
        return selectedDate.day == startDate.day &&
            selectedDate.month == startDate.month;

      default:
        return false;
    }
  }

  List<DateTime> _getHourlyOccurrencesForDay(Reminder reminder, DateTime date) {
    final recurrence = reminder.recurrence;
    if (recurrence == null) return [];

    final type = recurrence['type'] as String?;
    final unit = recurrence['unit'] as String?;
    final every = recurrence['every'] as int? ?? 1;

    if (type != 'interval' || (unit != 'hours' && unit != 'minutes')) {
      return [];
    }

    final occurrences = <DateTime>[];
    final totalMinutes = unit == 'hours' ? every * 60 : every;

    if (totalMinutes == 0) return occurrences;

    // Start of the requested day
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // Get the start time from recurrence
    final startDateValue = recurrence['startDate'];
    if (startDateValue == null) return occurrences;

    final startDate = (startDateValue as Timestamp).toDate();
    final timeStr = recurrence['time'] as String?;

    DateTime startTime;
    if (timeStr != null) {
      final timeParts = timeStr.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      startTime = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        hour,
        minute,
      );
    } else {
      startTime = startDate;
    }

    // If end date exists and the requested day is after it, return empty
    final endDateValue = recurrence['endDate'];
    if (endDateValue != null) {
      final endDate = (endDateValue as Timestamp).toDate();
      if (date.isAfter(endDate)) {
        return occurrences;
      }
    }

    // If requested day is before start date, return empty
    if (date.isBefore(
      DateTime(startTime.year, startTime.month, startTime.day),
    )) {
      return occurrences;
    }

    // Calculate first occurrence of the day
    DateTime current;

    if (date.year == startTime.year &&
        date.month == startTime.month &&
        date.day == startTime.day) {
      // On the start day, first occurrence is at start time
      current = startTime;
    } else {
      // On subsequent days, calculate how many intervals have passed since start
      final minutesSinceStart = dayStart.difference(startTime).inMinutes;
      final intervalsPassed = (minutesSinceStart / totalMinutes).floor();
      current = startTime.add(
        Duration(minutes: totalMinutes * intervalsPassed),
      );

      // Move to first occurrence on this day
      while (current.isBefore(dayStart)) {
        current = current.add(Duration(minutes: totalMinutes));
      }
    }

    // Collect all occurrences within the day
    while (current.isBefore(dayEnd) || current.isAtSameMomentAs(dayEnd)) {
      occurrences.add(current);
      current = current.add(Duration(minutes: totalMinutes));
    }

    return occurrences;
  }

  @override
  Widget build(BuildContext context) {
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

    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final isPast = _selectedDate.isBefore(now) && !isToday;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color: textColor,
                          size: 24.sp,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        'All Reminders',
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  // Row(
                  //   children: [
                  //     IconButton(
                  //       onPressed: () {
                  //         setState(() {
                  //           _isSearching = !_isSearching;
                  //           if (!_isSearching) {
                  //             _searchController.clear();
                  //             _searchFocusNode.unfocus();
                  //           } else {
                  //             _searchFocusNode.requestFocus();
                  //           }
                  //         });
                  //       },
                  //       icon: Icon(
                  //         _isSearching ? Icons.close : Icons.search,
                  //         color: subtitleColor,
                  //         size: 24.sp,
                  //       ),
                  //       padding: EdgeInsets.zero,
                  //       constraints: const BoxConstraints(),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),

            // Search bar
            if (_isSearching) ...[
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: TextStyle(fontSize: 16.sp, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Search reminders...',
                      hintStyle: TextStyle(
                        fontSize: 16.sp,
                        color: subtitleColor,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: subtitleColor,
                        size: 20.sp,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: subtitleColor,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Search results count
            // if (_isSearching && _searchQuery.isNotEmpty) ...[
            //   SizedBox(height: 12.h),
            //   Padding(
            //     padding: EdgeInsets.symmetric(horizontal: 24.w),
            //     child: StreamBuilder<List<Reminder>>(
            //       stream: _reminderService.getRemindersStream(),
            //       builder: (context, activeSnapshot) {
            //         return StreamBuilder<List<Reminder>>(
            //           stream: _reminderService.getCompletedRemindersStream(),
            //           builder: (context, completedSnapshot) {
            //             final allReminders = <Reminder>[
            //               ...(activeSnapshot.data ?? []),
            //               ...(completedSnapshot.data ?? []),
            //             ];
            //             final matchingCount = allReminders.where(_matchesSearchQuery).length;

            //             return Text(
            //               '$matchingCount ${matchingCount == 1 ? 'reminder' : 'reminders'} found',
            //               style: TextStyle(
            //                 fontSize: 12.sp,
            //                 color: subtitleColor,
            //               ),
            //             );
            //           },
            //         );
            //       },
            //     ),
            //   ),
            // ],

            // Day selector tabs
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              child: Row(
                children: [
                  _buildDayTab('Today', textColor, subtitleColor),
                  SizedBox(width: 8.w),
                  _buildDayTab('Tomorrow', textColor, subtitleColor),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showCupertinoDatePickerModal(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                          _selectedDay = '';
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedDay.isEmpty
                            ? _accentColor
                            : (_isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05)),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        size: 16.sp,
                        color: _selectedDay.isEmpty
                            ? Colors.white
                            : subtitleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 8.h),

            // Reminder list
            Expanded(
              child: StreamBuilder<List<Reminder>>(
                stream: _reminderService.getRemindersStream(),
                builder: (context, activeSnapshot) {
                  return StreamBuilder<List<Reminder>>(
                    stream: _reminderService.getCompletedRemindersStream(),
                    builder: (context, completedSnapshot) {
                      if (!activeSnapshot.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: _accentColor),
                        );
                      }

                      final activeReminders = activeSnapshot.data ?? [];
                      final completedReminders = completedSnapshot.data ?? [];

                      // Combine and filter for selected date
                      final allReminders = [
                        ...activeReminders,
                        ...completedReminders,
                      ];

                      // Expand hourly reminders into multiple occurrences
                      final expandedReminders = <Map<String, dynamic>>[];

                      for (final reminder in allReminders) {
                        // For recurring reminders, check if they would occur on this date
                        if (reminder.recurrence != null) {
                          final shouldShow = _shouldShowRecurringReminderOnDate(
                            reminder,
                            _selectedDate,
                          );
                          if (!shouldShow) continue;

                          // Check if it's an hourly reminder
                          final recurrence = reminder.recurrence!;
                          final type = recurrence['type'] as String?;
                          final unit = recurrence['unit'] as String?;

                          if (type == 'interval' &&
                              (unit == 'hours' || unit == 'minutes')) {
                            // Expand hourly reminder into multiple occurrences
                            final occurrences = _getHourlyOccurrencesForDay(
                              reminder,
                              _selectedDate,
                            );
                            for (final occurrence in occurrences) {
                              // Add all occurrences, filtering happens later
                              expandedReminders.add({
                                'reminder': reminder,
                                'occurrenceTime': occurrence,
                              });
                            }
                          } else {
                            // Single occurrence for non-hourly recurring reminders
                            expandedReminders.add({
                              'reminder': reminder,
                              'occurrenceTime': null,
                            });
                          }
                        } else {
                          // For non-recurring reminders, just check the time
                          if (_isSameDay(reminder.time, _selectedDate)) {
                            expandedReminders.add({
                              'reminder': reminder,
                              'occurrenceTime': null,
                            });
                          }
                        }
                      }

                      // For recurring reminders, check if they were completed on the selected date
                      final selectedDateStr =
                          '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

                      final upcomingReminders =
                          expandedReminders
                              .where((item) {
                                final r = item['reminder'] as Reminder;
                                if (r.isCompleted)
                                  return false; // Non-recurring completed reminders

                                // For hourly reminders, check specific occurrence
                                final occurrenceTime =
                                    item['occurrenceTime'] as DateTime?;
                                if (occurrenceTime != null) {
                                  return !r.isOccurrenceCompleted(
                                    occurrenceTime,
                                  );
                                }

                                // For recurring reminders, check if this specific date was completed
                                if (r.recurrence != null &&
                                    r.consistency != null) {
                                  return !r.consistency!.wasCompletedOnDate(
                                    selectedDateStr,
                                  );
                                }

                                return !r.isCompleted;
                              })
                              .where(
                                (item) => _matchesSearchQuery(
                                  item['reminder'] as Reminder,
                                ),
                              ) // Apply search filter
                              .toList()
                            ..sort((a, b) {
                              // Sort by occurrence time if available, otherwise by nextDueAt/time
                              final aReminder = a['reminder'] as Reminder;
                              final bReminder = b['reminder'] as Reminder;
                              final aOccurrence =
                                  a['occurrenceTime'] as DateTime?;
                              final bOccurrence =
                                  b['occurrenceTime'] as DateTime?;

                              final aTime =
                                  aOccurrence ??
                                  ((aReminder.recurrence != null &&
                                          aReminder.nextDueAt != null)
                                      ? aReminder.nextDueAt!
                                      : aReminder.time);
                              final bTime =
                                  bOccurrence ??
                                  ((bReminder.recurrence != null &&
                                          bReminder.nextDueAt != null)
                                      ? bReminder.nextDueAt!
                                      : bReminder.time);
                              return aTime.compareTo(bTime);
                            });

                      final pastDueReminders = isToday
                          ? upcomingReminders.where((item) {
                              final r = item['reminder'] as Reminder;
                              final occurrenceTime =
                                  item['occurrenceTime'] as DateTime?;
                              final itemTime =
                                  occurrenceTime ??
                                  ((r.recurrence != null && r.nextDueAt != null)
                                      ? r.nextDueAt!
                                      : r.time);
                              return itemTime.isBefore(now);
                            }).toList()
                          : <Map<String, dynamic>>[];

                      final upcomingFutureReminders = isToday
                          ? upcomingReminders.where((item) {
                              final r = item['reminder'] as Reminder;
                              final occurrenceTime =
                                  item['occurrenceTime'] as DateTime?;
                              final itemTime =
                                  occurrenceTime ??
                                  ((r.recurrence != null && r.nextDueAt != null)
                                      ? r.nextDueAt!
                                      : r.time);
                              return !itemTime.isBefore(now);
                            }).toList()
                          : upcomingReminders;

                      final completedDayReminders =
                          expandedReminders
                              .where((item) {
                                final r = item['reminder'] as Reminder;
                                // Non-recurring completed reminders
                                if (r.recurrence == null) {
                                  return r.isCompleted;
                                }

                                // For hourly reminders, check specific occurrence
                                final occurrenceTime =
                                    item['occurrenceTime'] as DateTime?;
                                if (occurrenceTime != null) {
                                  return r.isOccurrenceCompleted(
                                    occurrenceTime,
                                  );
                                }

                                // For recurring reminders, check if this specific date was completed
                                if (r.consistency != null) {
                                  return r.consistency!.wasCompletedOnDate(
                                    selectedDateStr,
                                  );
                                }

                                return false;
                              })
                              .where(
                                (item) => _matchesSearchQuery(
                                  item['reminder'] as Reminder,
                                ),
                              ) // Apply search filter
                              .toList()
                            ..sort((a, b) {
                              // Sort by occurrence time if available, otherwise by nextDueAt/time
                              final aReminder = a['reminder'] as Reminder;
                              final bReminder = b['reminder'] as Reminder;
                              final aOccurrence =
                                  a['occurrenceTime'] as DateTime?;
                              final bOccurrence =
                                  b['occurrenceTime'] as DateTime?;

                              final aTime =
                                  aOccurrence ??
                                  ((aReminder.recurrence != null &&
                                          aReminder.nextDueAt != null)
                                      ? aReminder.nextDueAt!
                                      : aReminder.time);
                              final bTime =
                                  bOccurrence ??
                                  ((bReminder.recurrence != null &&
                                          bReminder.nextDueAt != null)
                                      ? bReminder.nextDueAt!
                                      : bReminder.time);
                              return bTime.compareTo(aTime);
                            });

                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Past Section (for today)
                            if (isToday && pastDueReminders.isNotEmpty) ...[
                              _buildSectionHeader('PAST', subtitleColor),
                              SizedBox(height: 12.h),
                              ...pastDueReminders.map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildReminderCard(
                                    item['reminder'] as Reminder,
                                    cardColor,
                                    textColor,
                                    subtitleColor,
                                    false,
                                    isPaused: true,
                                    occurrenceTime:
                                        item['occurrenceTime'] as DateTime?,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.h),
                            ],

                            // Upcoming Section (for today and future)
                            if (upcomingFutureReminders.isNotEmpty &&
                                !isPast) ...[
                              _buildSectionHeader('UPCOMING', subtitleColor),
                              SizedBox(height: 12.h),
                              ...upcomingFutureReminders.map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildReminderCard(
                                    item['reminder'] as Reminder,
                                    cardColor,
                                    textColor,
                                    subtitleColor,
                                    false,
                                    occurrenceTime:
                                        item['occurrenceTime'] as DateTime?,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.h),
                            ],

                            // Paused/Missed Section (for past days - uncompleted)
                            if (isPast && upcomingReminders.isNotEmpty) ...[
                              _buildSectionHeader('MISSED', subtitleColor),
                              SizedBox(height: 12.h),
                              ...upcomingReminders.map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildReminderCard(
                                    item['reminder'] as Reminder,
                                    cardColor,
                                    textColor,
                                    subtitleColor,
                                    false,
                                    isPaused: true,
                                    occurrenceTime:
                                        item['occurrenceTime'] as DateTime?,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.h),
                            ],

                            // Completed Section (for today and past days)
                            if ((isToday || isPast) &&
                                completedDayReminders.isNotEmpty) ...[
                              _buildSectionHeader(
                                isToday ? 'COMPLETED TODAY' : 'COMPLETED',
                                subtitleColor,
                              ),
                              SizedBox(height: 12.h),
                              ...completedDayReminders.map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 12.h),
                                  child: _buildReminderCard(
                                    item['reminder'] as Reminder,
                                    cardColor,
                                    textColor,
                                    subtitleColor,
                                    true,
                                    occurrenceTime:
                                        item['occurrenceTime'] as DateTime?,
                                  ),
                                ),
                              ),
                              SizedBox(height: 24.h),
                            ],

                            // Empty state
                            if (upcomingReminders.isEmpty &&
                                completedDayReminders.isEmpty)
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 100.h),
                                  child: Column(
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty
                                            ? Icons.search_off
                                            : Icons.event_available_outlined,
                                        size: 64.sp,
                                        color: subtitleColor.withOpacity(0.5),
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No reminders match "$_searchQuery"'
                                            : 'No reminders scheduled',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: subtitleColor,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_searchQuery.isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        TextButton(
                                          onPressed: () {
                                            _searchController.clear();
                                          },
                                          child: Text(
                                            'Clear search',
                                            style: TextStyle(
                                              fontSize: 14.sp,
                                              color: _accentColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                            SizedBox(height: 50.h),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTab(String label, Color textColor, Color subtitleColor) {
    final isSelected = _selectedDay == label;
    return GestureDetector(
      onTap: () => _selectDay(label),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentColor
              : (_isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color subtitleColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: subtitleColor.withOpacity(0.8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildReminderCard(
    Reminder reminder,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    bool isCompleted, {
    bool isPaused = false,
    DateTime? occurrenceTime,
  }) {
    // Use occurrence time if provided (for hourly reminders), otherwise use scheduled time
    final displayTime = occurrenceTime ?? reminder.scheduledDisplayTime;

    final dateKey = DateFormat('yyyy-MM-dd').format(displayTime);
    if (reminder.recurrence != null && reminder.isSkippedOnDate(dateKey)) {
      return const SizedBox.shrink();
    }
    final displayTitle = reminder.recurrence != null
        ? reminder.getEffectiveDisplayName()
        : reminder.name;

    final timeOnly = DateFormat('hh:mm a').format(displayTime);
    final dateText = DateFormat('MMM d').format(displayTime);
    final hasRecurrence = reminder.recurrence != null;

    final snoozedUntil = reminder.snoozedUntil;
    final isSnoozed = snoozedUntil != null;
    final snoozedUntilFormatted = snoozedUntil != null
        ? DateFormat('hh:mm a').format(snoozedUntil)
        : null;

    return GestureDetector(
      onTap: () {
        // For completed or paused, navigate to details
        // For active reminders, optionally handle quick complete here
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReminderDetailsScreen(reminder: reminder),
          ),
        );
      },
      onLongPress: !isCompleted && !isPaused
          ? () async {
              // Quick complete on long press for non-completed reminders
              final service = ReminderService();
              try {
                await service.markAsCompleted(
                  reminder.id,
                  occurrenceTime: occurrenceTime,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as done!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            }
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: isCompleted
              ? null
              : Border.all(color: reminder.color.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left indicator or checkbox
            if (isCompleted)
              Icon(
                Icons.check_circle,
                color: _accentColor.withOpacity(0.6),
                size: 20.sp,
              )
            else if (isPaused)
              Icon(
                Icons.cancel_outlined,
                color: subtitleColor.withOpacity(0.6),
                size: 20.sp,
              )
            else
              Container(
                width: 8.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: reminder.color,
                  shape: BoxShape.circle,
                ),
              ),
            SizedBox(width: 16.w),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? subtitleColor.withOpacity(0.7)
                          : textColor,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isSameDay(_selectedDate, DateTime.now())
                              ? timeOnly
                              : '$dateText · $timeOnly',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Snooze: "Rings at [time]" in the time row
                      if (isSnoozed && snoozedUntilFormatted != null) ...[
                        SizedBox(width: 8.w),
                        Text(
                          '·',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: subtitleColor,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.snooze_rounded,
                          size: 12.sp,
                          color: _accentColor,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Snoozed until $snoozedUntilFormatted',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: _accentColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Show frequency for recurring reminders
                      if (hasRecurrence) ...[
                        SizedBox(width: 8.w),
                        Text(
                          '·',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: subtitleColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            _getRecurrenceFrequencyText(reminder),
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: 12.w),

            // Right side - consistency meter for recurring or icon
            if (hasRecurrence && !isCompleted)
              _buildConsistencyMeter(reminder, textColor)
            else if (!isCompleted)
              Container(
                width: 36.w,
                height: 36.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reminder.color.withOpacity(0.15),
                ),
                child: reminder.customIconUrl != null
                    ? ClipOval(
                        child: Image.network(
                          reminder.customIconUrl!,
                          width: 36.w,
                          height: 36.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              reminder.icon,
                              color: reminder.color,
                              size: 20.sp,
                            );
                          },
                        ),
                      )
                    : Icon(reminder.icon, color: reminder.color, size: 20.sp),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyMeter(Reminder reminder, Color textColor) {
    final consistency = reminder.consistencyPercentage.clamp(0.0, 100.0);

    // Use orange color from image
    const meterColor = Color(0xFFFF8A3D);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Text on the left
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${consistency.toInt()}%',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'CONSISTENCY',
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: meterColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(width: 8.w),
        // Circle on the right
        SizedBox(
          width: 32.w,
          height: 32.h,
          child: CircularProgressIndicator(
            value: consistency / 100,
            strokeWidth: 2,
            backgroundColor: _isDarkMode
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFE8E8E8),
            valueColor: const AlwaysStoppedAnimation<Color>(meterColor),
            strokeCap: StrokeCap.round,
          ),
        ),
      ],
    );
  }

  String _getRecurrenceFrequencyText(Reminder reminder) {
    if (reminder.recurrence == null) return '';

    final recurrence = reminder.recurrence!;
    final type = recurrence['type'] as String?;

    if (type == null) return '';

    switch (type) {
      case 'interval':
        final unit = recurrence['unit'] as String?;
        final every = recurrence['every'] as int? ?? 1;

        if (unit == 'days' && every == 1) {
          return 'Daily';
        } else if (unit == 'days') {
          return 'Every $every days';
        } else if (unit == 'hours' && every == 1) {
          return 'Hourly';
        } else if (unit == 'hours') {
          return 'Every $every hours';
        } else if (unit == 'minutes') {
          return 'Every $every min';
        }
        return 'Recurring';

      case 'weekly':
        final days = recurrence['days'] as List<dynamic>?;
        if (days == null || days.isEmpty) return 'Weekly';

        final dayNames = {
          'mon': 'Mon',
          'tue': 'Tue',
          'wed': 'Wed',
          'thu': 'Thu',
          'fri': 'Fri',
          'sat': 'Sat',
          'sun': 'Sun',
        };

        final formattedDays = days
            .map((d) => dayNames[d.toString().toLowerCase()] ?? '')
            .where((d) => d.isNotEmpty)
            .join(', ');

        return formattedDays.isNotEmpty ? formattedDays : 'Weekly';

      case 'monthly':
        return 'Monthly';

      case 'yearly':
        return 'Yearly';

      default:
        return 'Recurring';
    }
  }
}
