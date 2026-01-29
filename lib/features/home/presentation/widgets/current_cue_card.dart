import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../reminders/domain/reminder_model.dart';
import '../../../reminders/data/reminder_service.dart';
import '../../../reminders/presentation/reminder_details_screen.dart';
import '../../../snooze/presentation/snooze_screen.dart';

class CurrentCueCard extends StatefulWidget {
  final Reminder reminder;
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
    with SingleTickerProviderStateMixin {
  late AnimationController _swipeController;
  late Animation<double> _swipeAnimation;
  late TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();
  final ReminderService _reminderService = ReminderService();

  double _dragOffset = 0;
  bool _isSnoozeMode = false;
  bool _isSnoozeExpanded = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _notesController = TextEditingController(text: widget.reminder.notes ?? '');

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
      // Reset snooze slider state when reminder changes
      _dragOffset = 0;
      _isSnoozeMode = false;
      _isSnoozeExpanded = false;
      _swipeController.reset();
    }
  }

  void _initAnimations() {
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _swipeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
    );

    _swipeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
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
        print('Error saving notes: $e');
      }
    }
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
    ).then((_) {
      // Reset snooze slider state when returning from snooze screen
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _isSnoozeMode = false;
          _isSnoozeExpanded = false;
        });
        _swipeController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeText = widget.getTimeDisplayText(widget.reminder.time);
    final formattedTime = DateFormat('hh:mm a').format(widget.reminder.time);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReminderDetailsScreen(
              reminder: widget.reminder,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(42.r),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with label and icon
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Dynamic icon from reminder
                Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.reminder.color.withOpacity(0.15),
                  ),
                  child: Icon(
                    widget.reminder.icon,
                    color: widget.reminder.color,
                    size: 30.sp,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Reminder title
            Text(
              widget.reminder.name,
              style: TextStyle(
                fontSize: 46.sp,
                fontWeight: FontWeight.w700,
                color: widget.textColor,
                height: 1.2,
              ),
            ),

            SizedBox(height: 12.h),

            // Time info (below title)
            Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 18.sp,
                  color: widget.subtitleColor,
                ),
                SizedBox(width: 6.w),
                Text(
                  timeText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: widget.accentColor,
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

            SizedBox(height: 32.h),

            // Notes section
            _buildNotesSection(),

            SizedBox(height: 60.h),

            // Action buttons (Done and Snooze)
            _buildActionButtons(),
          ],
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
        // Snooze button or slider
        Expanded(
          flex: _isSnoozeExpanded ? 4 : 2,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  child: child,
                ),
              );
            },
            child: _isSnoozeExpanded
                ? _buildSnoozeSlider()
                : _buildSnoozeButton(),
          ),
        ),
        SizedBox(width: 12.w),
        // Done button (always visible)
        Expanded(
          flex: _isSnoozeExpanded ? 2 : 3,
          child: _buildDoneButton(),
        ),
      ],
    );
  }

  Widget _buildSnoozeButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isSnoozeExpanded = true;
        });
      },
      child: Container(
        key: const ValueKey('snooze_button'),
        height: 64.h,
        decoration: BoxDecoration(
          color: widget.isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(36.r),
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
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: widget.accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoneButton() {
    return GestureDetector(
      onTap: () {
        widget.onMarkCompleted(widget.reminder.id);
      },
      child: Container(
        height: 64.h,
        decoration: BoxDecoration(
          color: widget.accentColor,
          borderRadius: BorderRadius.circular(36.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
            if (!_isSnoozeExpanded) ...[
              SizedBox(width: 8.w),
              Text(
                'DONE',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSnoozeSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final thumbSize = 48.h;
        final trackHeight = 64.h;
        final maxSlide = maxWidth - thumbSize - 8.w;

        return GestureDetector(
          onHorizontalDragStart: (_) {
            setState(() {
              _dragOffset = 0;
            });
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.delta.dx;
              _dragOffset = _dragOffset.clamp(0, maxSlide);

              final progress = _dragOffset / maxSlide;
              if (progress > 0.2) {
                if (!_isSnoozeMode) {
                  _isSnoozeMode = true;
                  _swipeController.forward();
                }
              } else {
                if (_isSnoozeMode) {
                  _isSnoozeMode = false;
                  _swipeController.reverse();
                }
              }
            });
          },
          onHorizontalDragEnd: (_) {
            final progress = _dragOffset / maxSlide;
            if (progress > 0.85) {
              _navigateToSnooze();
            } else {
              // If not completed, collapse back to two buttons
              setState(() {
                _dragOffset = 0;
                _isSnoozeMode = false;
                _isSnoozeExpanded = false;
              });
              _swipeController.reverse();
            }
          },
          child: Container(
            key: const ValueKey('snooze_slider'),
            width: double.infinity,
            height: trackHeight,
            decoration: BoxDecoration(
              color: widget.accentColor,
              borderRadius: BorderRadius.circular(36.r),
            ),
            child: Stack(
              children: [
                // Background text
                Positioned.fill(
                  child: Center(
                    child: Text(
                      'Snooze',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Thumb
                AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    final animProgress = _swipeAnimation.value;
                    final baseThumbColor = Color.lerp(
                      widget.accentColor,
                      Colors.white,
                      0.20,
                    )!;

                    return Positioned(
                      left: 8.w + _dragOffset,
                      top: 8.h,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            baseThumbColor,
                            Colors.orange,
                            animProgress,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color.lerp(
                                baseThumbColor,
                                Colors.orange,
                                animProgress,
                              )!.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.snooze_rounded,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
