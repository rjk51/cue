import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../services/local_storage_service.dart';
import '../../notifications/notification_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final ThemeService _themeService = ThemeService();
  final TextEditingController _nudgeMessageController = TextEditingController();

  late Color _accentColor;
  late bool _isDarkMode;
  String _selectedSound = 'notification_ringtone';
  
  // Available notification sounds
  final List<Map<String, String>> _sounds = [
    {'name': 'notification_ringtone', 'display': 'Default Tone', 'emoji': '🔔'},
    {'name': 'notification_bell', 'display': 'Bell Chime', 'emoji': '🎵'},
    {'name': 'notification_ding', 'display': 'Ding Sound', 'emoji': '🔊'},
    {'name': 'notification_alert', 'display': 'Alert Tone', 'emoji': '⚡'},
  ];

  @override
  void initState() {
    super.initState();
    _accentColor = ThemeNotifier.instance.accentColor;
    _isDarkMode = ThemeNotifier.instance.isDarkMode;
    _loadSettings();
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _nudgeMessageController.dispose();
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      _accentColor = ThemeNotifier.instance.accentColor;
      _isDarkMode = ThemeNotifier.instance.isDarkMode;
    });
  }

  Future<void> _loadSettings() async {
    final selectedSound = LocalStorageService.instance.getNotificationSound();
    final nudgeMessage = LocalStorageService.instance.getNudgeMessage();
    
    if (mounted) {
      setState(() {
        _selectedSound = selectedSound;
        _nudgeMessageController.text = nudgeMessage;
      });
    }
  }

  Future<void> _saveNotificationSound(String soundName) async {
    await LocalStorageService.instance.setNotificationSound(soundName);
    setState(() {
      _selectedSound = soundName;
    });
    _showSnackbar('Notification sound updated ✓');
  }

  Future<void> _saveNudgeMessage() async {
    final message = _nudgeMessageController.text.trim();
    
    // Validate: should be around 4 words (allow 2-6 words for flexibility)
    final wordCount = message.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    
    if (message.isEmpty) {
      _showSnackbar('Please enter a nudge message', isError: true);
      return;
    }
    
    if (wordCount > 6) {
      _showSnackbar('Keep it short! Max 6 words recommended', isError: true);
      return;
    }
    
    await LocalStorageService.instance.setNudgeMessage(message);
    _showSnackbar('Nudge message updated ✓');
    FocusScope.of(context).unfocus();
  }

  // Test notification functionality removed - not implemented in NotificationService

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = ThemeNotifier.instance.textColor ?? (_isDarkMode ? Colors.white : Colors.black);
    final subtitleColor = textColor.withOpacity(0.6);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 24.sp),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification Settings',
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(20.r),
        children: [
          // Notification Sound Section
          _buildSectionTitle('Notification Sound', '🔔', textColor, subtitleColor),
          SizedBox(height: 12.h),
          _buildSoundOptions(cardColor, textColor, subtitleColor),
          
          SizedBox(height: 32.h),
          
          // Nudge Message Section
          _buildSectionTitle('Custom Nudge Message', '👋', textColor, subtitleColor),
          SizedBox(height: 8.h),
          Text(
            'Customize what your buddy sees when you nudge them',
            style: TextStyle(
              fontSize: 13.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 16.h),
          _buildNudgeMessageCard(cardColor, textColor, subtitleColor),
        ],
      ),
    );
  }

  Color get _backgroundColor {
    return ThemeNotifier.instance.backgroundColor ?? 
           (_isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
  }

  Widget _buildSectionTitle(String title, String emoji, Color textColor, Color subtitleColor) {
    return Row(
      children: [
        Text(
          emoji,
          style: TextStyle(fontSize: 24.sp),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSoundOptions(Color cardColor, Color textColor, Color subtitleColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: _sounds.map((sound) {
          final isSelected = _selectedSound == sound['name'];
          return _buildSoundOption(
            sound['emoji']!,
            sound['display']!,
            sound['name']!,
            isSelected,
            cardColor,
            textColor,
            subtitleColor,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSoundOption(
    String emoji,
    String displayName,
    String soundName,
    bool isSelected,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _saveNotificationSound(soundName),
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: subtitleColor.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                emoji,
                style: TextStyle(fontSize: 24.sp),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: textColor,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: _accentColor,
                  size: 24.sp,
                )
              else
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: subtitleColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNudgeMessageCard(Color cardColor, Color textColor, Color subtitleColor) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Example: "Drink water nudge"',
            style: TextStyle(
              fontSize: 13.sp,
              color: subtitleColor,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _nudgeMessageController,
            style: TextStyle(
              fontSize: 16.sp,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            maxLength: 40,
            decoration: InputDecoration(
              hintText: 'Don\'t forget your reminders',
              hintStyle: TextStyle(
                color: subtitleColor,
                fontSize: 16.sp,
              ),
              filled: true,
              fillColor: _isDarkMode 
                  ? Colors.black.withOpacity(0.2) 
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: _accentColor, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              counterStyle: TextStyle(
                fontSize: 12.sp,
                color: subtitleColor,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Keep it short and meaningful (2-6 words recommended)',
            style: TextStyle(
              fontSize: 12.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveNudgeMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Text(
                'Save Message',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
