import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/pulse_models.dart';

/// Displays current streak with a flame animation and best streak.
class StreakCard extends StatelessWidget {
  final StreakData streaks;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const StreakCard({
    super.key,
    required this.streaks,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Streak flame + count
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Animated flame
                    _AnimatedFlame(
                      isActive: streaks.currentStreak > 0,
                      accentColor: accentColor,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${streaks.currentStreak}',
                      style: TextStyle(
                        fontSize: 48.sp,
                        fontWeight: FontWeight.w800,
                        color: streaks.currentStreak > 0
                            ? accentColor
                            : subtitleColor,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  streaks.currentStreak == 1
                      ? 'day streak'
                      : 'day streak',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
                if (streaks.isActiveToday) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '✓ Active today',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 80.h,
            color: subtitleColor.withOpacity(0.15),
          ),
          // Best streak
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  '👑',
                  style: TextStyle(fontSize: 28.sp),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${streaks.bestStreak}',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  'best streak',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated flame icon that pulses when streak is active.
class _AnimatedFlame extends StatefulWidget {
  final bool isActive;
  final Color accentColor;

  const _AnimatedFlame({
    required this.isActive,
    required this.accentColor,
  });

  @override
  State<_AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<_AnimatedFlame>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isActive ? _scaleAnimation.value : 1.0,
          child: Text(
            widget.isActive ? '🔥' : '❄️',
            style: TextStyle(fontSize: 36.sp),
          ),
        );
      },
    );
  }
}
