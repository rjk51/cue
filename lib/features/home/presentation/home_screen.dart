import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/presentation/create_reminder_screen.dart';
import '../../../services/theme_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'widgets/current_cue_card.dart';
import 'widgets/bottom_nav_bar.dart';

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
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
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
      MaterialPageRoute(builder: (context) => const CreateReminderScreen()),
    );

    if (result != null && mounted) {
      context.showSuccessSnackbar('Reminder created successfully!');
    }
  }

  Future<void> _markAsCompleted(String reminderId) async {
    try {
      await _reminderService.markAsCompleted(reminderId);
      if (mounted) {
        context.showSuccessSnackbar('Marked as done!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    }
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
      body: SafeArea(
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
                  !r.isCompleted;
            }).toList();

            // Get current/next reminder (first uncompleted)
            final upcomingReminders = sortedReminders
                .where(
                  (r) =>
                      !r.isCompleted &&
                      r.time.isAfter(now.subtract(const Duration(hours: 1))),
                )
                .toList();

            final currentReminder = upcomingReminders.isNotEmpty
                ? upcomingReminders.first
                : null;

            // Upcoming reminders (after current)
            final upcomingAfterCurrent = upcomingReminders.length > 1
                ? upcomingReminders.sublist(1)
                : <Reminder>[];

            return Column(
              children: [
                // Date header
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
                SizedBox(height: 32.h),

                // Today's Reminders Count Section (moved here)
                _buildRemindersToday(
                  todayReminders.length,
                  textColor,
                  subtitleColor,
                ),

                SizedBox(height: 40.h),

                Expanded(
                  child: SingleChildScrollView(
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

                        SizedBox(height: 32.h),

                        // Upcoming Section
                        _buildUpcomingSection(
                          upcomingAfterCurrent,
                          cardColor,
                          textColor,
                          subtitleColor,
                        ),

                        SizedBox(height: 100.h), // Space for FAB
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(right: 18.w),
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
          child: FloatingActionButton(
            onPressed: _navigateToCreateReminder,
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Icon(Icons.add, color: Colors.white, size: 28.sp),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w),
        child: BottomNavBar(
          accentColor: _accentColor,
          isDarkMode: _isDarkMode,
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
            // TODO: Navigate to different screens based on index
            // 0 = home, 1 = calendar, 2 = settings
          },
        ),
      ),
    );
  }

  Widget _buildEmptyCueCard(
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(32.r),
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
            size: 48.sp,
            color: _accentColor,
          ),
          SizedBox(height: 16.h),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'No upcoming reminders',
            style: TextStyle(fontSize: 14.sp, color: subtitleColor),
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
                // TODO: Navigate to full list view
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
          height: 100.h,
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
    final formattedTime = DateFormat('HH:mm').format(reminder.time);

    return Container(
      width: 140.w,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  reminder.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersToday(int count, Color textColor, Color subtitleColor) {
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
          SizedBox(height: 16.h),
          // Hardcoded icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCategoryIcon(Icons.medication_outlined),
              SizedBox(width: 24.w),
              _buildCategoryIcon(Icons.local_florist_outlined),
              SizedBox(width: 24.w),
              _buildCategoryIcon(Icons.directions_bus_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(IconData icon) {
    return Container(
      width: 44.w,
      height: 44.h,
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.1)
            : _accentColor.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: _isDarkMode
            ? Colors.white.withOpacity(0.7)
            : _accentColor.withOpacity(0.7),
        size: 22.sp,
      ),
    );
  }
}
