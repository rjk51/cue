import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../home/presentation/home_screen.dart';

class DeviceSyncOnboardingScreen extends StatefulWidget {
  const DeviceSyncOnboardingScreen({super.key});

  @override
  State<DeviceSyncOnboardingScreen> createState() =>
      _DeviceSyncOnboardingScreenState();
}

class _DeviceSyncOnboardingScreenState
    extends State<DeviceSyncOnboardingScreen> {
  final ThemeService _themeService = ThemeService();
  Color _accentColor = const Color(0xFFFFB4A3);
  Color? _backgroundColor;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _accentColor = ThemeNotifier.instance.accentColor;
        _isDarkMode = ThemeNotifier.instance.isDarkMode;
      });
    }
  }

  Future<void> _loadTheme() async {
    final color = await _themeService.getAccentColor();
    final backgroundColor = await _themeService.getBackgroundColor();
    final theme = await _themeService.getThemePreference();
    if (mounted) {
      setState(() {
        _accentColor = color;
        _backgroundColor = backgroundColor;
        if (theme == 'dark') {
          _isDarkMode = true;
        } else if (theme == 'system') {
          _isDarkMode =
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark;
        } else {
          _isDarkMode = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Background color with accent tint (same as home screen)
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2A2A2A);
    final subtitleColor =
        _isDarkMode ? Colors.white70 : const Color(0xFF666666);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Phone illustrations
              SizedBox(
                height: 280.h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left phone (light/inactive)
                    Positioned(
                      left: 60.w,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Container(
                          width: 140.w,
                          height: 260.h,
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(32.r),
                            border: Border.all(
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: 20.h),
                              // Notch
                              Container(
                                width: 60.w,
                                height: 6.h,
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withOpacity(0.15)
                                      : Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(3.r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Right phone (active with checkmark)
                    Positioned(
                      right: 70.w,
                      child: Transform.rotate(
                        angle: 0.05,
                        child: Container(
                          width: 140.w,
                          height: 260.h,
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(32.r),
                            border: Border.all(
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.black.withOpacity(0.15),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: 20.h),
                              // Notch
                              Container(
                                width: 60.w,
                                height: 6.h,
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withOpacity(0.2)
                                      : Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3.r),
                                ),
                              ),
                              SizedBox(height: 32.h),
                              // Content placeholder (notification card)
                              Container(
                                margin: EdgeInsets.symmetric(horizontal: 16.w),
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? Colors.white.withOpacity(0.08)
                                      : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Column(
                                  children: [
                                    // Avatar circle
                                    Container(
                                      width: 32.w,
                                      height: 32.h,
                                      decoration: BoxDecoration(
                                        color: subtitleColor.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    // Text lines
                                    Container(
                                      height: 6.h,
                                      decoration: BoxDecoration(
                                        color: subtitleColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(3.r),
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Container(
                                      height: 6.h,
                                      width: 70.w,
                                      decoration: BoxDecoration(
                                        color: subtitleColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3.r),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Checkmark badge
                    Positioned(
                      right: 80.w,
                      bottom: 10.h,
                      child: Container(
                        width: 40.w,
                        height: 40.h,
                        decoration: BoxDecoration(
                          color: _accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 60.h),

              // Title
              Text(
                "You're synced.",
                style: TextStyle(
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 20.h),

              // Subtitle
              Text(
                'Your reminders and notifications are now live on this device. Actions on one will automatically clear on the other.',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Got it button
              SizedBox(
                width: double.infinity,
                height: 60.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
