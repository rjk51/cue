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
    if (_hasCompletedOnboarding == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF4A4458),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFB4A3)),
        ),
      );
    }

    if (_hasCompletedOnboarding!) {
      return const HomeScreen();
    } else {
      return ThemePreferenceScreen(
        onOnboardingComplete: () {
          // Re-check onboarding status — will now find theme+color set and show HomeScreen
          _checkOnboarding();
        },
      );
    }
  }
}
