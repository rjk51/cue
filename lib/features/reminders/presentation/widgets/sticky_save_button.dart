import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StickySaveButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onCancel;
  final bool isLoading;
  final Color accentColor;
  final bool isDarkMode;
  final bool showCancel;

  const StickySaveButton({
    super.key,
    required this.onPressed,
    this.onCancel,
    required this.isLoading,
    required this.accentColor,
    required this.isDarkMode,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    // Get safe area insets to avoid system navigation buttons
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final viewInsets = mediaQuery.viewInsets;
    final keyboardHeight = viewInsets.bottom;

    return Container(
      // Add padding for safe area and keyboard
      padding: EdgeInsets.only(
        bottom: bottomPadding + (keyboardHeight > 0 ? 0 : 16.h),
        top: 16.h,
        left: 20.w,
        right: 20.w,
      ),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color.lerp(const Color(0xFF121212), accentColor, 0.08)!
            : Color.lerp(const Color(0xFFFAF5F3), accentColor, 0.05)!,
        boxShadow: keyboardHeight == 0
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56.h,
          child: showCancel
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isLoading ? null : onCancel,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(color: accentColor.withOpacity(0.6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          disabledBackgroundColor: accentColor.withOpacity(0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: accentColor.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
        ),
      ),
    );
  }
}
