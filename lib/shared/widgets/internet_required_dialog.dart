import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shows a dialog explaining that internet is required for a specific feature.
///
/// Returns `true` if the user tapped "OK", `false` if dismissed.
Future<bool> showInternetRequiredDialog(
  BuildContext context, {
  required String featureName,
  required Color accentColor,
  required bool isDarkMode,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: accentColor, size: 24.sp),
          SizedBox(width: 8.w),
          Flexible(
            child: Text(
              'Internet Required',
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '$featureName requires an internet connection. Please check your connection and try again.',
        style: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
          fontSize: 14.sp,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'OK',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
