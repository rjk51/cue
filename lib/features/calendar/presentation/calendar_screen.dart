import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/theme_service.dart';
import '../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../settings/presentation/settings_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ThemeService _themeService = ThemeService();
  Color _accentColor = const Color(0xFF2D7A78);
  Color? _backgroundColor;
  bool _isDarkMode = false;
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();
    final bgColor = await _themeService.getBackgroundColor();
    if (mounted) {
      setState(() {
        _accentColor = accentColor;
        _backgroundColor = bgColor;
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

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Calendar', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SafeArea(
        child: Center(
          child: Text(
            'Calendar placeholder',
            style: TextStyle(fontSize: 18.sp, color: textColor),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(left: 16.w, right: 16.w),
        child: BottomNavBar(
          accentColor: _accentColor,
          isDarkMode: _isDarkMode,
          currentIndex: _currentIndex,
          onTap: (index) async {
            if (index == _currentIndex) return;
            if (index == 0) {
              // Go back to home
              Navigator.pop(context);
            } else if (index == 1) {
              // already on calendar
            } else if (index == 2) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            }
          },
        ),
      ),
    );
  }
}
