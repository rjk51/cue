import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../services/theme_service.dart';
import '../../../services/auth_service.dart';
import '../../auth/presentation/welcome_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';
import '../../subscription/presentation/cue_pro_paywall_screen.dart';
import 'appearance_screen.dart';
import 'devices_screen.dart';
import 'sync_devices_screen.dart';
// import 'notification_settings_screen.dart'; // Used when Notifications card is enabled

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final AuthService _authService = AuthService();

  Color _accentColor = const Color(0xFF2D7A78);
  bool _isDarkMode = false;
  String _themeMode = 'light';
  String _userName = 'User';
  String _userEmail = 'user@cue.app';
  String _version = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _loadUserInfo();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      // If package info fails to load, keep default values
      print('Error loading version info: $e');
    }
  }

  Future<void> _loadThemeSettings() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();

    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _themeMode = themePreference;
        if (themePreference == 'system') {
          _isDarkMode =
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
        } else {
          _isDarkMode = themePreference == 'dark';
        }
      });
    }
  }

  String _getThemeDisplayText() {
    switch (_themeMode) {
      case 'dark':
        return 'Dark';
      case 'system':
        return 'System';
      case 'light':
      default:
        return 'Light';
    }
  }

  void _loadUserInfo() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'User';
        _userEmail = user.email ?? 'user@cue.app';
      });
    }
  }

  Future<void> _handleLogOut() async {
    final shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Log Out',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogOut == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Delete Account',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : const Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        // Show loading indicator
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: EdgeInsets.all(24.r),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _accentColor),
                    SizedBox(height: 16.h),
                    Text(
                      'Deleting account...',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Delete user data from Firestore and Firebase Auth
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userId = user.uid;
          
          // Delete user's reminders first
          final remindersSnapshot = await FirebaseFirestore.instance
              .collection('reminders')
              .where('userId', isEqualTo: userId)
              .get();
          
          for (var doc in remindersSnapshot.docs) {
            await doc.reference.delete();
          }
          
          // Delete user's devices
          final devicesSnapshot = await FirebaseFirestore.instance
              .collection('devices')
              .where('userId', isEqualTo: userId)
              .get();
          
          for (var doc in devicesSnapshot.docs) {
            await doc.reference.delete();
          }
          
          // Delete user's pending notifications
          final pendingNotificationsSnapshot = await FirebaseFirestore.instance
              .collection('pending_notifications')
              .where('userId', isEqualTo: userId)
              .get();
          
          for (var doc in pendingNotificationsSnapshot.docs) {
            await doc.reference.delete();
          }
          
          // Delete user document from Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .delete();
          
          // Delete the Firebase Auth user - THIS MUST BE LAST
          await user.delete();
          
          // Sign out to clear any cached credentials
          await FirebaseAuth.instance.signOut();
        }

        if (mounted) {
          // Close loading dialog
          Navigator.pop(context);
          
          // Navigate to welcome screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const WelcomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          // Close loading dialog if it's open
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().contains('requires-recent-login')
                    ? 'Please log out and log back in before deleting your account'
                    : 'Error deleting account: $e',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!;

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor = _isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 32.w, 24.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      color: textColor,
                      size: 24.sp,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OnboardingScreen(),
                          ),
                        );
                      },
                      child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              _isDarkMode ? 0.3 : 0.08,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar placeholder
                          Container(
                          width: 56.w,
                          height: 56.h,
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _userName.isNotEmpty
                                  ? _userName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w600,
                                color: _accentColor,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accentColor,
                                      borderRadius: BorderRadius.circular(
                                        4.r,
                                      ),
                                    ),
                                    child: Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _userEmail,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: subtitleColor,
                          size: 24.sp,
                        ),
                        ],
                      ),
                    ),
                    ),

                    SizedBox(height: 32.h),

                    // PREFERENCES Section
                    Text(
                      'PREFERENCES',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: 16.h),

                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              _isDarkMode ? 0.3 : 0.08,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Notifications row (commented out)
                          // GestureDetector(
                          //   onTap: () {
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder: (context) =>
                          //             const NotificationSettingsScreen(),
                          //       ),
                          //     );
                          //   },
                          //   child: Padding(
                          //     padding: EdgeInsets.symmetric(
                          //       horizontal: 20.w,
                          //       vertical: 16.h,
                          //     ),
                          //     child: Row(
                          //       children: [
                          //         Container(
                          //           width: 40.w,
                          //           height: 40.h,
                          //           decoration: BoxDecoration(
                          //             color: Colors.orange.withOpacity(0.15),
                          //             shape: BoxShape.circle,
                          //           ),
                          //           child: Icon(
                          //             Icons.notifications_outlined,
                          //             color: Colors.orange,
                          //             size: 22.sp,
                          //           ),
                          //         ),
                          //         SizedBox(width: 16.w),
                          //         Expanded(
                          //           child: Text(
                          //             'Notifications',
                          //             style: TextStyle(
                          //               fontSize: 16.sp,
                          //               fontWeight: FontWeight.w500,
                          //               color: textColor,
                          //             ),
                          //           ),
                          //         ),
                          //         Icon(
                          //           Icons.chevron_right,
                          //           color: subtitleColor,
                          //           size: 20.sp,
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          // Divider(
                          //   height: 1,
                          //   thickness: 1,
                          //   color: subtitleColor.withOpacity(0.08),
                          // ),

                          // Appearance row
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AppearanceScreen(),
                                ),
                              );
                              // Reload settings when returning from appearance screen
                              _loadThemeSettings();
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 16.h,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.palette_outlined,
                                      color: Colors.purple,
                                      size: 22.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Text(
                                      'Appearance',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _getThemeDisplayText(),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: subtitleColor,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(
                                    Icons.chevron_right,
                                    color: subtitleColor,
                                    size: 20.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: subtitleColor.withOpacity(0.08),
                          ),

                          // Cue Pro / Billing row
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CueProPaywallScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 16.h,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star_rounded,
                                      color: _accentColor,
                                      size: 22.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Text(
                                      'Cue Pro',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: subtitleColor,
                                    size: 20.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // DATA & SYNC Section
                    Text(
                      'DATA & SYNC',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: 16.h),

                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              _isDarkMode ? 0.3 : 0.08,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Sync & Devices
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SyncDevicesScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 16.h,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.sync,
                                      color: Colors.blue,
                                      size: 22.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Text(
                                      'Sync & Devices',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: subtitleColor,
                                    size: 20.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: subtitleColor.withOpacity(0.08),
                          ),

                          // Privacy & Data
                          GestureDetector(
                            onTap: () async {
                              const url = 'https://cue-landing-amber.vercel.app/#privacy'; // Replace with your actual privacy policy URL
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                // Handle error, maybe show a snackbar
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open privacy policy'),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 16.h,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40.w,
                                    height: 40.h,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green.withOpacity(0.15),
                                    ),
                                    child: Icon(
                                      Icons.shield_outlined,
                                      color: Colors.green,
                                      size: 22.sp,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Text(
                                      'Privacy & Data',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: subtitleColor,
                                    size: 20.sp,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 48.h),

                    // Version info
                    Center(
                      child: Text(
                        'Cue v$_version (build $_buildNumber)',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: subtitleColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Log Out button
                    Center(
                      child: TextButton(
                        onPressed: _handleLogOut,
                        child: Text(
                          'Log Out',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(255, 232, 96, 86),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 8.h),

                    // Delete Account button
                    Center(
                      child: TextButton(
                        onPressed: _handleDeleteAccount,
                        child: Text(
                          'Delete Account',
                           style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color.fromARGB(255, 232, 96, 86),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 50.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
