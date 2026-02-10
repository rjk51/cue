import 'dart:async';
import 'package:cue/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flip_card/flip_card.dart';
import 'package:lottie/lottie.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/presentation/create_reminder_screen.dart';
import '../../reminders/presentation/reminder_list_screen.dart';
import '../../reminders/presentation/reminder_details_screen.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../services/device_monitor_service.dart';
import '../../../services/widget_service.dart';
import '../../../services/tutorial_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/expandable_fab.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/delete_recurring_dialog.dart';
import '../../../shared/widgets/tutorial_overlay.dart';
import 'widgets/current_cue_card.dart';
import '../../pulse/presentation/pulse_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ReminderService _reminderService = ReminderService();
  final ThemeService _themeService = ThemeService();
  final DeviceMonitorService _deviceMonitor = DeviceMonitorService();
  final WidgetService _widgetService = WidgetService();
  final TutorialService _tutorialService = TutorialService();

  Color _accentColor = const Color(0xFF2D7A78); // Default teal
  Color? _backgroundColor;
  bool _isDarkMode = false;

  // Tutorial state
  bool _showFabTutorial = false;
  bool _showCueCardTutorial = false;
  bool _hasShownCueCardTutorial = false;
  int _cueCardTutorialStep =
      0; // 0: highlight card, 1: snooze, 2: done, 3: notes, 4: flip
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _cueCardKey = GlobalKey();

  // Progress bar state
  int _completedTasksCount = 0;
  int _totalTasksCount = 0;
  bool _isRunnerAnimating = false;
  late AnimationController _runnerController;
  late Animation<double> _runnerAnimation;
  StreamSubscription<List<Reminder>>? _progressStreamSub;
  int _previousCompletedTasksCount = 0;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _checkTutorialState();
    // Listen for theme changes
    ThemeNotifier.instance.addListener(_onThemeChanged);

    // Initialize runner animation controller
    _runnerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _runnerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _runnerController, curve: Curves.easeInOut),
    );

    // Start a dedicated progress stream that includes completed reminders
    _startProgressStream();

    // Start monitoring device status after a delay to ensure device is reactivated
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait for device to be reactivated in main.dart
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        _deviceMonitor.startMonitoring(context);
      }
    });
  }

  @override
  void dispose() {
    _progressStreamSub?.cancel();
    _runnerController.dispose();
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _deviceMonitor.stopMonitoring();
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
    final bgColor = await _themeService.getBackgroundColor();

    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _backgroundColor = bgColor;
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

  Future<void> _checkTutorialState() async {
    // Show FAB tutorial only once based on stored flag
    final shouldShowFab = await _tutorialService.shouldShowFabTutorial();

    if (mounted && shouldShowFab) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showFabTutorial = true;
        });
      }
    }
  }

  void _onFabTutorialNext() {
    setState(() {
      _showFabTutorial = false;
    });
    _tutorialService.markTutorialShown(TutorialService.homeFabShownKey);
  }

  void _onFabTutorialSkip() {
    setState(() {
      _showFabTutorial = false;
    });
    _tutorialService.completeTutorial();
  }

  void _checkCueCardTutorial(bool isCueCardPresent) {
    // Only show cue card tutorial once per user when a cue card is visible
    if (!isCueCardPresent || _showCueCardTutorial || _hasShownCueCardTutorial) {
      return;
    }

    // Avoid showing while FAB tutorial is on screen
    if (_showFabTutorial) return;

    _tutorialService.shouldShowCueCardTutorial().then((shouldShow) {
      if (!mounted ||
          !shouldShow ||
          _showCueCardTutorial ||
          _hasShownCueCardTutorial) {
        return;
      }

      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_showFabTutorial && !_showCueCardTutorial) {
          setState(() {
            _showCueCardTutorial = true;
            _cueCardTutorialStep = 0;
            _hasShownCueCardTutorial = true;
          });
        }
      });
    });
  }

  void _onCueCardTutorialNext() {
    if (_cueCardTutorialStep < 4) {
      setState(() {
        _cueCardTutorialStep++;
      });
    } else {
      setState(() {
        _showCueCardTutorial = false;
        _cueCardTutorialStep = 0;
      });
      _tutorialService.markMultipleTutorialsShown([
        TutorialService.homeCueCardShownKey,
        TutorialService.homeSnoozeShownKey,
        TutorialService.homeDoneShownKey,
        TutorialService.homeNotesShownKey,
        TutorialService.homeFlipShownKey,
      ]);
    }
  }

  void _onCueCardTutorialSkip() {
    setState(() {
      _showCueCardTutorial = false;
      _cueCardTutorialStep = 0;
    });
    _tutorialService.completeTutorial();
  }

  String _getCueCardTutorialTitle() {
    switch (_cueCardTutorialStep) {
      case 0:
        return 'Your Current Cue';
      case 1:
        return 'Snooze';
      case 2:
        return 'Mark as Done';
      case 3:
        return 'Add Notes';
      case 4:
        return 'Flip for More';
      default:
        return '';
    }
  }

  String _getCueCardTutorialDescription() {
    switch (_cueCardTutorialStep) {
      case 0:
        return 'This is your current or next reminder. It shows what you need to focus on right now.';
      case 1:
        return 'Tap snooze to snooze this reminder for a few minutes when you need more time.';
      case 2:
        return 'Tap done to mark the reminder completed. Great job staying on track!';
      case 3:
        return 'Tap inside the card to add notes or additional details about this reminder.';
      case 4:
        return 'Flip the card to see more options like editing or deleting this reminder.';
      default:
        return '';
    }
  }

  Future<void> _updateWidgets(List<Reminder> reminders) async {
    // Update iOS widgets with current reminder data
    await _widgetService.updateWidget(reminders);
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

  void _navigateToVoiceReminder() async {
    final result = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(builder: (context) => const NewReminderScreen(openedForVoice: true)),
    );

    if (result != null && mounted) {
      context.showSuccessSnackbar('Reminder created successfully!');
    }
  }

  Future<void> _markAsCompleted(
    String reminderId, {
    DateTime? occurrenceTime,
  }) async {
    if (mounted) {
      setState(() {
        _isRunnerAnimating = true;
      });
      
      _runnerController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _isRunnerAnimating = false;
          });
        }
      });
    }

    // Execute in background — the progress stream will automatically pick up the change
    _reminderService
        .markAsCompleted(reminderId, occurrenceTime: occurrenceTime)
        .catchError((e) {
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

    // For future reminders: consider current if within 30 minutes before
    if (difference.inMinutes >= 0) {
      return difference.inMinutes <= 30;
    }

    // For past reminders: only show if within 20 minutes past due
    return difference.inMinutes.abs() <= 20;
  }

  bool _isDateWithinUpcomingRange(DateTime date, DateTime now) {
    final difference = date.difference(now);
    // Include reminders from today up to 7 days in the future
    return difference.inDays >= 0 && difference.inDays <= 7;
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
    // Background color with accent tint (or custom background color if set)
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final tnText = ThemeNotifier.instance.textColor;
    final textColor = tnText ?? (_isDarkMode ? Colors.white : const Color(0xFF2D2D2D));
    final subtitleColor = tnText != null ? tnText.withOpacity(0.7) : (_isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A));

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          SafeArea(
            child: StreamBuilder<List<Reminder>>(
              stream: _reminderService.getRemindersStream(),
              builder: (context, snapshot) {
                final reminders = snapshot.data ?? [];

                // Update widgets whenever reminders change (including empty state)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _updateWidgets(reminders);
                });

                // Sort reminders by time
                final sortedReminders = List<Reminder>.from(reminders)
                  ..sort((a, b) => a.time.compareTo(b.time));

                // Expand hourly reminders into multiple occurrences
                final expandedReminders = <Map<String, dynamic>>[];
                final now = DateTime.now();

                for (final reminder in sortedReminders) {
                  // Check if it's an hourly reminder
                  if (reminder.recurrence != null) {
                    final recurrence = reminder.recurrence!;
                    final type = recurrence['type'] as String?;
                    final unit = recurrence['unit'] as String?;

                    if (type == 'interval' &&
                        (unit == 'hours' || unit == 'minutes')) {
                      // Expand hourly reminder into multiple occurrences for today
                      final occurrences = _getHourlyOccurrencesForDay(
                        reminder,
                        now,
                      );
                      for (final occurrence in occurrences) {
                        final dateKey = DateFormat(
                          'yyyy-MM-dd',
                        ).format(occurrence);
                        // Skip if this occurrence is skipped or completed
                        if (!reminder.isSkippedOnDate(dateKey) &&
                            !reminder.isOccurrenceCompleted(occurrence)) {
                          expandedReminders.add({
                            'reminder': reminder,
                            'occurrenceTime': occurrence,
                          });
                        }
                      }
                    } else {
                      // Single occurrence for non-hourly recurring reminders
                      final effectiveDate = reminder.effectiveNextDueAt;
                      final dateKey = DateFormat(
                        'yyyy-MM-dd',
                      ).format(effectiveDate);

                      if (!reminder.isSkippedOnDate(dateKey)) {
                        final effectiveDate = reminder.effectiveNextDueAt;
                        final isScheduledSoon = _isDateWithinUpcomingRange(effectiveDate, now);

                        if (isScheduledSoon && !reminder.isCompletedToday) {
                          expandedReminders.add({
                            'reminder': reminder,
                            'occurrenceTime': null,
                          });
                        }
                      }
                    }
                  } else {
                    // Non-recurring reminder
                    final effectiveDate = reminder.effectiveNextDueAt;
                    final isScheduledSoon = _isDateWithinUpcomingRange(effectiveDate, now);

                    if (isScheduledSoon && !reminder.isCompletedToday) {
                      expandedReminders.add({
                        'reminder': reminder,
                        'occurrenceTime': null,
                      });
                    }
                  }
                }

                // Filter for today's reminders
                final todayReminders = expandedReminders
                    .where(
                      (item) =>
                          item['occurrenceTime'] != null ||
                          !(item['reminder'] as Reminder).isCompletedToday,
                    )
                    .map((item) => item['reminder'] as Reminder)
                    .toList();

                // Get current/next reminder (first uncompleted) — only today's reminders
                final upcomingReminders = expandedReminders
                    .where(
                      (item) =>
                          item['occurrenceTime'] != null ||
                          !(item['reminder'] as Reminder).isCompletedToday,
                    )
                    .toList();

                // Sort by occurrence time
                upcomingReminders.sort((a, b) {
                  final aReminder = a['reminder'] as Reminder;
                  final bReminder = b['reminder'] as Reminder;
                  final aOccurrence = a['occurrenceTime'] as DateTime?;
                  final bOccurrence = b['occurrenceTime'] as DateTime?;

                  final aTime =
                      aOccurrence ?? aReminder.getEffectiveDisplayTime();
                  final bTime =
                      bOccurrence ?? bReminder.getEffectiveDisplayTime();
                  return aTime.compareTo(bTime);
                });

                final currentReminder = upcomingReminders.isNotEmpty
                    ? upcomingReminders.first['reminder'] as Reminder
                    : null;

                // Check tutorial for cue card (new logic)
                _checkCueCardTutorial(currentReminder != null);

                final currentOccurrenceTime = upcomingReminders.isNotEmpty
                    ? upcomingReminders.first['occurrenceTime'] as DateTime?
                    : null;

                // Upcoming reminders (after current)
                final upcomingAfterCurrent = upcomingReminders.length > 1
                    ? upcomingReminders.sublist(1)
                    : <Map<String, dynamic>>[];

                final isKeyboardOpen =
                    MediaQuery.of(context).viewInsets.bottom > 0;
                final screenHeight =
                    MediaQuery.of(context).size.height -
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
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Row(
                              children: [
                                Text(
                                  'Today, ',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('MMM d').format(now)}',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w400,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (sortedReminders.isNotEmpty) ...[
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
                                    Container(
                                      key: _cueCardKey,
                                      child: CurrentCueCard(
                                        reminder: currentReminder,
                                        occurrenceTime: currentOccurrenceTime,
                                        accentColor: _accentColor,
                                        isDarkMode: _isDarkMode,
                                        cardColor: cardColor,
                                        textColor: textColor,
                                        subtitleColor: subtitleColor,
                                        onMarkCompleted: (reminderId) =>
                                            _markAsCompleted(
                                              reminderId,
                                              occurrenceTime:
                                                  currentOccurrenceTime,
                                            ),
                                        getTimeDisplayText: _getTimeDisplayText,
                                        isCurrentCue: _isCurrentCue,
                                      ),
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
                          ] else ...[
                            // Show empty cue card when no reminders
                            SizedBox(height: 32.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildEmptyCueCard(
                                    cardColor,
                                    textColor,
                                    subtitleColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ] else ...[
                          // Date header - always shown
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Today, ',
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('MMM d').format(now)}',
                                  style: TextStyle(
                                    fontSize: 22.sp,
                                    fontWeight: FontWeight.w400,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (sortedReminders.isNotEmpty) ...[
                            SizedBox(height: 22.h),

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
                                      Container(
                                        key: _cueCardKey,
                                        child: CurrentCueCard(
                                          reminder: currentReminder,
                                          accentColor: _accentColor,
                                          isDarkMode: _isDarkMode,
                                          cardColor: cardColor,
                                          textColor: textColor,
                                          subtitleColor: subtitleColor,
                                          onMarkCompleted: _markAsCompleted,
                                          getTimeDisplayText:
                                              _getTimeDisplayText,
                                          isCurrentCue: _isCurrentCue,
                                        ),
                                      )
                                    else
                                      _buildEmptyCueCard(
                                        cardColor,
                                        textColor,
                                        subtitleColor,
                                      ),

                                    SizedBox(height: 32.h),

                                    // Upcoming Section - flexible to avoid overflow
                                    Flexible(
                                      child: _buildUpcomingSection(
                                        upcomingAfterCurrent,
                                        cardColor,
                                        textColor,
                                        subtitleColor,
                                      ),
                                    ),
                                    
                                    // Bottom padding to prevent FAB overlap
                                    SizedBox(height: 120.h),
                                  ],
                                ),
                              ),
                            ),
                          ] else ...[
                            // Show empty cue card when no reminders
                            SizedBox(height: 22.h),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildEmptyCueCard(
                                      cardColor,
                                      textColor,
                                      subtitleColor,
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

          // Pulse + Settings icons positioned at top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 10.h,
            right: 20.w,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PulseScreen(),
                        ),
                      );
                      if (mounted) {
                        await _loadThemeSettings();
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      child: Icon(
                        Icons.insights_rounded,
                        color: _accentColor,
                        size: 26.sp,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                // Settings button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                      // Reload theme settings when coming back
                      if (mounted) {
                        await _loadThemeSettings();
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      child: Image.asset(
                        'assets/settings.png',
                        width: 28.w,
                        height: 28.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable FAB positioned in Stack
          Positioned(
            right: 34.w,
            bottom: MediaQuery.of(context).padding.bottom + 30.h,
            child: Container(
              key: _fabKey,
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

          // Progress bar at bottom left (always visible if tasks exist today)
          if (_totalTasksCount > 0)
            Positioned(
              left: 20.w,
              bottom: MediaQuery.of(context).padding.bottom + 30.h,
              child: _buildProgressBar(),
            ),

          // Tutorial overlays
          if (_showFabTutorial)
            TutorialOverlay(
              targetKey: _fabKey,
              title: 'Create Your First Reminder',
              description:
                  'Tap the + button to create your first reminder. You can set a time, add notes, and customize it however you like!',
              onSkip: _onFabTutorialSkip,
              onNext: _onFabTutorialNext,
              isLastStep: true,
              accentColor: _accentColor,
              isDarkMode: _isDarkMode,
              highlightPadding: EdgeInsets.all(12.w),
            ),

          if (_showCueCardTutorial &&
              // removed check for _cueCardKey.currentContext != null since we check mounted in TutorialOverlay
              _cueCardKey.currentContext != null)
            TutorialOverlay(
              targetKey: _cueCardKey,
              title: _getCueCardTutorialTitle(),
              description: _getCueCardTutorialDescription(),
              onSkip: _onCueCardTutorialSkip,
              onNext: _onCueCardTutorialNext,
              isLastStep: _cueCardTutorialStep == 4,
              accentColor: _accentColor,
              isDarkMode: _isDarkMode,
              highlightPadding: EdgeInsets.all(16.w),
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
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFFFF8E6E),
              BlendMode.srcIn,
            ),
            child: Lottie.asset(
              'assets/success.json',
              width: 120.w,
              height: 120.h,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to icon if Lottie fails to load
                return Icon(
                  Icons.check_circle_outline_rounded,
                  size: 64.sp,
                  color: _accentColor,
                );
              },
            ),
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
    List<Map<String, dynamic>> upcomingReminders,
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
                    'That\'s everything for today',
                    style: TextStyle(fontSize: 14.sp, color: subtitleColor),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: upcomingReminders.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12.w),
                  itemBuilder: (context, index) {
                    final item = upcomingReminders[index];
                    final reminder = item['reminder'] as Reminder;
                    final occurrenceTime = item['occurrenceTime'] as DateTime?;
                    return _buildUpcomingCard(
                      reminder,
                      cardColor,
                      textColor,
                      subtitleColor,
                      occurrenceTime,
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
    DateTime? occurrenceTime,
  ) {
    // Use occurrence time if provided, otherwise use reminder time
    final displayTime = occurrenceTime ?? reminder.time;
    final timeOnly = DateFormat('hh:mm').format(displayTime);
    final amPm = DateFormat('a').format(displayTime);

    final flipKey = GlobalKey<FlipCardState>();

    return GestureDetector(
      onLongPress: () {
        flipKey.currentState?.toggleCard();
      },
      child: FlipCard(
        key: flipKey,
        fill: Fill.fillBack,
        direction: FlipDirection.HORIZONTAL,
        flipOnTouch: false,
        front: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReminderDetailsScreen(reminder: reminder),
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
                      child: reminder.customIconUrl != null
                          ? ClipOval(
                              child: Image.network(
                                reminder.customIconUrl!,
                                width: 32.w,
                                height: 32.h,
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
                          : Icon(
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
        ),
        back: Container(
          width: 180.w,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(
              color: reminder.color.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.all(8.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              _buildSmallActionButton(
                icon: Icons.edit_rounded,
                label: 'EDIT',
                color: _accentColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NewReminderScreen(reminderToEdit: reminder),
                    ),
                  );
                },
              ),
              SizedBox(width: 8.w),
              // Delete button
              _buildSmallActionButton(
                icon: Icons.delete_rounded,
                label: 'Skip/Delete',
                color: Colors.red.shade400,
                onTap: () => _handleUpcomingCardDelete(reminder),
              ),
            ],
          ),
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

    // Contextual message based on reminder count
    String contextualMessage;
    if (count <= 2) {
      contextualMessage = 'Take it slow today.';
    } else if (count <= 4) {
      contextualMessage = 'Almost done for today.';
    } else {
      contextualMessage = 'You\'ve got this!';
    }

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
          SizedBox(height: 6.h),
          Text(
            contextualMessage,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: subtitleColor.withOpacity(0.7),
              fontStyle: FontStyle.italic,
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
      child: Icon(icon, color: color, size: 22.sp),
    );
  }

  // Helper method for small action buttons on upcoming cards back side
  Widget _buildSmallActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70.w,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 36.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle delete action for upcoming cards
  Future<void> _handleUpcomingCardDelete(Reminder reminder) async {
    final reminderService = ReminderService();

    // For recurring reminders, show dialog to choose between skipping occurrence or deleting series
    if (reminder.recurrence != null) {
      final deleteOption = await DeleteRecurringDialog.show(
        context: context,
        reminderName: reminder.name,
        accentColor: _accentColor,
        isDarkMode: _isDarkMode,
      );

      // User cancelled the dialog
      if (deleteOption == null) {
        return;
      }

      if (deleteOption == DeleteRecurringOption.thisOccurrenceOnly) {
        // Skip this occurrence by creating a skipped override
        try {
          final occurrenceDate = reminder.effectiveNextDueAt;
          final dateKey = DateFormat('yyyy-MM-dd').format(occurrenceDate);

          // Get existing overrides or create new map
          final existingOverrides = reminder.overrides ?? {};
          final newOverrides = Map<String, Map<String, dynamic>>.from(
            existingOverrides,
          );

          // Create or update override for this date with skipped flag
          newOverrides[dateKey] = {
            ...(newOverrides[dateKey] ?? {}),
            'skipped': true,
          };

          await reminderService.updateReminder(reminder.id, {
            'overrides': newOverrides,
          });

          if (mounted) {
            context.showSuccessSnackbar('Occurrence skipped');
          }
        } catch (e) {
          if (mounted) {
            context.showErrorSnackbar('Error skipping occurrence: $e');
          }
        }
        return;
      }
      // If wholeSeries, fall through to show confirmation dialog
    }

    // For non-recurring reminders or when deleting whole series, show confirmation dialog
    await ConfirmationDialog.show(
      context: context,
      title: reminder.recurrence != null
          ? 'Delete Entire Series'
          : 'Delete Reminder',
      message: reminder.recurrence != null
          ? 'Are you sure you want to permanently delete "${reminder.name}" and all its occurrences? This action cannot be undone.'
          : 'Are you sure you want to delete "${reminder.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      accentColor: _accentColor,
      isDarkMode: _isDarkMode,
      isDestructive: true,
      onConfirm: () async {
        try {
          await reminderService.deleteReminder(reminder.id);
          if (mounted) {
            context.showSuccessSnackbar(
              reminder.recurrence != null
                  ? 'Reminder series deleted successfully'
                  : 'Reminder deleted successfully',
            );
          }
        } catch (e) {
          if (mounted) {
            context.showErrorSnackbar('Error deleting reminder: $e');
          }
        }
      },
    );
  }

  /// Subscribe to a dedicated stream that includes ALL today's reminders
  /// (including completed non-recurring ones) for accurate progress counting.
  void _startProgressStream() {
    _progressStreamSub = _reminderService.getAllRemindersForTodayStream().listen((reminders) {
      if (!mounted) return;
      final now = DateTime.now();

      int todayTotal = 0;
      int todayCompleted = 0;

      for (final reminder in reminders) {
        if (reminder.recurrence != null) {
          final recurrence = reminder.recurrence!;
          final type = recurrence['type'] as String?;
          final unit = recurrence['unit'] as String?;

          if (type == 'interval' && (unit == 'hours' || unit == 'minutes')) {
            // Hourly/minute-interval reminders: count each occurrence
            final occurrences = _getHourlyOccurrencesForDay(reminder, now);
            for (final occurrence in occurrences) {
              final dateKey = DateFormat('yyyy-MM-dd').format(occurrence);
              if (!reminder.isSkippedOnDate(dateKey)) {
                todayTotal++;
                if (reminder.isOccurrenceCompleted(occurrence)) {
                  todayCompleted++;
                }
              }
            }
          } else {
            // Daily/weekly/monthly recurring: check if due today
            final effectiveDate = reminder.effectiveNextDueAt;
            final isToday = effectiveDate.year == now.year &&
                effectiveDate.month == now.month &&
                effectiveDate.day == now.day;

            if (isToday) {
              todayTotal++;
              if (reminder.isCompletedToday) {
                todayCompleted++;
              }
            }
          }
        } else {
          // Non-recurring reminder — time is always today (stream already filtered)
          todayTotal++;
          if (reminder.isCompleted) {
            todayCompleted++;
          }
        }
      }

      if (_totalTasksCount != todayTotal || _completedTasksCount != todayCompleted) {
        setState(() {
          _previousCompletedTasksCount = _completedTasksCount;
          _totalTasksCount = todayTotal;
          _completedTasksCount = todayCompleted;
        });
      }
    });
  }

  Widget _buildProgressBar() {
    final progress = _totalTasksCount > 0 ? _completedTasksCount / _totalTasksCount : 0.0;
    const barWidth = 150.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Running character animation
        SizedBox(
          width: barWidth.w,
          height: 70.h,
          child: AnimatedBuilder(
            animation: _runnerAnimation,
            builder: (context, child) {
              // Calculate runner position based on progress
              double targetProgress = progress;
              if (_isRunnerAnimating) {
                // Interpolate from previous completed count to current for smooth animation
                final prevTotal = _totalTasksCount > 0 ? _totalTasksCount : 1;
                final previousProgress = prevTotal > 0
                    ? (_previousCompletedTasksCount / prevTotal)
                    : 0.0;
                targetProgress = previousProgress + (progress - previousProgress) * _runnerAnimation.value;
              }

              targetProgress = targetProgress.clamp(0.0, 1.0);

              final runnerSize = 70.w;
              final effectiveBarWidth = barWidth.w;
              // Align runner CENTER with the end of the progress fill.
              final fillWidth = (barWidth * targetProgress).w;
              final desiredLeft = fillWidth - runnerSize / 2;
              // Ensure the runner stays fully visible within the bar container
              final minLeft = 0.0;
              final maxLeft = effectiveBarWidth - runnerSize;
              final clampedOffset = desiredLeft.clamp(minLeft, maxLeft);

              return Transform.translate(
                offset: Offset(clampedOffset, 0),
                child: _isRunnerAnimating
                    ? Image.asset(
                        'assets/running_guy.gif',
                        width: runnerSize,
                        height: 70.h,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            '🏃',
                            style: TextStyle(fontSize: 40.sp),
                          );
                        },
                      )
                    : SizedBox.shrink(),
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
        
        // Progress bar container
        Container(
          width: barWidth.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: _isDarkMode 
                ? Colors.white.withOpacity(0.1) 
                : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Stack(
            children: [
              // Progress fill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: (barWidth * progress).w,
                height: 8.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8E6E),
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4.h),
        
        // Task count text
        Text(
          '$_completedTasksCount/$_totalTasksCount tasks',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: _isDarkMode 
                ? Colors.white.withOpacity(0.7) 
                : Colors.black.withOpacity(0.6),
          ),
        ),
      ],
    );
  }


}
