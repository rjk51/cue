import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'theme_preference_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 20, 57),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 24.h),
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(true), // Active dot for first screen
                SizedBox(width: 8.w),
                _buildDot(false),
                SizedBox(width: 8.w),
                _buildDot(false),
              ],
            ),
            const Spacer(flex: 2),

            // Illustration image - full width
            Image.asset(
              'assets/onboarding_image.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),

            const Spacer(flex: 2),

            // Text content and button with padding
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                children: [
                  // Main heading
                  Text(
                    'Your calm, capable sidekick.',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 20.h),

                  // Description text
                  Text(
                    'Master your day with smart reminders, powerful recurring tasks, and seamless sync. Stay calmly focused and never miss a beat.',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 48.h),

                  // Get Started button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 60.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ThemePreferenceScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 238, 147, 127),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: isActive ? 16.w : 8.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFB4A3) : Colors.white.withOpacity(0.3),
        shape: isActive ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isActive ? BorderRadius.circular(12.r) : null,
      ),
    );
  }
}
