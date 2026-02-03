import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/theme_service.dart';
import 'accent_color_screen.dart';

class ThemePreferenceScreen extends StatefulWidget {
  const ThemePreferenceScreen({super.key});

  @override
  State<ThemePreferenceScreen> createState() => _ThemePreferenceScreenState();
}

class _ThemePreferenceScreenState extends State<ThemePreferenceScreen> {
  final ThemeService _themeService = ThemeService();
  String _selectedTheme = 'light'; // Default to light
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  Future<void> _loadCurrentTheme() async {
    final theme = await _themeService.getThemePreference();
    setState(() {
      _selectedTheme = theme;
    });
  }

  Future<void> _handleNext() async {
    setState(() => _isLoading = true);

    try {
      // Save theme preference to both local and Firestore
      await _themeService.setThemePreference(_selectedTheme);

      if (mounted) {
        // Navigate to accent color screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => AccentColorScreen(themeMode: _selectedTheme),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preference: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C242A), Color(0xFF1C1922)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 24.h),
                // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(false),
                SizedBox(width: 8.w),
                _buildDot(true), // Active dot
                SizedBox(width: 8.w),
                _buildDot(false),
              ],
            ),
            SizedBox(height: 48.h),
            // Theme image
            Image.asset(
              'assets/theme_image.png',
              width: 180.w,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 32.h),
            // Title
            Text(
              'How should we look?',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            // Subtitle
            Text(
              'Customize your experience to\nmatch your environment.',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.white.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48.h),
            // Light option
            _buildThemeOption(
              theme: 'light',
              title: 'Light',
              subtitle: 'Sunrise warmth',
              isSelected: _selectedTheme == 'light',
              backgroundColor: Colors.white,
              borderColor: const Color(0xFFFFB4A3),
            ),
            SizedBox(height: 16.h),
            // Dark option
            _buildThemeOption(
              theme: 'dark',
              title: 'Dark',
              subtitle: 'Evening calm',
              isSelected: _selectedTheme == 'dark',
              backgroundColor: const Color(0xFF3D3A47),
              borderColor: const Color(0xFF3D3A47),
            ),
            SizedBox(height: 16.h),
            // System option
            _buildThemeOption(
              theme: 'system',
              title: 'System',
              subtitle: 'Automatic',
              isSelected: _selectedTheme == 'system',
              backgroundColor: Colors.white,
              borderColor: Colors.grey[300]!,
            ),
            const Spacer(),
            // Next button
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB4A3),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  disabledBackgroundColor: const Color(0xFFFFB4A3).withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: isActive ? 16.w : 8.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFB4A3) : const Color(0xFFE0E0E0),
        shape: isActive ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isActive ? BorderRadius.circular(12.r) : null,
      ),
    );
  }

  Widget _buildThemeOption({
    required String theme,
    required String title,
    required String subtitle,
    required bool isSelected,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    final isDark = theme == 'dark';
    final textColor = isDark ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8A8A8A);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTheme = theme;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB4A3) : borderColor,
            width: isSelected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            // Preview bars
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFFFFB4A3) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 32.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF8A8A8A) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF8A8A8A) : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
