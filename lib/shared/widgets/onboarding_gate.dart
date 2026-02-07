import 'package:flutter/material.dart';
import '../../../services/theme_service.dart';
import '../../../features/home/presentation/home_screen.dart';
import '../../../features/onboarding/presentation/theme_preference_screen.dart';

/// Widget that checks if user has completed onboarding
/// and routes them to the appropriate screen.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key});

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final completed = await ThemeService().hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use cached value to avoid flashing
    final hasCompleted = _hasCompletedOnboarding ?? true; // Default to true to show home immediately

    if (hasCompleted) {
      // User has completed onboarding, go to home
      return const HomeScreen();
    } else {
      // New user, show theme preference screen
      return const ThemePreferenceScreen();
    }
  }
}
