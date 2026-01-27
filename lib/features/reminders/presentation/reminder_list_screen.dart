import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/data/reminder_service.dart';
import '../../../services/theme_service.dart';

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
      if (day == 'Yesterday') {
        _selectedDate = now.subtract(const Duration(days: 1));
      } else if (day == 'Today') {
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

  bool _shouldShowRecurringReminderOnDate(Reminder reminder, DateTime selectedDate) {
    if (reminder.recurrence == null) return false;
    
    // Check if the reminder was completed on this specific date
    // If so, it should be shown in the completed section
    if (reminder.consistency != null) {
      final selectedDateStr = '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      if (reminder.consistency!.wasCompletedOnDate(selectedDateStr)) {
        return true; // Always show if it was completed on this date
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
    if (selectedDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      return false;
    }
    
    // Check end date - don't show if selected date is after the end date
    if (recurrence['endDate'] != null) {
      final endDate = (recurrence['endDate'] as Timestamp).toDate();
      if (selectedDate.isAfter(DateTime(endDate.year, endDate.month, endDate.day))) {
        return false;
      }
    }
    
    switch (type) {
      case 'interval':
        final unit = recurrence['unit'] as String?;
        final every = recurrence['every'] as int? ?? 1;
        
        if (unit == 'days') {
          // For daily reminders, check if the day difference is a multiple of 'every'
          final daysDiff = selectedDate.difference(DateTime(startDate.year, startDate.month, startDate.day)).inDays;
          return daysDiff >= 0 && daysDiff % every == 0;
        } else if (unit == 'hours' || unit == 'minutes') {
          // For hourly/minute reminders, only show on the current day
          return _isSameDay(startDate, selectedDate);
        }
        return false;
        
      case 'weekly':
        final days = recurrence['days'] as List<dynamic>?;
        if (days == null || days.isEmpty) return false;
        
        // Map day names to weekday numbers (1 = Monday, 7 = Sunday)
        final dayMap = {
          'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4,
          'fri': 5, 'sat': 6, 'sun': 7,
        };
        
        final selectedWeekday = selectedDate.weekday;
        return days.any((day) => dayMap[day.toString().toLowerCase()] == selectedWeekday);
        
      case 'monthly':
        // Show on the same day of each month
        return selectedDate.day == startDate.day;
        
      case 'yearly':
        // Show on the same day and month each year
        return selectedDate.day == startDate.day && selectedDate.month == startDate.month;
        
      default:
        return false;
    }
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSearching = !_isSearching;
                            if (!_isSearching) {
                              _searchController.clear();
                              _searchFocusNode.unfocus();
                            } else {
                              _searchFocusNode.requestFocus();
                            }
                          });
                        },
                        icon: Icon(
                          _isSearching ? Icons.close : Icons.search,
                          color: subtitleColor,
                          size: 24.sp,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
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
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: textColor,
                    ),
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
                  _buildDayTab('Yesterday', textColor, subtitleColor),
                  SizedBox(width: 8.w),
                  _buildDayTab('Today', textColor, subtitleColor),
                  SizedBox(width: 8.w),
                  _buildDayTab('Tomorrow', textColor, subtitleColor),
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(
                                primary: _accentColor,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                          _selectedDay = '';
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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
                      final allReminders = [...activeReminders, ...completedReminders];
                      
                      final dayReminders = allReminders.where((r) {
                        // For recurring reminders, check if they would occur on this date
                        if (r.recurrence != null) {
                          return _shouldShowRecurringReminderOnDate(r, _selectedDate);
                        }
                        // For non-recurring reminders, just check the time
                        return _isSameDay(r.time, _selectedDate);
                      }).toList();
                      
                      // For recurring reminders, check if they were completed on the selected date
                      final selectedDateStr = '${_selectedDate.year.toString().padLeft(4, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
                      
                      final upcomingReminders = dayReminders
                          .where((r) {
                            if (r.isCompleted) return false; // Non-recurring completed reminders
                            
                            // For recurring reminders, check if this specific date was completed
                            if (r.recurrence != null && r.consistency != null) {
                              return !r.consistency!.wasCompletedOnDate(selectedDateStr);
                            }
                            
                            return !r.isCompleted;
                          })
                          .where(_matchesSearchQuery) // Apply search filter
                          .toList()
                        ..sort((a, b) {
                          // Sort by nextDueAt for recurring reminders, time otherwise
                          final aTime = (a.recurrence != null && a.nextDueAt != null) 
                              ? a.nextDueAt! 
                              : a.time;
                          final bTime = (b.recurrence != null && b.nextDueAt != null) 
                              ? b.nextDueAt! 
                              : b.time;
                          return aTime.compareTo(bTime);
                        });
                      
                      final completedDayReminders = dayReminders
                          .where((r) {
                            // Non-recurring completed reminders
                            if (r.recurrence == null) {
                              return r.isCompleted;
                            }
                            
                            // For recurring reminders, check if this specific date was completed
                            if (r.consistency != null) {
                              return r.consistency!.wasCompletedOnDate(selectedDateStr);
                            }
                            
                            return false;
                          })
                          .where(_matchesSearchQuery) // Apply search filter
                          .toList()
                        ..sort((a, b) {
                          // Sort by nextDueAt for recurring reminders, time otherwise
                          final aTime = (a.recurrence != null && a.nextDueAt != null) 
                              ? a.nextDueAt! 
                              : a.time;
                          final bTime = (b.recurrence != null && b.nextDueAt != null) 
                              ? b.nextDueAt! 
                              : b.time;
                          return bTime.compareTo(aTime);
                        });

                      return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Upcoming Section (for today and future)
                        if (upcomingReminders.isNotEmpty && !isPast) ...[
                          _buildSectionHeader('UPCOMING', subtitleColor),
                          SizedBox(height: 12.h),
                          ...upcomingReminders.map((reminder) => Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: _buildReminderCard(
                                  reminder,
                                  cardColor,
                                  textColor,
                                  subtitleColor,
                                  false,
                                ),
                              )),
                          SizedBox(height: 24.h),
                        ],

                        // Paused/Missed Section (for past days - uncompleted)
                        if (isPast && upcomingReminders.isNotEmpty) ...[
                          _buildSectionHeader('MISSED', subtitleColor),
                          SizedBox(height: 12.h),
                          ...upcomingReminders.map((reminder) => Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: _buildReminderCard(
                                  reminder,
                                  cardColor,
                                  textColor,
                                  subtitleColor,
                                  false,
                                  isPaused: true,
                                ),
                              )),
                          SizedBox(height: 24.h),
                        ],

                        // Completed Section (for today and past days)
                        if ((isToday || isPast) && completedDayReminders.isNotEmpty) ...[
                          _buildSectionHeader(
                            isToday ? 'COMPLETED TODAY' : 'COMPLETED',
                            subtitleColor,
                          ),
                          SizedBox(height: 12.h),
                          ...completedDayReminders.map((reminder) => Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: _buildReminderCard(
                                  reminder,
                                  cardColor,
                                  textColor,
                                  subtitleColor,
                                  true,
                                ),
                              )),
                          SizedBox(height: 24.h),
                        ],

                        // Empty state
                        if (upcomingReminders.isEmpty && completedDayReminders.isEmpty)
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
  }) {
    // Use nextDueAt for recurring reminders, otherwise use time
    final displayTime = (reminder.recurrence != null && reminder.nextDueAt != null)
        ? reminder.nextDueAt!
        : reminder.time;
    
    final timeOnly = DateFormat('hh:mm a').format(displayTime);
    final dateText = DateFormat('MMM d').format(displayTime);
    final hasRecurrence = reminder.recurrence != null;

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to reminder details/edit screen
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: isCompleted
              ? null
              : Border.all(
                  color: reminder.color.withOpacity(0.15),
                  width: 1,
                ),
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
                    reminder.name,
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
                      Text(
                        _isSameDay(_selectedDate, DateTime.now())
                            ? timeOnly
                            : '$dateText · $timeOnly',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: subtitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                child: Icon(
                  reminder.icon,
                  color: reminder.color,
                  size: 20.sp,
                ),
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
