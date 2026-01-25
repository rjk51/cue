import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/onboarding/presentation/theme_preference_screen.dart';

/// Widget that checks if user has completed onboarding
/// and routes them to the appropriate screen.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ThemeService().hasCompletedOnboarding(),
      builder: (context, snapshot) {
        // Show loading while checking
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF4A4458),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB4A3)),
            ),
          );
        }

        // Check if onboarding is complete
        final hasCompletedOnboarding = snapshot.data ?? false;

        if (hasCompletedOnboarding) {
          // User has completed onboarding, go to home
          return const HomeScreen();
        } else {
          // New user, show theme preference screen
          return const ThemePreferenceScreen();
        }
      },
    );
  }
}
