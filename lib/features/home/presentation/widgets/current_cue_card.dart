import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../reminders/domain/reminder_model.dart';
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

  double _dragOffset = 0;
  bool _isSnoozeMode = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.isCurrentCue(widget.reminder.time);
    final timeText = widget.getTimeDisplayText(widget.reminder.time);
    final formattedTime = DateFormat('hh:mm a').format(widget.reminder.time);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    isCurrent ? 'CURRENT CUE' : 'NEXT CUE',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.accentColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              // Medicine icon (hardcoded for now)
              Container(
                width: 50.w,
                height: 50.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accentColor.withOpacity(0.15),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: widget.accentColor,
                  size: 30.sp,
                ),
              ),
            ],
          ),

          SizedBox(height: 42.h),

          // Reminder title
          Text(
            widget.reminder.name,
            style: TextStyle(
              fontSize: 42.sp,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
              height: 1.2,
            ),
          ),

          SizedBox(height: 12.h),

          // Time info
          Row(
            children: [
              Icon(
                Icons.access_time_filled,
                size: 20.sp,
                color: widget.subtitleColor,
              ),
              SizedBox(width: 6.w),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                  color: widget.accentColor,
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '·',
                style: TextStyle(fontSize: 18.sp, color: widget.subtitleColor),
              ),
              SizedBox(width: 8.w),
              Text(
                formattedTime,
                style: TextStyle(fontSize: 18.sp, color: widget.subtitleColor),
              ),
            ],
          ),

          SizedBox(height: 100.h),

          // Slider to mark done or snooze
          Padding(
            padding: EdgeInsets.only(left: 30.w, right: 30.w),
            child: _buildSlider(),
          ),

          SizedBox(height: 20.h),

          // Swipe hint text
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isSnoozeMode ? 'SWIPE TO SNOOZE' : 'SWIPE TO SNOOZE',
                key: ValueKey(_isSnoozeMode),
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: widget.subtitleColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final thumbSize = 48.h;
        final trackHeight = 64.h;
        final maxSlide = maxWidth - thumbSize - 8.w; // 8.w padding

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

              // Update snooze mode when dragged past 70%
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
              // Fully slid - navigate to snooze
              _navigateToSnooze();
            }
            // Reset slider
            setState(() {
              _dragOffset = 0;
              _isSnoozeMode = false;
            });
            _swipeController.reverse();
          },
          child: Container(
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isSnoozeMode ? 'Snooze' : 'Mark Done',
                        key: ValueKey(_isSnoozeMode),
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb
                AnimatedBuilder(
                  animation: _swipeController,
                  builder: (context, child) {
                    final animProgress = _swipeAnimation.value;
                    // Lighter base thumb color derived from accent color
                    final baseThumbColor = Color.lerp(
                      widget.accentColor,
                      Colors.white,
                      0.20,
                    )!;

                    return Positioned(
                      left: 8.w + _dragOffset,
                      top: 8.h,
                      child: GestureDetector(
                        onTap: () {
                          // Tap on thumb marks as done
                          widget.onMarkCompleted(widget.reminder.id);
                        },
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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: Icon(
                              _isSnoozeMode
                                  ? Icons.snooze_rounded
                                  : Icons.check_rounded,
                              key: ValueKey(_isSnoozeMode),
                              color: Colors.white,
                              size: 24.sp,
                            ),
                          ),
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
