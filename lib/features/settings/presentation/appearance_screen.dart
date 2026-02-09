import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import '../../../services/theme_service.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  final ThemeService _themeService = ThemeService();
  Color _selectedColor = const Color(0xFFFFB4A3);
  Color? _backgroundColor;
  Color? _textColor;
  String _themeMode = 'light';
  double _fontSizeScale = 1.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final color = await _themeService.getAccentColor();
    final theme = await _themeService.getThemePreference();
    final fontSize = await _themeService.getFontSizeScale();
    final bgColor = await _themeService.getBackgroundColor();
    final txtColor = await _themeService.getTextColor();
    setState(() {
      _selectedColor = color;
      _themeMode = theme;
      _fontSizeScale = fontSize;
      _backgroundColor = bgColor;
      _textColor = txtColor;
    });
  }

  bool get _isDarkMode {
    if (_themeMode == 'dark') return true;
    if (_themeMode == 'system') {
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
              onPressed: () async {
                setState(() {
                  _selectedColor = pickedColor;
                  _isLoading = true;
                });
                await _themeService.setAccentColor(pickedColor);
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Accent color updated!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showBackgroundColorPicker() async {
    Color pickedColor = _backgroundColor ?? (_isDarkMode ? const Color(0xFF121212) : const Color(0xFFFAF5F3));

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick background color'),
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
            if (_backgroundColor != null)
              TextButton(
                onPressed: () async {
                  setState(() {
                    _backgroundColor = null;
                    _isLoading = true;
                  });
                  await _themeService.setBackgroundColor(null);
                  setState(() {
                    _isLoading = false;
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Background reset to default!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Reset'),
              ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _backgroundColor = pickedColor;
                  _isLoading = true;
                });
                await _themeService.setBackgroundColor(pickedColor);
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Background color updated!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTextColorPicker() async {
    Color pickedColor = _textColor ?? (_isDarkMode ? Colors.white : const Color(0xFF2D2D2D));

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick text color'),
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
            if (_textColor != null)
              TextButton(
                onPressed: () async {
                  setState(() {
                    _textColor = null;
                    _isLoading = true;
                  });
                  await _themeService.setTextColor(null);
                  setState(() {
                    _isLoading = false;
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Text color reset to default!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Reset'),
              ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _textColor = pickedColor;
                  _isLoading = true;
                });
                await _themeService.setTextColor(pickedColor);
                setState(() {
                  _isLoading = false;
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Text color updated!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('This will reset accent color, background color, text color, and font size to defaults. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _themeService.setAccentColor(const Color(0xFFFFB4A3));
        await _themeService.setBackgroundColor(null);
        await _themeService.setTextColor(null);
        await _themeService.setFontSizeScale(1.0);
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reset to defaults!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting: $e'),
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
  }

  Future<void> _updateThemeMode(String mode) async {
    setState(() {
      _themeMode = mode;
      _isLoading = true;
    });

    try {
      await _themeService.setThemePreference(mode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme updated to $mode mode!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating theme: $e'),
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

  Future<void> _updateFontSizeScale(double scale) async {
    setState(() {
      _fontSizeScale = scale;
      _isLoading = true;
    });

    try {
      await _themeService.setFontSizeScale(scale);
      if (mounted) {
        String sizeLabel = scale == 1.0 ? 'Default' : scale == 1.15 ? 'Medium' : 'Large';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Font size updated to $sizeLabel!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating font size: $e'),
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
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _selectedColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _selectedColor, 0.05)!);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _selectedColor, 0.1)!
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
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor, size: 24.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Appearance',
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
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Theme Mode Section
                    Text(
                      'THEME',
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
                          _buildThemeOption(
                            title: 'Light',
                            icon: Icons.light_mode,
                            isSelected: _themeMode == 'light',
                            onTap: () => _updateThemeMode('light'),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: subtitleColor.withOpacity(0.08),
                          ),
                          _buildThemeOption(
                            title: 'Dark',
                            icon: Icons.dark_mode,
                            isSelected: _themeMode == 'dark',
                            onTap: () => _updateThemeMode('dark'),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: subtitleColor.withOpacity(0.08),
                          ),
                          _buildThemeOption(
                            title: 'System',
                            icon: Icons.brightness_auto,
                            isSelected: _themeMode == 'system',
                            onTap: () => _updateThemeMode('system'),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Font Size Section
                    Text(
                      'FONT SIZE',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Single row with three font size options (compact, no outer card)
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _buildCompactFontOption(
                            label: 'Default',
                            scale: 1.0,
                            isSelected: _fontSizeScale == 1.0,
                            onTap: () => _updateFontSizeScale(1.0),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildCompactFontOption(
                            label: 'Medium',
                            scale: 1.15,
                            isSelected: _fontSizeScale == 1.15,
                            onTap: () => _updateFontSizeScale(1.15),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildCompactFontOption(
                            label: 'Large',
                            scale: 1.3,
                            isSelected: _fontSizeScale == 1.3,
                            onTap: () => _updateFontSizeScale(1.3),
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),

                    // Accent Color Section
                    Text(
                      'ACCENT COLOR',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    Container(
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
                          GestureDetector(
                            onTap: _showColorPicker,
                            child: Container(
                              width: 80.w,
                              height: 80.w,
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
                          SizedBox(width: 20.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Choose a color that fits your style',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Background Color Section
                    Text(
                      'BACKGROUND COLOR',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    Container(
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
                          GestureDetector(
                            onTap: _showBackgroundColorPicker,
                            child: Container(
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                color: _backgroundColor ?? (_isDarkMode 
                                  ? Color.lerp(const Color(0xFF121212), _selectedColor, 0.08)! 
                                  : Color.lerp(const Color(0xFFFAF5F3), _selectedColor, 0.05)!),
                                shape: BoxShape.circle,
                                border: _backgroundColor == null ? Border.all(
                                  color: subtitleColor.withOpacity(0.2),
                                  width: 2,
                                ) : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_backgroundColor ?? _selectedColor).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: _backgroundColor == null
                                  ? Icon(
                                      Icons.gradient,
                                      color: subtitleColor.withOpacity(0.5),
                                      size: 32.sp,
                                    )
                                  : null,
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _backgroundColor == null ? 'Using default' : 'Tap to change',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _backgroundColor == null 
                                      ? 'Default gradient background' 
                                      : 'Custom solid background',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Text Color Section
                    Text(
                      'TEXT COLOR',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    Container(
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
                          GestureDetector(
                            onTap: _showTextColorPicker,
                            child: Container(
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                color: _textColor ?? (_isDarkMode 
                                  ? Colors.white 
                                  : const Color(0xFF2D2D2D)),
                                shape: BoxShape.circle,
                                border: _textColor == null ? Border.all(
                                  color: subtitleColor.withOpacity(0.2),
                                  width: 2,
                                ) : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_textColor ?? (_isDarkMode ? Colors.white : const Color(0xFF2D2D2D))).withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    fontSize: 32.sp,
                                    fontWeight: FontWeight.bold,
                                    color: backgroundColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _textColor == null ? 'Using default' : 'Tap to change',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _textColor == null 
                                      ? 'Default theme-based text' 
                                      : 'Custom text color',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Reset to Defaults Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: TextButton(
                        onPressed: _resetToDefaults,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Reset All to Defaults',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Preview Section
                    Text(
                      'PREVIEW',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Home Screen Preview
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(28.r),
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 345.h,
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
                        
                            SizedBox(height: 20.h),
                        
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.r),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                        
                                    SizedBox(height: 16.h),
                        
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
                        
                            // Bottom with FAB preview
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 8.h,
                                right: 20.w,
                                top: 8.h,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: isSelected
                    ? _selectedColor.withOpacity(0.15)
                    : subtitleColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? _selectedColor : subtitleColor,
                size: 22.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: _selectedColor, size: 24.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFontOption({
    required String label,
    required double scale,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 6.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                // Compact preview without boxed container
                fontSize: (16.sp * scale),
                fontWeight: FontWeight.w700,
                color: isSelected ? _selectedColor : textColor,
              ),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? _selectedColor : subtitleColor,
                  ),
                ),
                if (isSelected) ...[
                  SizedBox(width: 6.w),
                  Icon(Icons.check_circle, color: _selectedColor, size: 16.sp),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}
