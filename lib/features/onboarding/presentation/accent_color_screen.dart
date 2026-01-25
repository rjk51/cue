import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../../services/theme_service.dart';
import '../../home/presentation/home_screen.dart';

class AccentColorScreen extends StatefulWidget {
  final String themeMode;

  const AccentColorScreen({
    super.key,
    required this.themeMode,
  });

  @override
  State<AccentColorScreen> createState() => _AccentColorScreenState();
}

class _AccentColorScreenState extends State<AccentColorScreen> {
  final ThemeService _themeService = ThemeService();
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
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
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
              pickersEnabled: const {
                ColorPickerType.wheel: true,
              },
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
                  colors: [
                    Color(0xFF2C242A),
                    Color(0xFF1C1922),
                  ],
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
                // Example UI preview
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: _isDarkMode
                          ? const Color(0xFF2D2D2D)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TODAY',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: _isDarkMode
                                        ? Colors.white.withOpacity(0.5)
                                        : const Color(0xFF8A8A8A),
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Good morning,',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF2D2D2D),
                                  ),
                                ),
                                Text(
                                  'Sarah.',
                                  style: TextStyle(
                                    fontSize: 24.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _isDarkMode
                                        ? Colors.white
                                        : const Color(0xFF2D2D2D),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: _selectedColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: BoxDecoration(
                                    color: _selectedColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24.h),
                        // Daily Goals section
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? const Color(0xFF3A3A3A)
                                : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Daily Goals',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF2D2D2D),
                                    ),
                                  ),
                                  Text(
                                    '3 left',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: _selectedColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: LinearProgressIndicator(
                                  value: 0.6,
                                  backgroundColor: _isDarkMode
                                      ? const Color(0xFF4A4A4A)
                                      : const Color(0xFFE0E0E0),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _selectedColor,
                                  ),
                                  minHeight: 8.h,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        // Tasks
                        _buildTaskItem(
                          title: 'Morning meditation',
                          isCompleted: true,
                        ),
                        SizedBox(height: 12.h),
                        _buildTaskItem(
                          title: 'Design Review',
                          time: '10:00 AM • Zoom',
                          isCompleted: false,
                          showFab: true,
                        ),
                      ],
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
      width: 8.w,
      height: 8.h,
      decoration: BoxDecoration(
        color: isActive
            ? (_isDarkMode ? Colors.white : const Color(0xFFFFB4A3))
            : (_isDarkMode
                ? Colors.white.withOpacity(0.3)
                : const Color(0xFFE0E0E0)),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildTaskItem({
    required String title,
    String? time,
    required bool isCompleted,
    bool showFab = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: _isDarkMode
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: BoxDecoration(
              color: isCompleted
                  ? _selectedColor
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCompleted
                    ? _selectedColor
                    : (_isDarkMode
                        ? Colors.white.withOpacity(0.3)
                        : const Color(0xFFE0E0E0)),
                width: 2,
              ),
            ),
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 16.sp,
                    color: Colors.white,
                  )
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: _isDarkMode
                        ? (isCompleted
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white)
                        : (isCompleted
                            ? const Color(0xFF8A8A8A)
                            : const Color(0xFF2D2D2D)),
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (time != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : const Color(0xFF8A8A8A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showFab) ...[
            SizedBox(width: 12.w),
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withOpacity(0.3),
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
          ],
        ],
      ),
    );
  }
}
