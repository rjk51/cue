import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../services/theme_service.dart';

class SyncDevicesScreen extends StatefulWidget {
  const SyncDevicesScreen({super.key});

  @override
  State<SyncDevicesScreen> createState() => _SyncDevicesScreenState();
}

class _SyncDevicesScreenState extends State<SyncDevicesScreen> {
  final ThemeService _themeService = ThemeService();
  Color _accentColor = const Color(0xFF2D7A78);
  Color? _backgroundColor;
  bool _isDarkMode = false;
  String _currentDeviceId = '';

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _getCurrentDeviceId();
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

  Future<void> _getCurrentDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? '';
      } else {
        return;
      }

      if (mounted) {
        setState(() {
          _currentDeviceId = deviceId;
        });
      }
    } catch (e) {
      print('Error getting device ID: $e');
    }
  }

  Future<void> _removeDevice(String deviceId, String deviceName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Remove Device',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "$deviceName"? This will sign out that device.',
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
              'Remove',
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
        await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing device: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.apple;
      default:
        return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

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
                    'Sync & Devices',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: userId == null
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: _accentColor,
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading devices',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16.sp,
                              ),
                            ),
                          );
                        }

                        final devices = snapshot.data?.docs ?? [];

                        if (devices.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.devices_other,
                                  size: 64.sp,
                                  color: subtitleColor,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'No devices found',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          itemCount: devices.length,
                          itemBuilder: (context, index) {
                            final deviceDoc = devices[index];
                            final deviceData =
                                deviceDoc.data() as Map<String, dynamic>;
                            final deviceId = deviceDoc.id;
                            final deviceName =
                                deviceData['deviceName'] ?? 'Unknown Device';
                            final platform =
                                deviceData['platform'] ?? 'unknown';
                            final lastUpdated = deviceData['lastUpdated']
                                as Timestamp?;
                            final isCurrentDevice =
                                deviceId == _currentDeviceId;

                            return Container(
                              margin: EdgeInsets.only(bottom: 16.h),
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
                              child: Padding(
                                padding: EdgeInsets.all(20.r),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48.w,
                                      height: 48.h,
                                      decoration: BoxDecoration(
                                        color: _accentColor.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _getPlatformIcon(platform),
                                        color: _accentColor,
                                        size: 24.sp,
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  deviceName,
                                                  style: TextStyle(
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: textColor,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                    'THIS DEVICE',
                                                    style: TextStyle(
                                                      fontSize: 9.sp,
                                                      fontWeight:
                                                          FontWeight.w700,
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
                                            platform.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: subtitleColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (lastUpdated != null) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              'Last active: ${_formatTimestamp(lastUpdated)}',
                                              style: TextStyle(
                                                fontSize: 11.sp,
                                                color: subtitleColor
                                                    .withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!isCurrentDevice)
                                      IconButton(
                                        onPressed: () => _removeDevice(
                                          deviceId,
                                          deviceName,
                                        ),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.withOpacity(0.7),
                                          size: 22.sp,
                                        ),
                                      ),
                                  ],
                                ),
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

  String _formatTimestamp(Timestamp timestamp) {
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
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
