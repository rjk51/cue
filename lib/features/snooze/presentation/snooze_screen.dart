import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../shared/widgets/cupertino_pickers.dart';
import '../../reminders/data/reminder_service.dart';

class SnoozeScreen extends StatefulWidget {
  final String reminderId;
  final String reminderTitle;

  const SnoozeScreen({
    super.key,
    required this.reminderId,
    required this.reminderTitle,
  });

  @override
  State<SnoozeScreen> createState() => _SnoozeScreenState();
}

class _SnoozeScreenState extends State<SnoozeScreen> {
  final ThemeService _themeService = ThemeService();
  final ReminderService _reminderService = ReminderService();
  int _snoozeMinutes = 15;
  String? _selectedPreset;
  double _currentAngle =
      0.25 * 2 * 3.14159; // Start at 15 minutes (25% of circle)
  Color _accentColor = const Color(0xFFFFB4A3);
  bool _isDarkMode = false;
  bool _isLoading = false;

  // State for custom times
  DateTime? _laterTodayTime;
  DateTime? _tomorrowTime;
  DateTime? _otherDayDateTime;

  @override
  void initState() {
    super.initState();
    _loadAccentColor();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
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

  Future<void> _loadAccentColor() async {
    final color = await _themeService.getAccentColor();
    final themePreference = await _themeService.getThemePreference();
    if (mounted) {
      setState(() {
        _accentColor = color;
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

  void _updateSnoozeFromAngle(double angle) {
    // Normalize angle to 0-2π range
    double normalizedAngle = angle % (2 * 3.14159);
    if (normalizedAngle < 0) normalizedAngle += 2 * 3.14159;

    // Convert angle to minutes (0-360° = 1-60 minutes)
    int minutes = ((normalizedAngle / (2 * 3.14159)) * 60).round();
    if (minutes == 0) minutes = 1; // Minimum 1 minute

    setState(() {
      _snoozeMinutes = minutes.clamp(1, 60);
      _currentAngle = normalizedAngle;
      // Clear preset selection when manually adjusting
      _selectedPreset = null;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size, Offset center) {
    // Calculate the angle based on touch position
    final touchPosition = details.localPosition;
    final dx = touchPosition.dx - center.dx;
    final dy = touchPosition.dy - center.dy;

    // Calculate angle (atan2 returns angle from -π to π)
    // We need to adjust so 0° is at the top
    double angle = math.atan2(dy, dx) + (3.14159 / 2);

    _updateSnoozeFromAngle(angle);
  }

  DateTime _calculateLaterToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 18, 0); // 6:00 PM
  }

  DateTime _calculateTomorrowMorning() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1, 9, 0); // 9:00 AM
  }

  DateTime _calculateOtherDayDefault() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
  }

  Future<void> _handleConfirmSnooze() async {
    if (_isLoading) return;
    final now = DateTime.now();

    // Validate and get target time based on selected preset
    DateTime? targetTime;
    if (_selectedPreset == 'later') {
      if (_laterTodayTime == null || !_laterTodayTime!.isAfter(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose a time later than now'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      targetTime = _laterTodayTime;
    } else if (_selectedPreset == 'morning') {
      if (_tomorrowTime == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose a time for tomorrow'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      targetTime = _tomorrowTime;
    } else if (_selectedPreset == 'other_day') {
      if (_otherDayDateTime == null || !_otherDayDateTime!.isAfter(now)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose a date and time in the future'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      targetTime = _otherDayDateTime;
    } else {
      // Minutes-based snooze (default or when circle is used)
      targetTime = now.add(Duration(minutes: _snoozeMinutes));
    }

    setState(() => _isLoading = true);
    try {
      if (_selectedPreset == 'later' || _selectedPreset == 'morning' || _selectedPreset == 'other_day') {
        await _reminderService.snoozeReminderTo(widget.reminderId, targetTime!);
      } else {
        await _reminderService.snoozeReminder(widget.reminderId, minutes: _snoozeMinutes);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to snooze: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleMarkComplete() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await _reminderService.markAsCompleted(widget.reminderId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getIconForTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) {
      return Icons.wb_sunny_outlined; // Morning
    } else if (hour >= 12 && hour < 17) {
      return Icons.wb_sunny; // Afternoon
    } else if (hour >= 17 && hour < 20) {
      return Icons.wb_twilight_outlined; // Evening
    } else {
      return Icons.nightlight_outlined; // Night
    }
  }

  String _getTimeOfDayLabel(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'MORNING';
    if (hour >= 12 && hour < 17) return 'AFTERNOON';
    if (hour >= 17 && hour < 20) return 'EVENING';
    return 'NIGHT';
  }

  Future<void> _pickTodayTime() async {
    final now = DateTime.now();
    final initialTime =
        _laterTodayTime ?? DateTime(now.year, now.month, now.day, 18, 0);

    final TimeOfDay? picked = await showCupertinoTimePickerModal(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );

    if (picked != null) {
      final selectedTime = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );

      // Only allow times after current time
      if (selectedTime.isAfter(now)) {
        setState(() {
          _laterTodayTime = selectedTime;
          _selectedPreset = 'later';
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a time after the current time'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickTomorrowTime() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final initialTime =
        _tomorrowTime ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);

    final TimeOfDay? picked = await showCupertinoTimePickerModal(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialTime),
    );

    if (picked != null) {
      final selectedTime = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        picked.hour,
        picked.minute,
      );

      setState(() {
        _tomorrowTime = selectedTime;
        _selectedPreset = 'morning';
      });
    }
  }

  Future<void> _pickOtherDayDateTime() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final initialDate =
        _otherDayDateTime ??
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);

    final DateTime? pickedDate = await showCupertinoDatePickerModal(
      context: context,
      initialDate: initialDate.isBefore(now) ? tomorrow : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showCupertinoTimePickerModal(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _otherDayDateTime ?? initialDate,
        ),
      );

      if (pickedTime != null) {
        final selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        if (selectedDateTime.isAfter(now)) {
          setState(() {
            _otherDayDateTime = selectedDateTime;
            _selectedPreset = 'other_day';
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please choose a date and time in the future'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background color with accent tint (same as home screen)
    final backgroundColor = _isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!;

    // Dynamic colors based on theme
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2A2A2A);
    final subtitleColor = _isDarkMode ? Colors.white70 : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: subtitleColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'REMINDER',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: subtitleColor,
                      size: 24.sp,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40.h),

            // Circular Snooze Selector
            GestureDetector(
              onPanUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final center = Offset(box.size.width / 2, 140.h + 40.h + 140.h);
                _handlePanUpdate(details, box.size, center);
              },
              child: Container(
                width: 296.w, // 280 + 16 (handle size for padding)
                height: 296.h,
                padding: EdgeInsets.all(8.r), // Padding for handle overflow
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Background Circle
                    Container(
                      width: 280.w,
                      height: 280.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                    ),

                    // Progress Arc
                    SizedBox(
                      width: 280.w,
                      height: 280.h,
                      child: CustomPaint(
                        painter: _SnoozeArcPainter(
                          progress: _snoozeMinutes / 60,
                          angle: _currentAngle,
                          accentColor: _accentColor,
                        ),
                      ),
                    ),

                    // Center Content
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SNOOZE FOR',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '+$_snoozeMinutes',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 68.sp,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'minutes',
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    // Draggable Handle
                    Positioned(
                      left:
                          140.w +
                          137.w * math.cos(_currentAngle - math.pi / 2) -
                          16.w,
                      top:
                          140.h +
                          137.h * math.sin(_currentAngle - math.pi / 2) -
                          16.h,
                      child: Stack(
                        children: [
                          Container(
                            width: 32.w,
                            height: 32.h,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 10.w,
                            top: 10.h,
                            child: Container(
                              width: 12.w,
                              height: 12.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 60.h),

            // Preset Options
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildPresetCard(
                          icon: _laterTodayTime != null
                              ? _getIconForTime(_laterTodayTime!)
                              : Icons.wb_sunny_outlined,
                          label: 'LATER',
                          time: 'Today',
                          subtitle: _laterTodayTime != null
                              ? DateFormat('h:mm a').format(_laterTodayTime!)
                              : DateFormat(
                                  'h:mm a',
                                ).format(_calculateLaterToday()),
                          isSelected: _selectedPreset == 'later',
                          onTap: _pickTodayTime,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildPresetCard(
                          icon: _tomorrowTime != null
                              ? _getIconForTime(_tomorrowTime!)
                              : Icons.wb_twilight_outlined,
                          label: _getTimeOfDayLabel(
                            _tomorrowTime ?? _calculateTomorrowMorning(),
                          ),
                          time: 'Tomorrow',
                          subtitle: _tomorrowTime != null
                              ? DateFormat('h:mm a').format(_tomorrowTime!)
                              : DateFormat(
                                  'h:mm a',
                                ).format(_calculateTomorrowMorning()),
                          isSelected: _selectedPreset == 'morning',
                          onTap: _pickTomorrowTime,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildPresetCard(
                    icon: Icons.calendar_today_outlined,
                    label: 'ANOTHER DAY',
                    time: _otherDayDateTime != null
                        ? DateFormat('EEEE, MMM d').format(_otherDayDateTime!)
                        : 'Pick date',
                    subtitle: _otherDayDateTime != null
                        ? DateFormat('h:mm a').format(_otherDayDateTime!)
                        : DateFormat('h:mm a').format(_calculateOtherDayDefault()),
                    isSelected: _selectedPreset == 'other_day',
                    onTap: _pickOtherDayDateTime,
                    isFullWidth: true,
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Action Buttons
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              child: Column(
                children: [
                  // Confirm Snooze Button
                  SizedBox(
                    width: double.infinity,
                    height: 70.h,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleConfirmSnooze,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: _isDarkMode ? Colors.white : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 24.h,
                              width: 24.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.alarm, size: 22.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Confirm Snooze',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Mark as Complete Button
                  TextButton(
                    onPressed: _isLoading ? null : _handleMarkComplete,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20.sp,
                          color: subtitleColor,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Mark as Complete',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required IconData icon,
    required String label,
    required String time,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    // Dynamic colors based on theme
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2A2A2A);
    final subtitleColor = _isDarkMode ? Colors.white70 : const Color(0xFF666666);
    final cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isSelected
              ? (_isDarkMode ? const Color(0xFF2A2A2A) : cardColor)
              : (_isDarkMode ? Colors.white.withOpacity(0.05) : cardColor.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? _accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: isFullWidth
            ? Row(
                children: [
                  Icon(icon, color: _accentColor, size: 20.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: _accentColor,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '$time • $subtitle',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: subtitleColor.withOpacity(0.5),
                    size: 16.sp,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: _accentColor, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        label,
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    time,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SnoozeArcPainter extends CustomPainter {
  final double progress;
  final double angle;
  final Color accentColor;

  _SnoozeArcPainter({required this.progress, required this.angle, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Paint for the background grey arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Paint for the progress arc
    final progressPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    // Draw full background arc from top (270 degrees) clockwise
    const startAngle = -90 * 3.14159 / 180; // Start from top
    const fullSweepAngle = 2 * 3.14159; // Full circle

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      startAngle,
      fullSweepAngle,
      false,
      backgroundPaint,
    );

    // Draw progress arc on top
    final sweepAngle = angle; // Use the actual angle

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 3),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_SnoozeArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.angle != angle;
  }
}
