import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/pulse_models.dart';

/// Displays unlocked and locked achievements in a grid.
class AchievementsSection extends StatelessWidget {
  final List<Achievement> achievements;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const AchievementsSection({
    super.key,
    required this.achievements,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a.isUnlocked).toList();
    final locked = achievements.where((a) => !a.isUnlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: accentColor,
              size: 18.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              'ACHIEVEMENTS',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: subtitleColor,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              '${unlocked.length}/${achievements.length}',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        SizedBox(height: 14.h),

        // Unlocked achievements
        if (unlocked.isNotEmpty) ...[
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: unlocked
                .map((a) => _AchievementBadge(
                      achievement: a,
                      accentColor: accentColor,
                      isDarkMode: isDarkMode,
                      cardColor: cardColor,
                      textColor: textColor,
                    ))
                .toList(),
          ),
          SizedBox(height: 16.h),
        ],

        // Locked achievements (dimmed)
        if (locked.isNotEmpty) ...[
          Text(
            'Locked',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: subtitleColor.withOpacity(0.7),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: locked
                .map((a) => _AchievementBadge(
                      achievement: a,
                      accentColor: accentColor,
                      isDarkMode: isDarkMode,
                      cardColor: cardColor,
                      textColor: textColor,
                      isLocked: true,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final Achievement achievement;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final bool isLocked;

  const _AchievementBadge({
    required this.achievement,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${achievement.title}\n${achievement.description}',
      child: AnimatedOpacity(
        opacity: isLocked ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          width: 90.w,
          height: 90.h,
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: isLocked
                ? (isDarkMode
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03))
                : accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16.r),
            border: isLocked
                ? Border.all(
                    color: (isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06)),
                    width: 1,
                  )
                : Border.all(
                    color: accentColor.withOpacity(0.2),
                    width: 1.5,
                  ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLocked ? Icons.lock_rounded : Icons.emoji_events_rounded,
                  size: 26.sp,
                  color: isLocked
                      ? textColor.withOpacity(0.3)
                      : accentColor,
                ),
                SizedBox(height: 4.h),
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w600,
                    color: isLocked
                        ? textColor.withOpacity(0.4)
                        : textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
