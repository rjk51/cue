import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../../services/theme_service.dart';
import '../../../services/local_storage_service.dart';
import '../../home/presentation/home_screen.dart';

class AccentColorScreen extends StatefulWidget {
  final String themeMode;

  const AccentColorScreen({super.key, required this.themeMode});

  @override
  State<AccentColorScreen> createState() => _AccentColorScreenState();
}

class _AccentColorScreenState extends State<AccentColorScreen> {
  final ThemeService _themeService = ThemeService();
  final _storage = LocalStorageService.instance;
  Color _selectedColor = const Color(0xFFFFB4A3); // Default coral color
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    final color = await _themeService.getAccentColor();
    setState(() {
      _selectedColor = color;
    });
  }

  bool get _isDarkMode {
    if (widget.themeMode == 'dark') return true;
    if (widget.themeMode == 'system') {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return false;
  }

  Future<void> _showColorPicker() async {
    Color pickedColor = _selectedColor;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick your glow'),
          content: SingleChildScrollView(
            child: ColorPicker(
              color: pickedColor,
              onColorChanged: (Color color) {
                pickedColor = color;
              },
              width: 40,
              height: 40,
              borderRadius: 20,
              heading: Text(
                'Select color',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subheading: Text(
                'Select color shade',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              wheelDiameter: 200,
              enableShadesSelection: true,
              pickersEnabled: const {ColorPickerType.wheel: true},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedColor = pickedColor;
                });
                Navigator.pop(context);
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleNext() async {
    setState(() => _isLoading = true);

    try {
      // Save accent color preference
      await _themeService.setAccentColor(_selectedColor);

      // Mark device sync onboarding as shown (first device doesn't need sync screen)
      await _storage.set('device_sync_onboarding_shown', true);

      if (mounted) {
        // Navigate to home screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preference: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _isDarkMode
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C242A), Color(0xFF1C1922)],
                ),
              )
            : const BoxDecoration(color: Color(0xFFF5F5F5)),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              children: [
                SizedBox(height: 24.h),
                // Progress dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(false),
                    SizedBox(width: 8.w),
                    _buildDot(false),
                    SizedBox(width: 8.w),
                    _buildDot(true), // Active dot (3rd step)
                  ],
                ),
                SizedBox(height: 48.h),
                // Title
                Text(
                  'Pick your glow.',
                  style: TextStyle(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w700,
                    color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                // Subtitle
                Text(
                  'Fine-tune your accent color for\na look that feels right to you.',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.6)
                        : const Color(0xFF8A8A8A),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48.h),
                // Color picker circle
                GestureDetector(
                  onTap: _showColorPicker,
                  child: Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      color: _selectedColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _selectedColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 48.h),
                // Home Screen Preview
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? Color.lerp(
                              const Color(0xFF121212),
                              _selectedColor,
                              0.08,
                            )!
                          : Color.lerp(
                              const Color(0xFFFAF5F3),
                              _selectedColor,
                              0.05,
                            )!,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Date header
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          child: Text(
                            'FRIDAY, JAN 25',
                            style: TextStyle(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.6)
                                  : const Color(0xFF8A8A8A),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                  
                        SizedBox(height: 16.h),
                  
                        // Reminders Today Count
                        Text(
                          '5 reminders today',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: _isDarkMode
                                ? Colors.white.withOpacity(0.6)
                                : const Color(0xFF8A8A8A),
                          ),
                        ),
                  
                        SizedBox(height: 12.h),
                  
                        // Category Icons Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildPreviewCategoryIcon(
                              Icons.medication_outlined,
                            ),
                            SizedBox(width: 18.w),
                            _buildPreviewCategoryIcon(
                              Icons.local_florist_outlined,
                            ),
                            SizedBox(width: 18.w),
                            _buildPreviewCategoryIcon(
                              Icons.directions_bus_outlined,
                            ),
                          ],
                        ),
                  
                        SizedBox(height: 12.h),
                  
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.r),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Current Cue Card
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: _isDarkMode
                                        ? Color.lerp(
                                            const Color(0xFF1E1E1E),
                                            _selectedColor,
                                            0.1,
                                          )!
                                        : Colors.white,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _selectedColor
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8.r),
                                            ),
                                            child: Text(
                                              'CURRENT CUE',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w700,
                                                color: _selectedColor,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _selectedColor
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Text(
                                              'in 15 mins',
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),
                                      Text(
                                        'Team standup',
                                        style: TextStyle(
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w600,
                                          color: _isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF2D2D2D),
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14.sp,
                                            color: _isDarkMode
                                                ? Colors.white.withOpacity(
                                                    0.6,
                                                  )
                                                : const Color(0xFF8A8A8A),
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            '10:00 AM',
                                            style: TextStyle(
                                              fontSize: 13.sp,
                                              color: _isDarkMode
                                                  ? Colors.white.withOpacity(
                                                      0.6,
                                                    )
                                                  : const Color(0xFF8A8A8A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                  
                                SizedBox(height: 12.h),
                  
                                // Upcoming Section
                                Text(
                                  'UPCOMING',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: _isDarkMode
                                        ? Colors.white.withOpacity(0.6)
                                        : const Color(0xFF8A8A8A),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                  
                                // Horizontal scrollable upcoming items
                                SizedBox(
                                  height: 70.h,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 3,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(width: 8.w),
                                    itemBuilder: (context, index) {
                                      final items = [
                                        {'title': 'Lunch', 'time': '12:30'},
                                        {'title': 'Meeting', 'time': '2:00'},
                                        {'title': 'Gym', 'time': '6:00'},
                                      ];
                                      return Container(
                                        width: 100.w,
                                        padding: EdgeInsets.all(12.r),
                                        decoration: BoxDecoration(
                                          color: _isDarkMode
                                              ? Color.lerp(
                                                  const Color(0xFF1E1E1E),
                                                  _selectedColor,
                                                  0.1,
                                                )!
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                _isDarkMode ? 0.2 : 0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 6.w,
                                                  height: 6.h,
                                                  decoration: BoxDecoration(
                                                    color: _selectedColor
                                                        .withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Expanded(
                                                  child: Text(
                                                    items[index]['title']!,
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _isDarkMode
                                                          ? Colors.white
                                                          : const Color(
                                                              0xFF2D2D2D,
                                                            ),
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              items[index]['time']!,
                                              style: TextStyle(
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
                                                color: _isDarkMode
                                                    ? Colors.white
                                                          .withOpacity(0.6)
                                                    : const Color(0xFF8A8A8A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  
                        // Bottom with FAB preview
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: 8.h,
                            right: 20.w,
                            top: 4.h,
                          ),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            child: Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _selectedColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                // Next button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isDarkMode
                          ? Colors.white
                          : Colors.black,
                      foregroundColor: _isDarkMode
                          ? Colors.black
                          : Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: _isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.black.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _isDarkMode ? Colors.black : Colors.white,
                            ),
                          )
                        : Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return Container(
      width: isActive ? 16.w : 8.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: isActive? (_isDarkMode ? Colors.white : const Color(0xFFFFB4A3))
            : (_isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : const Color(0xFFE0E0E0)),
        shape: isActive ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isActive ? BorderRadius.circular(12.r) : null,
      ),
    );
  }

  Widget _buildPreviewCategoryIcon(IconData icon) {
    return Container(
      width: 32.w,
      height: 32.h,
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.1)
            : _selectedColor.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: _isDarkMode
            ? Colors.white.withOpacity(0.7)
            : _selectedColor.withOpacity(0.7),
        size: 16.sp,
      ),
    );
  }
}
