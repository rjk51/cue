import 'package:cue/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/presentation/create_reminder_screen.dart';
import '../../reminders/presentation/reminder_list_screen.dart';
import '../../reminders/presentation/reminder_details_screen.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'widgets/current_cue_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ReminderService _reminderService = ReminderService();
  final ThemeService _themeService = ThemeService();

  Color _accentColor = const Color(0xFF2D7A78); // Default teal
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    // Listen for theme changes
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      // Reload from storage to ensure we have the latest values
      _loadThemeSettings();
    }
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

  void _navigateToCreateReminder() async {
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(builder: (context) => const NewReminderScreen()),
    );

    if (result != null && mounted) {
      context.showSuccessSnackbar('Reminder created successfully!');
    }
  }

  Future<void> _markAsCompleted(String reminderId) async {
    // Show snackbar immediately (optimistic UI)
    if (mounted) {
      context.showSuccessSnackbar('Marked as done!');
    }
    
    // Execute in background without blocking UI
    _reminderService.markAsCompleted(reminderId).catchError((e) {
      // Only show error if it fails
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    });
  }

  String _getTimeDisplayText(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);

    if (difference.isNegative) {
      // Past due
      if (difference.inMinutes.abs() < 1) {
        return 'now';
      } else if (difference.inMinutes.abs() < 60) {
        return '${difference.inMinutes.abs()} mins ago';
      } else if (difference.inHours.abs() < 24) {
        return '${difference.inHours.abs()} hrs ago';
      } else {
        return '${difference.inDays.abs()} days ago';
      }
    } else {
      // Future
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inMinutes < 60) {
        return 'in ${difference.inMinutes} mins';
      } else if (difference.inHours < 24) {
        return 'in ${difference.inHours} hrs';
      } else {
        return 'in ${difference.inDays} days';
      }
    }
  }

  bool _isCurrentCue(DateTime reminderTime) {
    final now = DateTime.now();
    final difference = reminderTime.difference(now);
    // Consider it current if within 30 minutes before or after
    return difference.inMinutes.abs() <= 30;
  }

  @override
  Widget build(BuildContext context) {
    // Background color with accent tint
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

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: StreamBuilder<List<Reminder>>(
              stream: _reminderService.getRemindersStream(),
              builder: (context, snapshot) {
                final reminders = snapshot.data ?? [];

                // Sort reminders by time
                final sortedReminders = List<Reminder>.from(reminders)
                  ..sort((a, b) => a.time.compareTo(b.time));

                // Filter for today's reminders
                final now = DateTime.now();
                final todayReminders = sortedReminders.where((r) {
                  return r.time.year == now.year &&
                      r.time.month == now.month &&
                      r.time.day == now.day &&
                      !r.isCompletedToday; // Uses helper method that checks both isCompleted and consistency
                }).toList();

                // Get current/next reminder (first uncompleted)
                final upcomingReminders = sortedReminders
                    .where(
                      (r) =>
                          !r.isCompletedToday && // Uses helper method that checks both isCompleted and consistency
                          r.time.isAfter(
                            now.subtract(const Duration(hours: 1)),
                          ),
                    )
                    .toList();

                final currentReminder = upcomingReminders.isNotEmpty
                    ? upcomingReminders.first
                    : null;

                // Upcoming reminders (after current)
                final upcomingAfterCurrent = upcomingReminders.length > 1
                    ? upcomingReminders.sublist(1)
                    : <Reminder>[];

                final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                final screenHeight = MediaQuery.of(context).size.height - 
                    MediaQuery.of(context).padding.top;
                
                return SingleChildScrollView(
                  physics: isKeyboardOpen 
                      ? const ClampingScrollPhysics() 
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    height: isKeyboardOpen ? null : screenHeight,
                    child: Column(
                      children: [
                        if (isKeyboardOpen) ...[
                              // Date header - keyboard open
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: Text(
                                  DateFormat('EEEE, MMM d').format(now).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: subtitleColor,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),

                              // Show full-screen empty state if no reminders at all
                              if (sortedReminders.isEmpty)
                                SizedBox(
                                  height: screenHeight - 100.h,
                                  child: _buildFullScreenEmptyState(
                                    textColor,
                                    subtitleColor,
                                  ),
                                )
                              else ...[
                                SizedBox(height: 32.h),

                                // Today's Reminders Count Section
                                _buildRemindersToday(
                                  todayReminders.length,
                                  textColor,
                                  subtitleColor,
                                  todayReminders,
                                ),

                                SizedBox(height: 40.h),

                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Current/Next Cue Card
                                      if (currentReminder != null)
                                        CurrentCueCard(
                                          reminder: currentReminder,
                                          accentColor: _accentColor,
                                          isDarkMode: _isDarkMode,
                                          cardColor: cardColor,
                                          textColor: textColor,
                                          subtitleColor: subtitleColor,
                                          onMarkCompleted: _markAsCompleted,
                                          getTimeDisplayText: _getTimeDisplayText,
                                          isCurrentCue: _isCurrentCue,
                                        )
                                      else
                                        _buildEmptyCueCard(
                                          cardColor,
                                          textColor,
                                          subtitleColor,
                                        ),

                                      SizedBox(height: 24.h),

                                      // Upcoming Section
                                      _buildUpcomingSection(
                                        upcomingAfterCurrent,
                                        cardColor,
                                        textColor,
                                        subtitleColor,
                                      ),

                                      // Add bottom padding to account for keyboard and FAB
                                      SizedBox(height: 150.h),
                                    ],
                                  ),
                                ),
                              ],
                        ] else ...[
                          // Date header - always shown
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            child: Text(
                              DateFormat('EEEE, MMM d').format(now).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: subtitleColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),

                          // Show full-screen empty state if no reminders at all
                          if (sortedReminders.isEmpty)
                            Expanded(
                              child: _buildFullScreenEmptyState(
                                textColor,
                                subtitleColor,
                              ),
                            )
                          else ...[
                            SizedBox(height: 32.h),

                            // Today's Reminders Count Section
                            _buildRemindersToday(
                              todayReminders.length,
                              textColor,
                              subtitleColor,
                              todayReminders,
                            ),

                            SizedBox(height: 40.h),

                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Current/Next Cue Card
                                    if (currentReminder != null)
                                      CurrentCueCard(
                                        reminder: currentReminder,
                                        accentColor: _accentColor,
                                        isDarkMode: _isDarkMode,
                                        cardColor: cardColor,
                                        textColor: textColor,
                                        subtitleColor: subtitleColor,
                                        onMarkCompleted: _markAsCompleted,
                                        getTimeDisplayText: _getTimeDisplayText,
                                        isCurrentCue: _isCurrentCue,
                                      )
                                    else
                                      _buildEmptyCueCard(
                                        cardColor,
                                        textColor,
                                        subtitleColor,
                                      ),

                                    SizedBox(height: 24.h),

                                    // Upcoming Section - flexible to avoid overflow
                                    Flexible(
                                      child: _buildUpcomingSection(
                                        upcomingAfterCurrent,
                                        cardColor,
                                        textColor,
                                        subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                        ],
                      ),
                    ),
                );
              },
            ),
          ),

          // Settings icon positioned at top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            right: 20.w,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  // Reload theme settings when coming back
                  if (mounted) {
                    await _loadThemeSettings();
                  }
                },
                customBorder: const CircleBorder(),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(
                    Icons.settings_outlined,
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : const Color(0xFF8A8A8A),
                    size: 24.sp,
                  ),
                ),
              ),
            ),
          ),

          // FAB positioned in Stack to avoid layout constraints
          Positioned(
            right: 34.w,
            bottom: MediaQuery.of(context).padding.bottom + 30.h,
            child: Container(
              width: 64.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: _accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToCreateReminder,
                  customBorder: const CircleBorder(),
                  child: Icon(Icons.add, color: Colors.white, size: 28.sp),
                ),
              ),
            ),
          ),
        ],
      ),
      // bottomNavigationBar: Padding(
      //   padding: EdgeInsets.only(left: 16.w, right: 16.w),
      //   child: BottomNavBar(
      //     accentColor: _accentColor,
      //     isDarkMode: _isDarkMode,
      //     currentIndex: _currentNavIndex,
      //     onTap: (index) async {
      //       // Update local index for UI
      //       setState(() {
      //         _currentNavIndex = index;
      //       });

      //       // Navigate to respective screens
      //       if (index == 0) {
      //         // Already on home; no-op
      //         return;
      //       } else if (index == 1) {
      //         // Calendar
      //         await Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (context) => const CalendarScreen()),
      //         );
      //       } else if (index == 2) {
      //         // Settings
      //         await Navigator.push(
      //           context,
      //           MaterialPageRoute(builder: (context) => const SettingsScreen()),
      //         );
      //       }
      //       // When coming back, reset nav index to home and reload theme settings
      //       if (mounted) {
      //         await _loadThemeSettings();
      //         setState(() {
      //           _currentNavIndex = 0;
      //         });
      //       }
      //     },
      //   ),
      // ),
    );
  }

  Widget _buildEmptyCueCard(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 64.h),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64.sp,
            color: _accentColor,
          ),
          SizedBox(height: 32.h),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'No upcoming reminders',
            style: TextStyle(fontSize: 16.sp, color: subtitleColor),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(
    List<Reminder> upcomingReminders,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UPCOMING',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
                letterSpacing: 1.5,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReminderListScreen(),
                  ),
                );
              },
              child: Text(
                'VIEW ALL',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: _accentColor,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 16.h),

        // Horizontal scrollable list
        SizedBox(
          height: 120.h,
          child: upcomingReminders.isEmpty
              ? Center(
                  child: Text(
                    'No more reminders scheduled',
                    style: TextStyle(fontSize: 14.sp, color: subtitleColor),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: upcomingReminders.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    final reminder = upcomingReminders[index];
                    return _buildUpcomingCard(
                      reminder,
                      cardColor,
                      textColor,
                      subtitleColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(
    Reminder reminder,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    final timeOnly = DateFormat('hh:mm').format(reminder.time);
    final amPm = DateFormat('a').format(reminder.time);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReminderDetailsScreen(
              reminder: reminder,
            ),
          ),
        );
      },
      child: Container(
        width: 180.w,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: reminder.color.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Title and Icon row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reminder name
              Expanded(
                child: Text(
                  reminder.name,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              // Icon on the right
              Container(
                width: 32.w,
                height: 32.h,
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
          
          // Time with AM/PM
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeOnly,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(width: 4.w),
              Padding(
                padding: EdgeInsets.only(bottom: 2.h),
                child: Text(
                  amPm,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildRemindersToday(
    int count,
    Color textColor,
    Color subtitleColor,
    List<Reminder> todayReminders,
  ) {
    // Sort by time and take only first 3
    final sortedReminders = List<Reminder>.from(todayReminders)
      ..sort((a, b) => a.time.compareTo(b.time));
    final displayReminders = sortedReminders.take(3).toList();

    return Center(
      child: Column(
        children: [
          Text(
            '$count reminder${count == 1 ? '' : 's'} today',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
            ),
          ),
          if (displayReminders.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < displayReminders.length; i++) ...[
                  if (i > 0) SizedBox(width: 24.w),
                  _buildCategoryIcon(
                    displayReminders[i].icon,
                    displayReminders[i].color,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon, Color color) {
    return Container(
      width: 44.w,
      height: 44.h,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 22.sp,
      ),
    );
  }

  Widget _buildFullScreenEmptyState(
    Color textColor,
    Color subtitleColor,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 48.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration_outlined,
              size: 120.sp,
              color: _accentColor.withOpacity(0.3),
            ),
            SizedBox(height: 48.h),
            Text(
              'No Reminders Yet',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            Text(
              'Tap the + button to create your first reminder',
              style: TextStyle(
                fontSize: 16.sp,
                color: subtitleColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 64.h),
            // Arrow pointing to FAB
            Icon(
              Icons.arrow_downward_rounded,
              size: 32.sp,
              color: _accentColor.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
