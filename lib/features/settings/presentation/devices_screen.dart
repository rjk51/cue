import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../notifications/notification_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
// Screen to manage and view devices linked to the user's account

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final ThemeService _themeService = ThemeService();
  final NotificationService _notificationService = NotificationService();
  
  // Initialize from ThemeNotifier immediately to prevent white flash
  late Color _accentColor;
  late Color? _backgroundColor;
  late bool _isDarkMode;
  String? _currentDeviceToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Get theme values synchronously from ThemeNotifier
    _accentColor = ThemeNotifier.instance.accentColor;
    _backgroundColor = ThemeNotifier.instance.backgroundColor;
    _isDarkMode = ThemeNotifier.instance.isDarkMode;
    _loadThemeSettings();
    _loadCurrentDeviceToken();
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

  Future<void> _loadThemeSettings() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();
    final backgroundColor = await _themeService.getBackgroundColor();
    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _backgroundColor = backgroundColor;
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

  Future<void> _loadCurrentDeviceToken() async {
    final token = _notificationService.fcmToken;
    if (mounted) {
      setState(() {
        _currentDeviceToken = token;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeDevice(String deviceId, String fcmToken, bool isCurrentDevice) async {
    await ConfirmationDialog.show(
      context: context,
      title: isCurrentDevice ? 'Logout from This Device' : 'Remove Device',
      message: isCurrentDevice
          ? 'Are you sure you want to logout from this device? You will need to sign in again.'
          : 'Are you sure you want to remove this device? The device will no longer receive notifications.',
      confirmText: isCurrentDevice ? 'Logout' : 'Remove',
      cancelText: 'Cancel',
      accentColor: _accentColor,
      isDarkMode: _isDarkMode,
      isDestructive: true,
      onConfirm: () async {
        try {
          // Set device as inactive
          await FirebaseFirestore.instance
              .collection('devices')
              .doc(deviceId)
              .update({
            'active': false,
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            context.showSuccessSnackbar(
              isCurrentDevice
                  ? 'Logged out from this device'
                  : 'Device removed successfully',
            );

            // If removing current device, sign out
            if (isCurrentDevice) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          }
        } catch (e) {
          if (mounted) {
            context.showErrorSnackbar('Error removing device: $e');
          }
        }
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.apple;
      case 'web':
        return Icons.web;
      default:
        return Icons.devices;
    }
  }

  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      case 'web':
        return 'Web';
      default:
        return 'Unknown';
    }
  }

  String _formatLastUpdated(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final tnText = ThemeNotifier.instance.textColor;
    final textColor = tnText ?? (_isDarkMode ? Colors.white : const Color(0xFF2D2D2D));
    final subtitleColor = tnText != null ? tnText.withOpacity(0.7) : (_isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A));

    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                    'Devices',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Info text
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
                'Manage devices that are signed in to your account',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // Devices list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _accentColor,
                      ),
                    )
                  : userId == null
                      ? Center(
                          child: Text(
                            'Please sign in to view devices',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 16.sp,
                            ),
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('devices')
                              .where('userId', isEqualTo: userId)
                              .where('active', isEqualTo: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Error loading devices',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      '${snapshot.error}',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 12.sp,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _accentColor,
                                ),
                              );
                            }

                            final devices = snapshot.data?.docs ?? [];
                            
                            // Sort in memory by lastUpdated (most recent first)
                            devices.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aTime = aData['lastUpdated'] as Timestamp?;
                              final bTime = bData['lastUpdated'] as Timestamp?;
                              
                              if (aTime == null && bTime == null) return 0;
                              if (aTime == null) return 1;
                              if (bTime == null) return -1;
                              
                              return bTime.compareTo(aTime);
                            });

                            if (devices.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.devices_other,
                                      size: 64.sp,
                                      color: subtitleColor.withOpacity(0.5),
                                    ),
                                    SizedBox(height: 16.h),
                                    Text(
                                      'No active devices',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: 24.w),
                              itemCount: devices.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                final data = device.data() as Map<String, dynamic>;
                                final fcmToken = data['fcmToken'] as String?;
                                final platform = data['platform'] as String? ?? 'unknown';
                                final deviceName = data['deviceName'] as String?;
                                final lastUpdated = data['lastUpdated'] as Timestamp?;
                                final isCurrentDevice = fcmToken == _currentDeviceToken;

                                return Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: isCurrentDevice
                                        ? Border.all(
                                            color: _accentColor,
                                            width: 2,
                                          )
                                        : null,
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
                                      // Platform icon
                                      Container(
                                        width: 48.w,
                                        height: 48.h,
                                        decoration: BoxDecoration(
                                          color: isCurrentDevice
                                              ? _accentColor.withOpacity(0.15)
                                              : subtitleColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getPlatformIcon(platform),
                                          color: isCurrentDevice
                                              ? _accentColor
                                              : subtitleColor,
                                          size: 24.sp,
                                        ),
                                      ),
                                      SizedBox(width: 16.w),

                                      // Device info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    deviceName ?? _getPlatformName(platform),
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      fontWeight: FontWeight.w600,
                                                      color: textColor,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isCurrentDevice) ...[
                                                  SizedBox(width: 8.w),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 8.w,
                                                      vertical: 2.h,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: _accentColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4.r),
                                                    ),
                                                    child: Text(
                                                      'Current',
                                                      style: TextStyle(
                                                        fontSize: 10.sp,
                                                        fontWeight: FontWeight.w700,
                                                        color: Colors.white,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              deviceName != null
                                                  ? '${_getPlatformName(platform)} • ${lastUpdated != null ? 'Last active ${_formatLastUpdated(lastUpdated)}' : 'Last active: Unknown'}'
                                                  : lastUpdated != null
                                                      ? 'Last active ${_formatLastUpdated(lastUpdated)}'
                                                      : 'Last active: Unknown',
                                              style: TextStyle(
                                                fontSize: 13.sp,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Remove button
                                      IconButton(
                                        onPressed: () => _removeDevice(
                                          device.id,
                                          fcmToken ?? '',
                                          isCurrentDevice,
                                        ),
                                        icon: Icon(
                                          Icons.logout,
                                          color: Colors.red.withOpacity(0.7),
                                          size: 20.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
