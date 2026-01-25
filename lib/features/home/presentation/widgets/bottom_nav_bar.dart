import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BottomNavBar extends StatelessWidget {
  final Color accentColor;
  final bool isDarkMode;
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.accentColor,
    required this.isDarkMode,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(18.w, 0, 18.w, 24.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color.lerp(const Color.fromARGB(90, 46, 46, 46), accentColor, 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            isActive: currentIndex == 0,
            accentColor: accentColor,
            isDarkMode: isDarkMode,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.calendar_today_rounded,
            isActive: currentIndex == 1,
            accentColor: accentColor,
            isDarkMode: isDarkMode,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.settings_rounded,
            isActive: currentIndex == 2,
            accentColor: accentColor,
            isDarkMode: isDarkMode,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color accentColor;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.accentColor,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive
        ? accentColor
        : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 28.sp),
            SizedBox(height: 4.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 6.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: isActive ? accentColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
