import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum DeleteRecurringOption {
  thisOccurrenceOnly,
  wholeSeries,
}

/// Dialog to ask user how to delete a recurring reminder
class DeleteRecurringDialog extends StatelessWidget {
  final Color accentColor;
  final bool isDarkMode;
  final String reminderName;

  const DeleteRecurringDialog({
    super.key,
    required this.accentColor,
    required this.isDarkMode,
    required this.reminderName,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), accentColor, 0.1)!
        : Colors.white;

    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor = isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Delete Recurring Reminder',
              style: TextStyle(
                color: textColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              reminderName,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 14.sp,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 24.h),
            // Options
            _buildOption(
              context,
              icon: Icons.event_busy,
              title: 'Skip this occurrence',
              subtitle: 'Hide this occurrence only, keep the series',
              option: DeleteRecurringOption.thisOccurrenceOnly,
              textColor: textColor,
              subtitleColor: subtitleColor,
              accentColor: accentColor,
            ),
            SizedBox(height: 12.h),
            _buildOption(
              context,
              icon: Icons.delete_forever,
              title: 'Delete entire series',
              subtitle: 'Permanently delete all occurrences',
              option: DeleteRecurringOption.wholeSeries,
              textColor: textColor,
              subtitleColor: subtitleColor,
              accentColor: accentColor,
              isDestructive: true,
            ),
            SizedBox(height: 24.h),
            // Cancel button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: subtitleColor,
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
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

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required DeleteRecurringOption option,
    required Color textColor,
    required Color subtitleColor,
    required Color accentColor,
    bool isDestructive = false,
  }) {
    final borderColor = isDestructive
        ? Colors.red.withOpacity(0.5)
        : accentColor.withOpacity(0.3);
    final iconBgColor = isDestructive
        ? Colors.red.withOpacity(0.15)
        : accentColor.withOpacity(0.15);
    final iconColor = isDestructive ? Colors.red : accentColor;

    return InkWell(
      onTap: () => Navigator.pop(context, option),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          border: Border.all(
            color: borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : textColor,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: subtitleColor,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  /// Static method to show the dialog
  static Future<DeleteRecurringOption?> show({
    required BuildContext context,
    required String reminderName,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return showDialog<DeleteRecurringOption>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => DeleteRecurringDialog(
        reminderName: reminderName,
        accentColor: accentColor,
        isDarkMode: isDarkMode,
      ),
    );
  }
}
