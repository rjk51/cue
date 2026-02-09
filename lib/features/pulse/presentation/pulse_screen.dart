import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../data/pulse_service.dart';
import 'widgets/streak_card.dart';
import 'widgets/activity_heatmap.dart';
import 'widgets/stats_row.dart';
import 'widgets/insights_section.dart';
import 'widgets/achievements_section.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen>
    with SingleTickerProviderStateMixin {
  final ThemeService _themeService = ThemeService();
  final PulseService _pulseService = PulseService();

  Color _accentColor = const Color(0xFF2D7A78);
  Color? _backgroundColor;
  bool _isDarkMode = false;

  PulseData? _data;
  bool _isLoading = true;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadTheme();
    _loadData();

    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) _loadTheme();
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

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await _pulseService.loadPulseData();

      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
        _fadeController.forward(from: 0.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _backgroundColor ??
        (_isDarkMode
            ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
            : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final textColor = _isDarkMode ? Colors.white : const Color(0xFF2D2D2D);
    final subtitleColor =
        _isDarkMode ? Colors.white.withOpacity(0.6) : const Color(0xFF8A8A8A);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32.w,
                      height: 32.w,
                      child: CircularProgressIndicator(
                        color: _accentColor,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Analyzing your productivity...',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red, size: 48.sp),
                        SizedBox(height: 12.h),
                        Text(
                          'Failed to load data',
                          style: TextStyle(
                              fontSize: 16.sp, color: textColor),
                        ),
                        SizedBox(height: 8.h),
                        TextButton(
                          onPressed: _loadData,
                          child: Text('Retry',
                              style: TextStyle(color: _accentColor)),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      color: _accentColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Padding(
                              padding: EdgeInsets.only(
                                  top: 16.h, bottom: 24.h),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color: textColor,
                                      size: 24.sp,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        const BoxConstraints(),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    'Pulse',
                                    style: TextStyle(
                                      fontSize: 32.sp,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: _accentColor
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      'BETA',
                                      style: TextStyle(
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _accentColor,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Streak card
                            StreakCard(
                              streaks: _data!.streaks,
                              accentColor: _accentColor,
                              isDarkMode: _isDarkMode,
                              cardColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                            SizedBox(height: 24.h),

                            // Stats row
                            StatsRow(
                              stats: _data!.stats,
                              accentColor: _accentColor,
                              isDarkMode: _isDarkMode,
                              cardColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                            SizedBox(height: 28.h),

                            // Heatmap section
                            Text(
                              'ACTIVITY',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: subtitleColor,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius:
                                    BorderRadius.circular(18.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                        _isDarkMode ? 0.25 : 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ActivityHeatmap(
                                data: _data!.heatmap,
                                accentColor: _accentColor,
                                isDarkMode: _isDarkMode,
                              ),
                            ),
                            SizedBox(height: 28.h),

                            // AI Insights
                            InsightsSection(
                              insights: _data!.insights,
                              accentColor: _accentColor,
                              isDarkMode: _isDarkMode,
                              cardColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                            SizedBox(height: 28.h),

                            // Achievements
                            AchievementsSection(
                              achievements: _data!.achievements,
                              accentColor: _accentColor,
                              isDarkMode: _isDarkMode,
                              cardColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                            SizedBox(height: 48.h),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}
