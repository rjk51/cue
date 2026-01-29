import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum EditRecurringOption {
  thisOccurrenceOnly,
  thisAndFuture,
}

/// Dialog to ask user how to apply edits to a recurring reminder
class EditRecurringDialog extends StatelessWidget {
  final Color accentColor;
  final bool isDarkMode;
  final String reminderName;

  const EditRecurringDialog({
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
              'Edit Recurring Reminder',
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
              icon: Icons.event,
              title: 'This reminder only',
              subtitle: 'Changes apply only to this occurrence',
              option: EditRecurringOption.thisOccurrenceOnly,
              textColor: textColor,
              subtitleColor: subtitleColor,
              accentColor: accentColor,
            ),
            SizedBox(height: 12.h),
            _buildOption(
              context,
              icon: Icons.event_repeat,
              title: 'This and future reminders',
              subtitle: 'Changes apply to all future occurrences',
              option: EditRecurringOption.thisAndFuture,
              textColor: textColor,
              subtitleColor: subtitleColor,
              accentColor: accentColor,
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
    required EditRecurringOption option,
    required Color textColor,
    required Color subtitleColor,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, option),
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: accentColor,
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
                      color: textColor,
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
  static Future<EditRecurringOption?> show({
    required BuildContext context,
    required String reminderName,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return showDialog<EditRecurringOption>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => EditRecurringDialog(
        reminderName: reminderName,
        accentColor: accentColor,
        isDarkMode: isDarkMode,
      ),
    );
  }
}
