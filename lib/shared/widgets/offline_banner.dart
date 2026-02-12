import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/connectivity_service.dart';

/// Wraps any screen and shows a connectivity banner at the bottom.
///
/// - **Offline**: grey banner with "You're offline" and a cloud-off icon.
/// - **Back online**: green banner with "Back online" that auto-hides after ~1 s.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({required this.child, super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _connectivity = ConnectivityService();

  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  bool _showBanner = false;
  bool _isOnline = true;
  StreamSubscription<bool>? _subscription;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // off-screen (below)
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _isOnline = _connectivity.isOnline.value;

    // If app starts offline, show the banner immediately
    if (!_isOnline) {
      _showBanner = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animController.forward();
      });
    }

    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(bool online) {
    if (!mounted) return;

    _hideTimer?.cancel();

    if (online && !_isOnline) {
      // Was offline → now back online
      setState(() {
        _isOnline = true;
        _showBanner = true;
      });
      _animController.forward();

      // Auto-hide after ~1 second
      _hideTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) setState(() => _showBanner = false);
          });
        }
      });
    } else if (!online && _isOnline) {
      // Was online → now offline
      setState(() {
        _isOnline = false;
        _showBanner = true;
      });
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBanner(),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    final isBack = _isOnline;
    final color = isBack ? const Color(0xFF4CAF50) : const Color(0xFF757575);
    final icon = isBack ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
    final text = isBack ? 'Back online' : "You're offline";

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
