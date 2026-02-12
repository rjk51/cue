import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/whisper_speech_service.dart';
import '../../../services/chatgpt_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../reminders/data/reminder_service.dart';
import '../../reminders/domain/reminder_model.dart';
import '../../notifications/notification_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../services/connectivity_service.dart';
import '../../../shared/widgets/internet_required_dialog.dart';

class VoiceReminderScreen extends StatefulWidget {
  const VoiceReminderScreen({super.key});

  @override
  State<VoiceReminderScreen> createState() => _VoiceReminderScreenState();
}

class _VoiceReminderScreenState extends State<VoiceReminderScreen>
    with SingleTickerProviderStateMixin {
  final WhisperSpeechService _whisperService = WhisperSpeechService.instance;
  final ChatGPTService _chatGPTService = ChatGPTService.instance;
  final ReminderService _reminderService = ReminderService();
  final NotificationService _notificationService = NotificationService();
  final ThemeService _themeService = ThemeService();

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusText = 'Tap to speak';
  String? _transcribedText;
  String? _parsedReminderText;
  DateTime? _parsedTime;

  Color _accentColor = const Color(0xFF2D7A78);
  bool _isDarkMode = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    ThemeNotifier.instance.addListener(_onThemeChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      _loadThemeSettings();
    }
  }

  Future<void> _loadThemeSettings() async {
    final themePreference = await _themeService.getThemePreference();
    final accentColor = await _themeService.getAccentColor();

    if (mounted) {
      setState(() {
        _accentColor = accentColor;
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

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      // Voice input requires internet for Whisper API + ChatGPT
      if (!ConnectivityService().isOnline.value) {
        if (mounted) {
          await showInternetRequiredDialog(
            context,
            featureName: 'Voice input',
            accentColor: _accentColor,
            isDarkMode: _isDarkMode,
          );
        }
        return;
      }
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      await _whisperService.startRecording();
      setState(() {
        _isRecording = true;
        _statusText = 'Listening...';
        _transcribedText = null;
        _parsedReminderText = null;
        _parsedTime = null;
      });
      _pulseController.repeat(reverse: true);
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to start recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _pulseController.stop();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusText = 'Processing...';
      });

      final File? audioFile = await _whisperService.stopRecording();

      if (audioFile == null) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Recording too short. Try again.';
        });
        return;
      }

      // Transcribe with Whisper
      setState(() => _statusText = 'Transcribing...');
      final transcription = await _whisperService.transcribeWithWhisper(audioFile);

      if (transcription == null || transcription.isEmpty) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Could not understand. Try again.';
        });
        return;
      }

      setState(() {
        _transcribedText = transcription;
        _statusText = 'Parsing reminder...';
      });

      // Parse with ChatGPT
      final parseResult = await _chatGPTService.parseReminderFromVoice(transcription);

      if (parseResult == null) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Could not parse reminder. Try again.';
        });
        return;
      }

      setState(() {
        _parsedReminderText = parseResult.reminderText;
        _parsedTime = parseResult.scheduledTime;
        _statusText = 'Reminder ready!';
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusText = 'Error: $e';
      });
    }
  }

  Future<void> _saveReminder() async {
    if (_parsedReminderText == null || _parsedTime == null) return;

    setState(() => _isProcessing = true);

    try {
      // Get the current user ID from Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      final userId = currentUser?.uid ?? 'demo_user';

      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _parsedReminderText!,
        time: _parsedTime!,
        isCompleted: false,
        deviceToken: _notificationService.fcmToken,
        userId: userId,
        iconCodePoint: Icons.mic.codePoint,
        colorValue: _accentColor.value,
        autoSnoozeEnabled: false,
        autoSnoozeInterval: 10,
        autoSnoozeMaxCount: 3,
        autoSnoozeCount: 0,
      );

      final reminderId = await _reminderService.addReminder(
        reminder,
        _notificationService.fcmToken,
      );

      final savedReminder = reminder.copyWith(id: reminderId);
      await _notificationService.scheduleReminderNotification(savedReminder);

      if (mounted) {
        Navigator.pop(context, savedReminder);
        context.showSuccessSnackbar('Voice reminder created!');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to save reminder: $e');
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _isDarkMode ? const Color(0xFF121212) : Colors.white;
    final cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = _isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Reminder',
          style: TextStyle(
            color: textColor,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              // Status text
              Text(
                _statusText,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),

              // Recording button
              GestureDetector(
                onTap: _isProcessing ? null : _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: Container(
                        width: 200.w,
                        height: 200.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording
                              ? _accentColor.withOpacity(0.2)
                              : cardColor,
                          border: Border.all(
                            color: _accentColor,
                            width: 4.w,
                          ),
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 80.sp,
                          color: _accentColor,
                        ),
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: 40.h),

              // Transcribed text
              if (_transcribedText != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You said:',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        _transcribedText!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Parsed reminder
              if (_parsedReminderText != null && _parsedTime != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: _accentColor, size: 20.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'Reminder Details',
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _parsedReminderText!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.schedule, color: subtitleColor, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(
                            DateFormat('MMM d, y \'at\' h:mm a').format(_parsedTime!),
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Reminder',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
