import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flip_card/flip_card_controller.dart';
import '../../../reminders/domain/reminder_model.dart';
import '../../../reminders/data/reminder_service.dart';
import '../../../reminders/presentation/reminder_details_screen.dart';
import '../../../snooze/presentation/snooze_screen.dart';
import '../../../../shared/widgets/card_back_side.dart';

class CurrentCueCard extends StatefulWidget {
  final Reminder reminder;
  final DateTime? occurrenceTime;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;
  final Function(String) onMarkCompleted;
  final String Function(DateTime) getTimeDisplayText;
  final bool Function(DateTime) isCurrentCue;

  const CurrentCueCard({
    super.key,
    required this.reminder,
    this.occurrenceTime,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
    required this.onMarkCompleted,
    required this.getTimeDisplayText,
    required this.isCurrentCue,
  });

  @override
  State<CurrentCueCard> createState() => _CurrentCueCardState();
}

class _CurrentCueCardState extends State<CurrentCueCard>
    with TickerProviderStateMixin {
  late TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  final ReminderService _reminderService = ReminderService();
  final FlipCardController _flipController = FlipCardController();

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.reminder.notes ?? '');

    // Initialize bounce animation controller
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Start bounce animation when loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
    });

    // Listen to focus changes to update UI and save notes on blur
    _notesFocusNode.addListener(() {
      setState(() {});
      if (!_notesFocusNode.hasFocus) {
        _saveNotes();
      }
    });
  }

  @override
  void didUpdateWidget(CurrentCueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update notes controller when reminder changes
    if (oldWidget.reminder.id != widget.reminder.id) {
      _notesController.text = widget.reminder.notes ?? '';
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final newNotes = _notesController.text.trim();
    if (newNotes != (widget.reminder.notes ?? '')) {
      try {
        await _reminderService.updateReminder(widget.reminder.id, {
          'notes': newNotes.isEmpty ? null : newNotes,
        });
      } catch (e) {
        print('Error saving notes: $e');
      }
    }
  }

  Future<void> _skipCurrentReminder() async {
    try {
      final occurrenceDate = widget.occurrenceTime ?? widget.reminder.effectiveNextDueAt;
      final dateKey = DateFormat('yyyy-MM-dd').format(occurrenceDate);

      // Get existing overrides or create new map
      final existingOverrides = widget.reminder.overrides ?? {};
      final newOverrides = Map<String, Map<String, dynamic>>.from(
        existingOverrides,
      );

      // Create or update override for this date with skipped flag
      newOverrides[dateKey] = {
        ...(newOverrides[dateKey] ?? {}),
        'skipped': true,
      };

      await _reminderService.updateReminder(widget.reminder.id, {
        'overrides': newOverrides,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder skipped',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: widget.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error skipping reminder: $e',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show scheduled time only (original time when snoozed, not the snooze time)
    final displayTime = widget.reminder.scheduledDisplayTime;
    final timeText = widget.getTimeDisplayText(displayTime);
    final formattedTime = DateFormat('hh:mm a').format(displayTime);
    final displayTitle = widget.reminder.getEffectiveDisplayName();
    final snoozedUntil = widget.reminder.snoozedUntil;
    final isSnoozed = snoozedUntil != null;
    final snoozedUntilFormatted = snoozedUntil != null
        ? DateFormat('hh:mm a').format(snoozedUntil)
        : null;

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity!.abs() > 300) {
              _flipController.toggleCard();
            }
          }
        },
        child: FlipCard(
          controller: _flipController,
          direction: FlipDirection.HORIZONTAL,
          flipOnTouch: false,
          front: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ReminderDetailsScreen(reminder: widget.reminder),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: widget.cardColor,
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      widget.isDarkMode ? 0.3 : 0.08,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content
                  Padding(
                    padding: EdgeInsets.all(42.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with label and icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Reminder title
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: TextStyle(
                                  fontSize: 46.sp,
                                  fontWeight: FontWeight.w700,
                                  color: widget.textColor,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Dynamic icon from reminder with bounce animation
                            AnimatedBuilder(
                              animation: _bounceAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _bounceAnimation.value,
                                  child: Container(
                                    width: 50.w,
                                    height: 50.h,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.reminder.color.withOpacity(
                                        0.15,
                                      ),
                                    ),
                                    child: widget.reminder.customIconUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              widget.reminder.customIconUrl!,
                                              width: 50.w,
                                              height: 50.h,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Icon(
                                                      widget.reminder.icon,
                                                      color:
                                                          widget.reminder.color,
                                                      size: 30.sp,
                                                    );
                                                  },
                                            ),
                                          )
                                        : Icon(
                                            widget.reminder.icon,
                                            color: widget.reminder.color,
                                            size: 30.sp,
                                          ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // Time info (below title) — scheduled time only
                        Row(
                          children: [
                            Image.asset(
                              'assets/clock.png',
                              width: 28.w,
                              height: 28.h,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: timeText.contains('ago')
                                    ? const Color(0xFFFFC107)
                                    : widget.accentColor,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '·',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: widget.subtitleColor,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: widget.subtitleColor,
                              ),
                            ),
                          ],
                        ),

                        // Snooze chip — only when snoozed: "Rings at [time]"
                        if (isSnoozed && snoozedUntilFormatted != null) ...[
                          SizedBox(height: 10.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.snooze_rounded,
                                  size: 14.sp,
                                  color: widget.accentColor,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Snoozed until $snoozedUntilFormatted',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: widget.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        SizedBox(height: 32.h),

                        // Notes section
                        _buildNotesSection(),

                        SizedBox(height: 60.h),

                        // Action buttons (Done and Snooze)
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          back: CardBackSide(
            reminder: widget.reminder,
            accentColor: widget.accentColor,
            isDarkMode: widget.isDarkMode,
            cardColor: widget.cardColor,
            textColor: widget.textColor,
            onDeleted: () {
              // Pop back to home screen
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notes_outlined,
            size: 22.sp,
            color: widget.subtitleColor.withOpacity(0.6),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _notesController,
              focusNode: _notesFocusNode,
              cursorColor: widget.accentColor,
              cursorErrorColor: widget.accentColor,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w400,
                color: widget.textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Add notes',
                hintStyle: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w400,
                  color: widget.subtitleColor.withOpacity(0.6),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
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
              },
              child: Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: widget.accentColor,
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildSnoozeButton()),
        SizedBox(width: 8.w),
        Expanded(flex: 2, child: _buildSkipButton()),
        SizedBox(width: 8.w),
        Expanded(flex: 3, child: _buildDoneButton()),
      ],
    );
  }

  Widget _buildSnoozeButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () async {
            // Haptic feedback
            try {
              await HapticFeedback.mediumImpact();
            } catch (e) {
              // Haptic feedback not available on all platforms
            }
            _navigateToSnooze();
          },
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              height: 64.h,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(36.r),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.snooze_rounded,
                    color: widget.accentColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'SNOOZE',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkipButton() {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () async {
            // Haptic feedback
            try {
              await HapticFeedback.mediumImpact();
            } catch (e) {
              // Haptic feedback not available on all platforms
            }
            await _skipCurrentReminder();
          },
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              height: 64.h,
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(36.r),
                border: Border.all(
                  color: widget.subtitleColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.skip_next_rounded,
                    color: widget.subtitleColor,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'SKIP',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToSnooze() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SnoozeScreen(
          reminderId: widget.reminder.id,
          reminderTitle: widget.reminder.name,
        ),
      ),
    );
  }

  Future<void> _skipCurrentReminder() async {
    try {
      final occurrenceDate = widget.occurrenceTime ?? widget.reminder.effectiveNextDueAt;
      final dateKey = DateFormat('yyyy-MM-dd').format(occurrenceDate);

      // Get existing overrides or create new map
      final existingOverrides = widget.reminder.overrides ?? {};
      final newOverrides = Map<String, Map<String, dynamic>>.from(
        existingOverrides,
      );

      // Create or update override for this date with skipped flag
      newOverrides[dateKey] = {
        ...(newOverrides[dateKey] ?? {}),
        'skipped': true,
      };

      await _reminderService.updateReminder(widget.reminder.id, {
        'overrides': newOverrides,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reminder skipped',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: widget.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error skipping reminder: $e',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
