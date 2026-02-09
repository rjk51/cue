import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/reminder_model.dart';
import '../data/reminder_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/delete_recurring_dialog.dart';
import '../../snooze/presentation/snooze_screen.dart';
import 'create_reminder_screen.dart';

class ReminderDetailsScreen extends StatefulWidget {
  final Reminder reminder;

  const ReminderDetailsScreen({
    super.key,
    required this.reminder,
  });

  @override
  State<ReminderDetailsScreen> createState() => _ReminderDetailsScreenState();
}

class _ReminderDetailsScreenState extends State<ReminderDetailsScreen> {
  final ThemeService _themeService = ThemeService();
  final ReminderService _reminderService = ReminderService();
  final TextEditingController _notesController = TextEditingController();
  final FocusNode _notesFocusNode = FocusNode();
  Color _accentColor = const Color(0xFFFFB4A3);
  Color? _backgroundColor;
  bool _isDarkMode = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.reminder.notes ?? '';
    _loadThemeSettings();
    ThemeNotifier.instance.addListener(_onThemeChanged);
    
    // Update UI when focus changes
    _notesFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _saveNotes() async {
    final newNotes = _notesController.text.trim();
    if (newNotes != (widget.reminder.notes ?? '')) {
      try {
        await _reminderService.updateReminder(
          widget.reminder.id,
          {'notes': newNotes.isEmpty ? null : newNotes},
        );
      } catch (e) {
        if (mounted) {
          context.showErrorSnackbar('Error saving notes: $e');
        }
      }
    }
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
    final backgroundColor = await _themeService.getBackgroundColor();
    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _backgroundColor = backgroundColor;
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

  Future<void> _handleComplete() async {
    if (_isCompleting) return;
    
    setState(() {
      _isCompleting = true;
    });
    
    try {
      await _reminderService.markAsCompleted(widget.reminder.id);
      
      if (mounted) {
        context.showSuccessSnackbar('Marked as done!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  Future<void> _handleSnooze() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SnoozeScreen(
          reminderId: widget.reminder.id,
          reminderTitle: widget.reminder.name,
        ),
      ),
    );
  }

  Future<void> _handleEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewReminderScreen(
          reminderToEdit: widget.reminder,
        ),
      ),
    );
    
    // If reminder was updated, refresh the screen
    if (result == true && mounted) {
      Navigator.pop(context, true); // Pop back to previous screen with refresh signal
    }
  }

  Future<void> _handleDelete() async {
    // For recurring reminders, show dialog to choose between skipping occurrence or deleting series
    if (widget.reminder.recurrence != null) {
      final deleteOption = await DeleteRecurringDialog.show(
        context: context,
        reminderName: widget.reminder.name,
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
          final occurrenceDate = widget.reminder.effectiveNextDueAt;
          final dateKey = DateFormat('yyyy-MM-dd').format(occurrenceDate);

          // Get existing overrides or create new map
          final existingOverrides = widget.reminder.overrides ?? {};
          final newOverrides = Map<String, Map<String, dynamic>>.from(existingOverrides);

          // Create or update override for this date with skipped flag
          newOverrides[dateKey] = {
            ...(newOverrides[dateKey] ?? {}),
            'skipped': true,
          };

          await _reminderService.updateReminder(
            widget.reminder.id,
            {'overrides': newOverrides},
          );

          if (mounted) {
            Navigator.pop(context); // Pop details screen
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
      title: widget.reminder.recurrence != null
          ? 'Delete Entire Series'
          : 'Delete Reminder',
      message: widget.reminder.recurrence != null
          ? 'Are you sure you want to permanently delete "${widget.reminder.name}" and all its occurrences? This action cannot be undone.'
          : 'Are you sure you want to delete "${widget.reminder.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      accentColor: _accentColor,
      isDarkMode: _isDarkMode,
      isDestructive: true,
      onConfirm: () async {
        try {
          await _reminderService.deleteReminder(widget.reminder.id);
          if (mounted) {
            Navigator.pop(context); // Pop details screen
            context.showSuccessSnackbar(
              widget.reminder.recurrence != null
                  ? 'Reminder series deleted successfully'
                  : 'Reminder deleted successfully'
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

  @override
  Widget build(BuildContext context) {
    // Match home screen colors
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor = _isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    // Get reminder icon and color
    final reminderIcon = widget.reminder.icon;
    final reminderColor = widget.reminder.color;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'REMINDER DETAILS',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  children: [
                    SizedBox(height: 32.h),

                    // Icon with Glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Blurred glow effect
                        Container(
                          width: 140.w,
                          height: 140.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40.r),
                            boxShadow: [
                              BoxShadow(
                                color: reminderColor.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        // Icon container
                        Container(
                          width: 100.w,
                          height: 100.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32.r),
                            color: _isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.white,
                          ),
                          child: widget.reminder.customIconUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(32.r),
                                  child: Image.network(
                                    widget.reminder.customIconUrl!,
                                    width: 100.w,
                                    height: 100.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        reminderIcon,
                                        size: 48.sp,
                                        color: reminderColor,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  reminderIcon,
                                  size: 48.sp,
                                  color: reminderColor,
                                ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24.h),

                    // Reminder Title
                    Text(
                      widget.reminder.name,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 12.h),

                    // Time and Date Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 18.sp,
                          color: subtitleColor,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          DateFormat('h:mm a').format(widget.reminder.time),
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.reminder.recurrence == null) ...[ // If reminder is not recurring, show date
                          SizedBox(width: 12.w),
                          Icon(
                            Icons.calendar_today,
                            size: 16.sp,
                            color: subtitleColor,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            DateFormat('MMM dd, yyyy').format(widget.reminder.time),
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Recurrence Date Range (for recurring reminders)
                    if (widget.reminder.recurrence != null) ...[
                      SizedBox(height: 8.h),
                      _buildRecurrenceDateRange(subtitleColor),
                    ],

                    SizedBox(height: 32.h),

                    // Notes Section (always visible and editable)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.notes_outlined,
                                size: 16.sp,
                                color: subtitleColor,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'NOTES',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _notesController,
                                  focusNode: _notesFocusNode,
                                  cursorColor: _accentColor,
                                  maxLines: null,
                                  minLines: 1,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15.sp,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Add notes...',
                                    hintStyle: TextStyle(
                                      color: subtitleColor.withOpacity(0.5),
                                      fontSize: 15.sp,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) {
                                    _notesFocusNode.unfocus();
                                  },
                                ),
                              ),
                              if (_notesFocusNode.hasFocus) ...[
                                SizedBox(width: 10.w),
                                GestureDetector(
                                  onTap: () {
                                    _notesFocusNode.unfocus();
                                    _saveNotes();
                                  },
                                  child: Container(
                                    width: 32.w,
                                    height: 32.h,
                                    decoration: BoxDecoration(
                                      color: _accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 18.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons
            Padding(
              padding: EdgeInsets.fromLTRB(32.w, 32.h, 32.w, MediaQuery.of(context).padding.bottom + 32.h),
              child: Column(
                children: [
                  // Complete Button
                  SizedBox(
                    width: double.infinity,
                    height: 72.h,
                    child: ElevatedButton(
                      onPressed: _isCompleting ? null : _handleComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: _accentColor.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(41.r),
                        ),
                      ),
                      child: _isCompleting
                          ? SizedBox(
                              width: 24.w,
                              height: 24.h,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 22.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Snooze and Edit Buttons
                  Row(
                    children: [
                      // Snooze Button
                      Expanded(
                        child: SizedBox(
                          height: 56.h,
                          child: OutlinedButton(
                            onPressed: _handleSnooze,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: _isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.alarm,
                                  size: 20.sp,
                                  color: textColor,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Snooze',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: 12.w),

                      // Edit Button
                      Expanded(
                        child: SizedBox(
                          height: 56.h,
                          child: OutlinedButton(
                            onPressed: _handleEdit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(
                                color: _isDarkMode
                                    ? Colors.white.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28.r),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 20.sp,
                                  color: textColor,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Delete Button
                  TextButton(
                    onPressed: _handleDelete,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18.sp,
                          color: Colors.red.shade400,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Delete Reminder',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.red.shade400,
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

  Widget _buildRecurrenceDateRange(Color subtitleColor) {
    final recurrence = widget.reminder.recurrence;
    if (recurrence == null) return const SizedBox.shrink();

    DateTime? startDate;
    DateTime? endDate;

    // Extract start date
    final startDateValue = recurrence['startDate'];
    if (startDateValue != null) {
      if (startDateValue is Timestamp) {
        startDate = startDateValue.toDate();
      } else if (startDateValue is Map) {
        final startDateMap = startDateValue as Map<String, dynamic>;
        if (startDateMap.containsKey('_seconds')) {
          startDate = Timestamp(
            startDateMap['_seconds'] as int,
            startDateMap['_nanoseconds'] as int? ?? 0,
          ).toDate();
        }
      }
    }

    // Extract end date
    final endDateValue = recurrence['endDate'];
    if (endDateValue != null) {
      if (endDateValue is Timestamp) {
        endDate = endDateValue.toDate();
      } else if (endDateValue is Map) {
        final endDateMap = endDateValue as Map<String, dynamic>;
        if (endDateMap.containsKey('_seconds')) {
          endDate = Timestamp(
            endDateMap['_seconds'] as int,
            endDateMap['_nanoseconds'] as int? ?? 0,
          ).toDate();
        }
      }
    }

    if (startDate == null) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          DateFormat('MMM dd, yyyy').format(startDate),
          style: TextStyle(
            color: subtitleColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (endDate != null) ...[
          Text(
            ' - ',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            DateFormat('MMM dd, yyyy').format(endDate),
            style: TextStyle(
              color: subtitleColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
