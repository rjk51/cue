import 'package:flutter/material.dart';
import '../../../services/revenue_cat_service.dart';
import 'cue_pro_paywall_screen.dart';

/// Helper widget to check Cue Pro access and show paywall if needed
class CueProGate extends StatelessWidget {
  final Widget child;
  final Widget? placeholder;
  final VoidCallback? onAccessDenied;

  const CueProGate({
    super.key,
    required this.child,
    this.placeholder,
    this.onAccessDenied,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RevenueCatService().hasCueProAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              const Center(child: CircularProgressIndicator());
        }

        final hasAccess = snapshot.data ?? false;

        if (hasAccess) {
          return child;
        } else {
          // Show upgrade prompt
          return placeholder ??
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 64,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cue Pro Feature',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upgrade to Cue Pro to unlock this feature',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          onAccessDenied?.call();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const CueProPaywallScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'Upgrade Now',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              );
        }
      },
    );
  }
}

/// Wrapper to conditionally show content based on Cue Pro access
class CueProFeature extends StatelessWidget {
  final Widget proChild;
  final Widget? freeChild;
  final bool showUpgradePrompt;

  const CueProFeature({
    super.key,
    required this.proChild,
    this.freeChild,
    this.showUpgradePrompt = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RevenueCatService().hasCueProAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final hasAccess = snapshot.data ?? false;

        if (hasAccess) {
          return proChild;
        } else {
          if (freeChild != null) {
            return freeChild!;
          }
          if (showUpgradePrompt) {
            return _buildUpgradeBanner(context);
          }
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildUpgradeBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Unlock all premium features',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CueProPaywallScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

/// Button to trigger paywall
class UpgradeButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final bool isCompact;

  const UpgradeButton({
    super.key,
    this.text,
    this.icon,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: RevenueCatService().hasCueProAccess(),
      builder: (context, snapshot) {
        final hasAccess = snapshot.data ?? false;

        if (hasAccess) {
          return const SizedBox.shrink();
        }

        if (isCompact) {
          return IconButton(
            icon: Icon(icon ?? Icons.star_outline),
            onPressed: () => _showPaywall(context),
            tooltip: 'Upgrade to Pro',
          );
        }

        return ElevatedButton.icon(
          onPressed: () => _showPaywall(context),
          icon: Icon(icon ?? Icons.star),
          label: Text(text ?? 'Upgrade to Pro'),
        );
      },
    );
  }

  void _showPaywall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CueProPaywallScreen(),
      ),
    );
  }
}

/// Mixin for checking Cue Pro access in StatefulWidgets
mixin CueProAccessMixin<T extends StatefulWidget> on State<T> {
  bool _hasCueProAccess = false;
  bool _isCheckingAccess = true;

  bool get hasCueProAccess => _hasCueProAccess;
  bool get isCheckingAccess => _isCheckingAccess;

  @override
  void initState() {
    super.initState();
    _checkCueProAccess();
  }

  Future<void> _checkCueProAccess() async {
    setState(() => _isCheckingAccess = true);
    final hasAccess = await RevenueCatService().hasCueProAccess();
    if (mounted) {
      setState(() {
        _hasCueProAccess = hasAccess;
        _isCheckingAccess = false;
      });
    }
  }

  Future<void> recheckCueProAccess() async {
    await _checkCueProAccess();
  }

  void showPaywall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CueProPaywallScreen(),
      ),
    ).then((_) => _checkCueProAccess());
  }
}
