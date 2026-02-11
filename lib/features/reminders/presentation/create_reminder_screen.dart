import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../domain/recurrence_rule.dart';
import '../domain/reminder_model.dart';
import '../data/reminder_service.dart';
import '../../notifications/notification_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../../../services/tutorial_service.dart';
import '../../../services/pro_status_service.dart';
import '../../../services/file_storage_service.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/cupertino_pickers.dart';
import '../../../shared/widgets/edit_recurring_dialog.dart';
import '../../../services/whisper_speech_service.dart';
import '../../../services/chatgpt_service.dart';
import '../../subscription/presentation/cue_pro_paywall_screen.dart';
import '../../../shared/widgets/tutorial_overlay.dart';
import 'widgets/icon_picker_sheet.dart';
import 'widgets/sticky_save_button.dart';

class NewReminderScreen extends StatefulWidget {
  final Reminder? reminderToEdit;
  final bool openedForVoice;

  const NewReminderScreen({
    super.key,
    this.reminderToEdit,
    this.openedForVoice = false,
  });

  @override
  State<NewReminderScreen> createState() => _NewReminderScreenState();
}

class _NewReminderScreenState extends State<NewReminderScreen>
    with SingleTickerProviderStateMixin {
  final ThemeService _themeService = ThemeService();
  final ReminderService _reminderService = ReminderService();
  final NotificationService _notificationService = NotificationService();
  final TutorialService _tutorialService = TutorialService();
  final ProStatusService _proStatusService = ProStatusService();
  final FileStorageService _fileStorageService = FileStorageService();
  final TextEditingController _reminderController = TextEditingController();
  final WhisperSpeechService _whisperService = WhisperSpeechService.instance;
  final ChatGPTService _chatGPTService = ChatGPTService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  late Color _accentColor;
  late Color? _backgroundColor;
  late bool _isDarkMode;
  bool _isSaving = false;
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  bool _showVoiceHint = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Tutorial state
  bool _showRepeatTutorial = false;
  bool _showAutoSnoozeTutorial = false;
  final GlobalKey _repeatSwitchKey = GlobalKey();
  final GlobalKey _autoSnoozeSwitchKey = GlobalKey();

  // Reminder fields
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(DateTime.now());
  bool _repeatEnabled = false;

  // Recurrence fields (only used when repeat is enabled)
  RecurrenceFrequency _selectedFrequency = RecurrenceFrequency.weekly;
  Set<int> _selectedDays = {};
  DateTime? _endDate;
  bool _endDateEnabled = false;

  // Hourly interval fields
  int _hourlyIntervalHours = 1;
  int _hourlyIntervalMinutes = 0;

  // Icon and color
  IconData _selectedIcon = Icons.notification_important_outlined;
  String? _selectedCustomIconUrl;
  Color _selectedColor = const Color(0xFFFFB4A3);

  // Auto-snooze fields
  bool _autoSnoozeEnabled = false;
  int _autoSnoozeInterval = 10; // default 10 minutes
  int _autoSnoozeMaxCount = 3; // default 3 times
  int _sliderMaxValue = 60; // dynamic max value for slider

  // Attachments
  List<Map<String, dynamic>> _attachments = [];
  bool _isUploadingAttachment = false;

  // Map day indices to abbreviated names
  final List<String> _dayAbbreviations = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Track initial values to detect changes
  String _initialName = '';
  DateTime? _initialDate;
  TimeOfDay? _initialTime;
  bool _initialRepeatEnabled = false;
  RecurrenceFrequency? _initialFrequency;
  Set<int> _initialDays = {};
  DateTime? _initialEndDate;
  bool _initialEndDateEnabled = false;
  IconData? _initialIcon;
  Color? _initialColor;
  bool _initialAutoSnoozeEnabled = false;
  int? _initialAutoSnoozeInterval;
  int? _initialAutoSnoozeMaxCount;
  int _initialHourlyIntervalHours = 1;
  int _initialHourlyIntervalMinutes = 0;

  @override
  void initState() {
    super.initState();
    // Initialize theme values synchronously from ThemeNotifier to prevent white flash
    _accentColor = ThemeNotifier.instance.accentColor;
    _backgroundColor = ThemeNotifier.instance.backgroundColor;
    _isDarkMode = ThemeNotifier.instance.isDarkMode;
    
    _loadThemeSettings();
    _checkTutorialState();
    ThemeNotifier.instance.addListener(_onThemeChanged);
    _reminderController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize glow animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Show voice hint if opened for voice
    if (widget.openedForVoice) {
      _showVoiceHint = true;
      _glowController.repeat(reverse: true);
      // Auto-hide hint after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _showVoiceHint = false);
          _glowController.stop();
        }
      });
    }

    // If editing, pre-fill fields
    if (widget.reminderToEdit != null) {
      _initializeEditMode();
    } else {
      _selectedDays = {_selectedDate.weekday};
    }
  }

  Future<void> _checkTutorialState() async {
    // Only show tutorials when creating new reminder (not editing)
    if (widget.reminderToEdit != null) return;

    final state = await _tutorialService.getTutorialState();
    final shouldShowRepeat =
        !(state[TutorialService.createRepeatShownKey] ?? false);
    final shouldShowAutoSnooze =
        !(state[TutorialService.createAutoSnoozeShownKey] ?? false);

    if (!mounted) return;

    if (shouldShowRepeat) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showRepeatTutorial = true;
          });
        }
      });
    } else if (shouldShowAutoSnooze) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _showAutoSnoozeTutorial = true;
          });
        }
      });
    }
  }

  void _onRepeatTutorialNext() {
    setState(() {
      _showRepeatTutorial = false;
    });
    _tutorialService.markTutorialShown(TutorialService.createRepeatShownKey);

    // Check if auto-snooze tutorial should be shown next
    _tutorialService
        .getTutorialFlag(TutorialService.createAutoSnoozeShownKey)
        .then((shown) {
          if (!shown && mounted) {
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) {
                setState(() {
                  _showAutoSnoozeTutorial = true;
                });
              }
            });
          }
        });
  }

  void _onRepeatTutorialSkip() {
    setState(() {
      _showRepeatTutorial = false;
      _showAutoSnoozeTutorial = false;
    });
    _tutorialService.markMultipleTutorialsShown([
      TutorialService.createRepeatShownKey,
      TutorialService.createAutoSnoozeShownKey,
    ]);
  }

  void _onAutoSnoozeTutorialNext() {
    setState(() {
      _showAutoSnoozeTutorial = false;
    });
    _tutorialService.markTutorialShown(
      TutorialService.createAutoSnoozeShownKey,
    );
  }

  void _onAutoSnoozeTutorialSkip() {
    setState(() {
      _showAutoSnoozeTutorial = false;
    });
    _tutorialService.markTutorialShown(
      TutorialService.createAutoSnoozeShownKey,
    );
  }

  void _initializeEditMode() {
    final reminder = widget.reminderToEdit!;

    // For recurring reminders, use effectiveNextDueAt to get the current occurrence
    // For non-recurring, use the original time
    final displayTime = reminder.recurrence != null
        ? reminder.effectiveNextDueAt
        : reminder.time;

    // Set initial values
    _initialName = reminder.name;
    _initialDate = displayTime;
    _initialTime = TimeOfDay.fromDateTime(displayTime);
    _initialIcon = reminder.icon;
    _initialColor = reminder.color;
    _initialAutoSnoozeEnabled = reminder.autoSnoozeEnabled;
    _initialAutoSnoozeInterval = reminder.autoSnoozeInterval;
    _initialAutoSnoozeMaxCount = reminder.autoSnoozeMaxCount;

    // Pre-fill fields
    _reminderController.text = reminder.name;
    _selectedDate = DateTime(
      displayTime.year,
      displayTime.month,
      displayTime.day,
    );
    _selectedTime = TimeOfDay.fromDateTime(displayTime);
    _selectedIcon = reminder.icon;
    _selectedCustomIconUrl = reminder.customIconUrl;
    _selectedColor = reminder.color;
    _autoSnoozeEnabled = reminder.autoSnoozeEnabled;
    _autoSnoozeInterval = reminder.autoSnoozeInterval;
    _autoSnoozeMaxCount = reminder.autoSnoozeMaxCount;

    // Load existing attachments
    if (reminder.attachments != null) {
      _attachments = List<Map<String, dynamic>>.from(reminder.attachments!);
    }

    // Adjust slider max value if auto-snooze interval is greater than 60
    if (_autoSnoozeInterval > 60) {
      _sliderMaxValue = ((_autoSnoozeInterval / 60).ceil()) * 60;
    }

    // Handle recurrence
    if (reminder.recurrence != null) {
      _initialRepeatEnabled = true;
      _repeatEnabled = true;

      final recurrence = reminder.recurrence!;
      final frequency = recurrence['frequency'] as String?;

      if (frequency == 'hourly') {
        _selectedFrequency = RecurrenceFrequency.hourly;
        _initialFrequency = RecurrenceFrequency.hourly;

        // Parse interval
        final unit = recurrence['unit'] as String?;
        final every = recurrence['every'] as int? ?? 1;

        if (unit == 'hours') {
          _hourlyIntervalHours = every;
          _hourlyIntervalMinutes = 0;
        } else if (unit == 'minutes') {
          _hourlyIntervalHours = every ~/ 60;
          _hourlyIntervalMinutes = every % 60;
        }

        _initialHourlyIntervalHours = _hourlyIntervalHours;
        _initialHourlyIntervalMinutes = _hourlyIntervalMinutes;
      } else if (frequency == 'daily') {
        _selectedFrequency = RecurrenceFrequency.daily;
        _initialFrequency = RecurrenceFrequency.daily;
      } else if (frequency == 'weekly') {
        _selectedFrequency = RecurrenceFrequency.weekly;
        _initialFrequency = RecurrenceFrequency.weekly;
        final days = recurrence['days'] as List<dynamic>?;
        if (days != null) {
          _selectedDays = days.map((d) => d as int).toSet();
          _initialDays = Set.from(_selectedDays);
        }
      } else if (frequency == 'monthly') {
        _selectedFrequency = RecurrenceFrequency.monthly;
        _initialFrequency = RecurrenceFrequency.monthly;
      } else if (frequency == 'yearly') {
        _selectedFrequency = RecurrenceFrequency.yearly;
        _initialFrequency = RecurrenceFrequency.yearly;
      }

      // Handle end date
      if (recurrence['endDate'] != null) {
        Timestamp? endDateTimestamp;
        if (recurrence['endDate'] is Timestamp) {
          endDateTimestamp = recurrence['endDate'] as Timestamp;
        } else if (recurrence['endDate'] is Map) {
          // Handle case where it's stored as a map
          final endDateMap = recurrence['endDate'] as Map<String, dynamic>;
          endDateTimestamp = Timestamp(
            endDateMap['_seconds'] as int,
            endDateMap['_nanoseconds'] as int,
          );
        }
        if (endDateTimestamp != null) {
          _endDate = endDateTimestamp.toDate();
          _endDateEnabled = true;
          _initialEndDate = _endDate;
          _initialEndDateEnabled = true;
        }
      }
    } else {
      _initialRepeatEnabled = false;
      _selectedDays = {_selectedDate.weekday};
    }

    // Store initial values
    _initialName = reminder.name;
    _initialDate = _selectedDate;
    _initialTime = _selectedTime;
  }

  bool _hasChanges() {
    if (widget.reminderToEdit == null)
      return true; // Always show for new reminders

    // Check name
    if (_reminderController.text.trim() != _initialName) return true;

    // Check date
    if (_selectedDate.year != _initialDate?.year ||
        _selectedDate.month != _initialDate?.month ||
        _selectedDate.day != _initialDate?.day)
      return true;

    // Check time
    if (_selectedTime.hour != _initialTime?.hour ||
        _selectedTime.minute != _initialTime?.minute)
      return true;

    // Check repeat enabled
    if (_repeatEnabled != _initialRepeatEnabled) return true;

    // Check frequency
    if (_repeatEnabled && _selectedFrequency != _initialFrequency) return true;

    // Check hourly interval
    if (_repeatEnabled && _selectedFrequency == RecurrenceFrequency.hourly) {
      if (_hourlyIntervalHours != _initialHourlyIntervalHours ||
          _hourlyIntervalMinutes != _initialHourlyIntervalMinutes)
        return true;
    }

    // Check days
    if (_repeatEnabled && _selectedFrequency == RecurrenceFrequency.weekly) {
      if (_selectedDays.length != _initialDays.length ||
          !_selectedDays.every((d) => _initialDays.contains(d)))
        return true;
    }

    // Check end date enabled
    if (_repeatEnabled && _endDateEnabled != _initialEndDateEnabled)
      return true;

    // Check end date
    if (_repeatEnabled && _endDateEnabled) {
      if (_endDate?.year != _initialEndDate?.year ||
          _endDate?.month != _initialEndDate?.month ||
          _endDate?.day != _initialEndDate?.day)
        return true;
    }

    // Check icon
    if (_selectedIcon.codePoint != _initialIcon?.codePoint) return true;

    // Check color
    if (_selectedColor.value != _initialColor?.value) return true;

    // Check auto-snooze
    if (_autoSnoozeEnabled != _initialAutoSnoozeEnabled) return true;
    if (_autoSnoozeInterval != _initialAutoSnoozeInterval) return true;
    if (_autoSnoozeMaxCount != _initialAutoSnoozeMaxCount) return true;

    return false;
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _reminderController.dispose();
    _glowController.dispose();
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
        // Only default the reminder color to accent when creating.
        // In edit mode, keep the reminder's existing chosen color.
        if (widget.reminderToEdit == null) {
          _selectedColor = accentColor;
        }
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

  void _resetToInitial() {
    if (widget.reminderToEdit == null) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _reminderController.text = _initialName;

      final d = _initialDate ?? DateTime.now();
      _selectedDate = DateTime(d.year, d.month, d.day);
      _selectedTime = _initialTime ?? TimeOfDay.fromDateTime(DateTime.now());

      _repeatEnabled = _initialRepeatEnabled;
      _selectedFrequency = _initialFrequency ?? _selectedFrequency;
      _selectedDays = Set<int>.from(_initialDays);
      _endDateEnabled = _initialEndDateEnabled;
      _endDate = _initialEndDate;

      _selectedIcon = _initialIcon ?? _selectedIcon;
      _selectedColor = _initialColor ?? _selectedColor;

      _autoSnoozeEnabled = _initialAutoSnoozeEnabled;
      _autoSnoozeInterval = _initialAutoSnoozeInterval ?? _autoSnoozeInterval;
      _autoSnoozeMaxCount = _initialAutoSnoozeMaxCount ?? _autoSnoozeMaxCount;

      // Reset slider max value based on initial auto-snooze interval
      if ((_initialAutoSnoozeInterval ?? _autoSnoozeInterval) > 60) {
        _sliderMaxValue =
            (((_initialAutoSnoozeInterval ?? _autoSnoozeInterval) / 60)
                .ceil()) *
            60;
      } else {
        _sliderMaxValue = 60;
      }

      _hourlyIntervalHours = _initialHourlyIntervalHours;
      _hourlyIntervalMinutes = _initialHourlyIntervalMinutes;

      // Ensure days are sane if repeat is off
      if (!_repeatEnabled) {
        _selectedDays = {_selectedDate.weekday};
      } else if (_selectedFrequency == RecurrenceFrequency.weekly &&
          _selectedDays.isEmpty) {
        _selectedDays = {_selectedDate.weekday};
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showCupertinoDatePickerModal(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showCupertinoTimePickerModal(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showCupertinoDatePickerModal(
      context: context,
      initialDate: _endDate ?? _selectedDate.add(const Duration(days: 30)),
      firstDate: _selectedDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _toggleDay(int dayIndex) {
    setState(() {
      if (_selectedDays.contains(dayIndex)) {
        _selectedDays.remove(dayIndex);
      } else {
        _selectedDays.add(dayIndex);
      }
    });
  }

  Future<void> _openIconPicker() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IconPickerSheet(
        accentColor: _accentColor,
        isDarkMode: _isDarkMode,
        initialIcon: _selectedIcon,
        initialCustomIconUrl: _selectedCustomIconUrl,
      ),
    );

    if (result != null) {
      setState(() {
        if (result is Map) {
          // Custom icon
          _selectedCustomIconUrl = result['url'] as String?;
          _selectedIcon = Icons.notification_important_outlined;
        } else if (result is IconData) {
          // Regular icon
          _selectedIcon = result;
          _selectedCustomIconUrl = null;
        }
      });
    }
  }

  Future<void> _openColorPicker() async {
    Color pickedColor = _selectedColor;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode
            ? const Color.fromARGB(255, 33, 36, 39)
            : Colors.white,
        title: Text(
          'Choose Color',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: pickedColor,
            onColorChanged: (Color color) {
              pickedColor = color;
            },
            width: 40.w,
            height: 40.h,
            borderRadius: 20.r,
            spacing: 5.w,
            runSpacing: 5.h,
            wheelDiameter: 250.w,
            heading: Text(
              'Select color',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            subheading: Text(
              'Select color shade',
              style: TextStyle(
                fontSize: 14.sp,
                color: _isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            pickersEnabled: const {
              ColorPickerType.both: false,
              ColorPickerType.primary: false,
              ColorPickerType.accent: true,
              ColorPickerType.wheel: true,
            },
            // Rename the Accent tab to "Pre-defined Colors"
            // FlexColorPicker supports overriding picker labels via
            // `pickerTypeLabels` (map). If unsupported, this will be
            // caught by compiler and we'll adjust accordingly.
            pickerTypeLabels: const {
              ColorPickerType.accent: 'Pre-defined Colors',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedColor = pickedColor;
              });
              Navigator.pop(context);
            },
            child: Text(
              'Select',
              style: TextStyle(
                color: _accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Attachment handling methods
  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      
      if (image != null) {
        await _uploadAttachment(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to capture image: $e');
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        await _uploadAttachment(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _uploadAttachment(file);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to pick file: $e');
      }
    }
  }

  Future<void> _uploadAttachment(File file) async {
    // Check file size (max 10MB)
    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {
      if (mounted) {
        context.showWarningSnackbar('File size must be less than 10MB');
      }
      return;
    }

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final userId = 'demo_user';
      final reminderId = widget.reminderToEdit?.id ?? 
          DateTime.now().millisecondsSinceEpoch.toString();
      
      final attachmentData = await _fileStorageService.uploadFile(
        file: file,
        userId: userId,
        reminderId: reminderId,
      );

      setState(() {
        _attachments.add(attachmentData);
        _isUploadingAttachment = false;
      });

      if (mounted) {
        context.showSuccessSnackbar('Attachment added successfully');
      }
    } catch (e) {
      setState(() {
        _isUploadingAttachment = false;
      });
      
      if (mounted) {
        context.showErrorSnackbar('Failed to upload attachment: $e');
      }
    }
  }

  Future<void> _removeAttachment(int index) async {
    final attachment = _attachments[index];
    
    try {
      // Delete from storage if it has a storagePath
      if (attachment['storagePath'] != null) {
        await _fileStorageService.deleteFile(attachment['storagePath']);
      }
      
      setState(() {
        _attachments.removeAt(index);
      });
      
      if (mounted) {
        context.showSuccessSnackbar('Attachment removed');
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar('Failed to remove attachment: $e');
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final cardColor = _isDarkMode 
            ? const Color.fromARGB(255, 33, 36, 39) 
            : Colors.white;
        final textColor = _isDarkMode ? Colors.white : Colors.black87;
        
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.r),
              topRight: Radius.circular(24.r),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Add Attachment',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 16.h),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Choose from Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.attach_file,
                  label: 'Choose File',
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final textColor = _isDarkMode ? Colors.white : Colors.black87;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Row(
          children: [
            Icon(icon, color: _accentColor, size: 24.sp),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'document':
        return Icons.description;
      case 'video':
        return Icons.video_library;
      case 'audio':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  List<Map<String, String>> _generateNextOccurrences() {
    if (!_repeatEnabled) return [];

    final rule = _buildRule();
    final occurrences = <Map<String, String>>[];
    DateTime? cursor = rule.nextOccurrence(from: DateTime.now());
    int safety = 0;

    while (cursor != null && occurrences.length < 3 && safety < 12) {
      occurrences.add({
        'title': DateFormat('EEEE, MMM dd').format(cursor),
        'subtitle': _relativeSubtitle(cursor),
        'time': DateFormat('hh:mm a').format(cursor),
      });

      cursor = rule.nextOccurrence(
        from: cursor.add(const Duration(minutes: 1)),
      );
      safety++;
    }

    return occurrences;
  }

  String _relativeSubtitle(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);
    final days = diff.inDays;
    if (days <= 0) {
      final hours = diff.inHours;
      if (hours <= 0) {
        return 'In less than 1 hour';
      }
      return 'In $hours hour${hours == 1 ? '' : 's'}';
    }
    return 'In $days day${days == 1 ? '' : 's'}';
  }

  List<TextSpan> _buildSummaryTextSpans(Color textColor) {
    final List<TextSpan> spans = [];
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    // [Reminder name]
    final reminderText = _reminderController.text.trim().isEmpty
        ? '.....'
        : _reminderController.text.trim();
    spans.add(
      TextSpan(
        text: reminderText,
        style: TextStyle(
          color: _accentColor,
          fontWeight: FontWeight.w600,
          decoration: reminderText == '.....'
              ? TextDecoration.none
              : TextDecoration.underline,
          decorationColor: _accentColor,
        ),
      ),
    );

    // " at"
    spans.add(
      TextSpan(
        text: ' at ',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );

    // Time
    final hour = _selectedTime.hourOfPeriod == 0
        ? 12
        : _selectedTime.hourOfPeriod;
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    final period = _selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    spans.add(
      TextSpan(
        text: '$hour:$minute $period',
        style: TextStyle(
          color: _accentColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _accentColor,
        ),
      ),
    );

    // Date part
    if (_repeatEnabled) {
      spans.add(
        TextSpan(
          text: ' starting from ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      );
    } else {
      spans.add(
        TextSpan(
          text: isToday ? ' today' : ' on ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      );
    }

    if (!isToday || _repeatEnabled) {
      final dateText = DateFormat('MMM dd, yyyy').format(_selectedDate);
      spans.add(
        TextSpan(
          text: dateText,
          style: TextStyle(
            color: _accentColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _accentColor,
          ),
        ),
      );
    }

    // Repeat part
    if (_repeatEnabled) {
      String frequencyText = '';
      switch (_selectedFrequency) {
        case RecurrenceFrequency.hourly:
          final totalMinutes =
              (_hourlyIntervalHours * 60) + _hourlyIntervalMinutes;
          if (totalMinutes == 60) {
            frequencyText = 'hourly';
          } else if (totalMinutes < 60) {
            frequencyText = 'every $_hourlyIntervalMinutes minutes';
          } else if (totalMinutes % 60 == 0) {
            frequencyText = 'every $_hourlyIntervalHours hours';
          } else {
            frequencyText =
                'every ${_hourlyIntervalHours}h ${_hourlyIntervalMinutes}m';
          }
          break;
        case RecurrenceFrequency.daily:
          frequencyText = 'daily';
          break;
        case RecurrenceFrequency.weekly:
          frequencyText = 'weekly';
          break;
        case RecurrenceFrequency.monthly:
          frequencyText = 'monthly';
          break;
        case RecurrenceFrequency.yearly:
          frequencyText = 'yearly';
          break;
      }

      spans.add(
        TextSpan(
          text: ', repeating ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      );

      spans.add(
        TextSpan(
          text: frequencyText,
          style: TextStyle(
            color: _accentColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: _accentColor,
          ),
        ),
      );

      if (_endDateEnabled && _endDate != null) {
        spans.add(
          TextSpan(
            text: ' until ',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
        );

        spans.add(
          TextSpan(
            text: DateFormat('MMM dd, yyyy').format(_endDate!),
            style: TextStyle(
              color: _accentColor,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: _accentColor,
            ),
          ),
        );
      }
    }

    spans.add(
      TextSpan(
        text: '.',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );

    return spans;
  }

  RecurrenceRule _buildRule() {
    // Auto-convert 24 hours to daily
    RecurrenceFrequency effectiveFrequency = _selectedFrequency;
    int effectiveIntervalHours = _hourlyIntervalHours;
    int effectiveIntervalMinutes = _hourlyIntervalMinutes;

    if (_selectedFrequency == RecurrenceFrequency.hourly) {
      final totalHours = _hourlyIntervalHours + (_hourlyIntervalMinutes / 60);
      if (totalHours >= 24) {
        effectiveFrequency = RecurrenceFrequency.daily;
        effectiveIntervalHours = 1;
        effectiveIntervalMinutes = 0;
      }
    }

    return RecurrenceRule(
      frequency: effectiveFrequency,
      selectedWeekDays: _selectedDays,
      timeOfDay: _selectedTime,
      startDate: _selectedDate,
      endDate: _endDateEnabled ? _endDate : null,
      intervalHours: effectiveIntervalHours,
      intervalMinutes: effectiveIntervalMinutes,
    );
  }

  Future<void> _saveReminder() async {
    if (_isSaving) return;

    final reminderText = _reminderController.text.trim();
    if (reminderText.isEmpty) {
      context.showWarningSnackbar('Please enter a reminder name');
      return;
    }

    // Validate hourly interval
    if (_repeatEnabled && _selectedFrequency == RecurrenceFrequency.hourly) {
      if (_hourlyIntervalHours == 0 && _hourlyIntervalMinutes == 0) {
        context.showWarningSnackbar('Please set an interval greater than 0');
        return;
      }
    }

    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    RecurrenceRule? recurrenceRule;
    DateTime finalScheduledTime = scheduledDateTime;

    if (_repeatEnabled) {
      recurrenceRule = _buildRule();
      final nextOccurrence = recurrenceRule.nextOccurrence(
        from: DateTime.now(),
      );

      if (nextOccurrence == null) {
        context.showWarningSnackbar(
          'Recurrence ends before today. Please adjust dates.',
        );
        return;
      }

      finalScheduledTime = nextOccurrence;
    }

    if (finalScheduledTime.isBefore(DateTime.now())) {
      context.showWarningSnackbar('Please select a future date and time');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.reminderToEdit != null) {
        // Edit mode - check if it's a recurring reminder
        final isRecurring = widget.reminderToEdit!.recurrence != null;

        EditRecurringOption? editOption;
        if (isRecurring) {
          // Show dialog to ask user how to apply changes
          editOption = await EditRecurringDialog.show(
            context: context,
            reminderName: reminderText,
            accentColor: _accentColor,
            isDarkMode: _isDarkMode,
          );

          // User cancelled the dialog
          if (editOption == null) {
            setState(() {
              _isSaving = false;
            });
            return;
          }
        }

        // Prepare updates
        final updates = <String, dynamic>{
          if (_selectedCustomIconUrl != null)
            'customIconUrl': _selectedCustomIconUrl
          else
            'iconCodePoint': _selectedIcon.codePoint,
          'colorValue': _selectedColor.value,
          'autoSnoozeEnabled': _autoSnoozeEnabled,
          'autoSnoozeInterval': _autoSnoozeInterval,
          'autoSnoozeMaxCount': _autoSnoozeMaxCount,
          'attachments': _attachments.isNotEmpty ? _attachments : null,
        };

        if (isRecurring &&
            editOption == EditRecurringOption.thisOccurrenceOnly) {
          // Create override for this occurrence only
          final occurrenceDate = DateFormat(
            'yyyy-MM-dd',
          ).format(scheduledDateTime);
          final timeStr =
              '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

          // Get existing overrides or create new map
          final existingOverrides = widget.reminderToEdit!.overrides ?? {};
          final newOverrides = Map<String, Map<String, dynamic>>.from(
            existingOverrides,
          );

          // Create or update override for this date
          newOverrides[occurrenceDate] = {
            'time': timeStr,
            if (reminderText != widget.reminderToEdit!.name)
              'title': reminderText,
          };

          updates['overrides'] = newOverrides;

          // Don't update base fields (name, recurrence, etc.) for single occurrence
        } else {
          // Update the entire series (or non-recurring reminder)
          updates['name'] = reminderText;
          updates['time'] = Timestamp.fromDate(finalScheduledTime);

          if (recurrenceRule != null) {
            updates['recurrence'] = recurrenceRule.toBackendConfig();
            updates['nextDueAt'] = Timestamp.fromDate(finalScheduledTime);
          } else {
            updates['recurrence'] = null;
            updates['nextDueAt'] = null;
          }
        }

        await _reminderService.updateReminder(
          widget.reminderToEdit!.id,
          updates,
        );

        if (mounted) {
          Navigator.pop(context, true); // Return true to indicate update
          context.showSuccessSnackbar(
            isRecurring && editOption == EditRecurringOption.thisOccurrenceOnly
                ? 'Reminder occurrence updated!'
                : 'Reminder updated successfully!',
          );
        }
      } else {
        // Create mode - add new reminder
        final reminder = Reminder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: reminderText,
          time: finalScheduledTime,
          nextDueAt: recurrenceRule != null ? finalScheduledTime : null,
          recurrence: recurrenceRule?.toBackendConfig(),
          isCompleted: false,
          deviceToken: _notificationService.fcmToken,
          userId: 'demo_user',
          iconCodePoint: _selectedCustomIconUrl == null
              ? _selectedIcon.codePoint
              : null,
          customIconUrl: _selectedCustomIconUrl,
          colorValue: _selectedColor.value,
          autoSnoozeEnabled: _autoSnoozeEnabled,
          autoSnoozeInterval: _autoSnoozeInterval,
          autoSnoozeMaxCount: _autoSnoozeMaxCount,
          autoSnoozeCount: 0,
          attachments: _attachments.isNotEmpty ? _attachments : null,
        );

        final reminderId = await _reminderService.addReminder(
          reminder,
          _notificationService.fcmToken,
        );

        final savedReminder = reminder.copyWith(id: reminderId);
        await _notificationService.scheduleReminderNotification(savedReminder);

        if (mounted) {
          Navigator.pop(context, savedReminder);
          context.showSuccessSnackbar('Reminder created successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(
          widget.reminderToEdit != null
              ? 'Error updating reminder: $e'
              : 'Error creating reminder: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    // Check pro access for voice feature
    final hasPro = await _proStatusService.hasProAccess();
    if (!hasPro) {
      if (mounted) {
        final shouldUpgrade = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            title: Row(
              children: [
                Icon(Icons.star_rounded, color: _accentColor, size: 24.sp),
                SizedBox(width: 8.w),
                Text(
                  'Pro Feature',
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
            content: Text(
              'Voice reminders are a Pro feature. Upgrade to unlock voice input and many other premium features!',
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Not Now', style: TextStyle(color: _accentColor)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Upgrade to Pro'),
              ),
            ],
          ),
        );

        if (shouldUpgrade == true && mounted) {
          // Navigate to subscription screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CueProPaywallScreen(),
            ),
          );
        }
      }
      return;
    }

    if (_isRecording) {
      await _stopVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    print('🎙️ CreateReminder: _startVoiceRecording() called');
    try {
      print('🎙️ CreateReminder: Calling whisperService.startRecording()...');
      await _whisperService.startRecording();
      print('🎙️ CreateReminder: Recording started successfully');
      setState(() {
        _isRecording = true;
        _showVoiceHint = false;
      });
      _glowController.stop();
    } catch (e) {
      print('🎙️ CreateReminder: ERROR in startRecording: $e');
      print('🎙️ CreateReminder: Error type: ${e.runtimeType}');
      final errorMsg = e.toString();
      if (mounted) {
        // Check if error is permission-related
        if (errorMsg.contains('permission') || errorMsg.contains('Settings')) {
          print('🎙️ CreateReminder: Showing permission dialog');
          // Show dialog for permission issues
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Microphone Access Required'),
              content: Text(
                errorMsg.replaceAll('Exception: ', ''),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
        } else {
          context.showErrorSnackbar('Failed to start recording: ${errorMsg.replaceAll('Exception: ', '')}');
        }
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      setState(() {
        _isRecording = false;
        _isProcessingVoice = true;
      });

      final File? audioFile = await _whisperService.stopRecording();

      if (audioFile == null) {
        setState(() => _isProcessingVoice = false);
        if (mounted) {
          context.showWarningSnackbar('Recording too short');
        }
        return;
      }

      final transcription = await _whisperService.transcribeWithWhisper(
        audioFile,
      );

      if (transcription == null || transcription.isEmpty) {
        setState(() => _isProcessingVoice = false);
        if (mounted) {
          context.showWarningSnackbar('Could not understand speech');
        }
        return;
      }

      final parseResult = await _chatGPTService.parseReminderFromVoice(
        transcription,
      );

      if (parseResult == null) {
        setState(() => _isProcessingVoice = false);
        if (mounted) {
          context.showWarningSnackbar('Could not parse reminder');
        }
        return;
      }

      // Fill in the fields
      setState(() {
        _reminderController.text = parseResult.reminderText;
        _selectedDate = DateTime(
          parseResult.scheduledTime.year,
          parseResult.scheduledTime.month,
          parseResult.scheduledTime.day,
        );
        _selectedTime = TimeOfDay.fromDateTime(parseResult.scheduledTime);
        _isProcessingVoice = false;
      });

      if (mounted) {
        context.showSuccessSnackbar('Voice input processed!');
      }
    } catch (e) {
      setState(() => _isProcessingVoice = false);
      if (mounted) {
        context.showErrorSnackbar('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match home screen colors
    final backgroundColor = _backgroundColor ?? (_isDarkMode
        ? Color.lerp(const Color(0xFF121212), _accentColor, 0.08)!
        : Color.lerp(const Color(0xFFFAF5F3), _accentColor, 0.05)!);

    final cardColor = _isDarkMode
        ? Color.lerp(const Color(0xFF1E1E1E), _accentColor, 0.1)!
        : Colors.white;

    final tnText = ThemeNotifier.instance.textColor;
    final textColor = tnText ?? (_isDarkMode ? Colors.white : const Color(0xFF2D2D2D));
    final subtitleColor = _isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);

    final dividerColor = _isDarkMode
        ? const Color.fromARGB(255, 44, 48, 53)
        : Colors.grey.withOpacity(0.2);

    final inputBgColor = _isDarkMode
        ? const Color(0xFF1A1F2E)
        : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Icon(Icons.close, color: textColor, size: 24.sp),
        ),
        centerTitle: true,
        title: Text(
          widget.reminderToEdit != null ? 'Edit Reminder' : 'New Reminder',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: 20.r,
                left: 20.r,
                right: 20.r,
                bottom: 325.r, // Extra padding for the save button
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dynamic Summary Text
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 22.sp,
                        height: 1.4,
                        color: textColor,
                      ),
                      children: _buildSummaryTextSpans(textColor),
                    ),
                  ),

                  SizedBox(height: 32.h),

                  // Voice hint banner
                  if (_showVoiceHint)
                    Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _accentColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: _accentColor, size: 20.sp),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Try Voice Input!',
                                  style: TextStyle(
                                    color: _accentColor,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tap the mic and say: "Remind me to call John at 3pm"',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: subtitleColor,
                              size: 18.sp,
                            ),
                            onPressed: () {
                              setState(() => _showVoiceHint = false);
                              _glowController.stop();
                            },
                          ),
                        ],
                      ),
                    ),

                  // Main container for all controls
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reminder Name with Mic Button
                        Padding(
                          padding: EdgeInsets.all(12.r),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  cursorColor: _accentColor,
                                  controller: _reminderController,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 24.sp,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'What needs your attention?',
                                    hintStyle: TextStyle(
                                      color: subtitleColor.withOpacity(0.5),
                                      fontStyle: FontStyle.italic,
                                      fontSize: 20.sp,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (_) {
                                    setState(() {});
                                  },
                                ),
                              ),
                              SizedBox(width: 12.w),
                              // Mic Button with glow
                              AnimatedBuilder(
                                animation: _glowAnimation,
                                builder: (context, child) {
                                  return GestureDetector(
                                    onTap: _isProcessingVoice
                                        ? null
                                        : _toggleVoiceRecording,
                                    child: Container(
                                      width: 44.w,
                                      height: 44.h,
                                      decoration: BoxDecoration(
                                        color: _isRecording
                                            ? _accentColor.withOpacity(0.2)
                                            : inputBgColor,
                                        shape: BoxShape.circle,
                                        border: _isRecording
                                            ? Border.all(
                                                color: _accentColor,
                                                width: 2,
                                              )
                                            : null,
                                        boxShadow:
                                            _showVoiceHint && !_isRecording
                                            ? [
                                                BoxShadow(
                                                  color: _accentColor
                                                      .withOpacity(
                                                        _glowAnimation.value *
                                                            0.5,
                                                      ),
                                                  blurRadius:
                                                      12 * _glowAnimation.value,
                                                  spreadRadius:
                                                      2 * _glowAnimation.value,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: _isProcessingVoice
                                          ? Padding(
                                              padding: EdgeInsets.all(12.r),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                      _accentColor,
                                                    ),
                                              ),
                                            )
                                          : Icon(
                                              _isRecording
                                                  ? Icons.stop
                                                  : Icons.mic,
                                              color: _isRecording
                                                  ? _accentColor
                                                  : (_showVoiceHint
                                                        ? _accentColor
                                                        : textColor),
                                              size: 22.sp,
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Divider(color: dividerColor, height: 1.h),

                        // Main container for all controls
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Selector
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Date',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _selectDate,
                                      borderRadius: BorderRadius.circular(20.r),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.h,
                                          horizontal: 16.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: inputBgColor,
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              DateFormat(
                                                'MMM dd, yyyy',
                                              ).format(_selectedDate),
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Icon(
                                              Icons.calendar_today,
                                              color: subtitleColor,
                                              size: 16.sp,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Divider(color: dividerColor, height: 1.h),

                              // Time Selector
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Time',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _selectTime,
                                      borderRadius: BorderRadius.circular(20.r),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.h,
                                          horizontal: 16.w,
                                        ),
                                        decoration: BoxDecoration(
                                          color: inputBgColor,
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              () {
                                                final hour =
                                                    _selectedTime
                                                            .hourOfPeriod ==
                                                        0
                                                    ? 12
                                                    : _selectedTime
                                                          .hourOfPeriod;
                                                final minute = _selectedTime
                                                    .minute
                                                    .toString()
                                                    .padLeft(2, '0');
                                                final period =
                                                    _selectedTime.period ==
                                                        DayPeriod.am
                                                    ? 'AM'
                                                    : 'PM';
                                                return '$hour:$minute $period';
                                              }(),
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Icon(
                                              Icons.access_time,
                                              color: subtitleColor,
                                              size: 18.sp,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Divider(color: dividerColor, height: 1.h),

                              // Icon & Color - Combined in one row
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Icon & Color',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Icon Button
                                        InkWell(
                                          onTap: _openIconPicker,
                                          borderRadius: BorderRadius.circular(
                                            20.r,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.all(12.r),
                                            decoration: BoxDecoration(
                                              color: inputBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(20.r),
                                            ),
                                            child:
                                                _selectedCustomIconUrl != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8.r,
                                                        ),
                                                    child: Image.network(
                                                      _selectedCustomIconUrl!,
                                                      width: 24.w,
                                                      height: 24.h,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return Icon(
                                                              Icons
                                                                  .notification_important_outlined,
                                                              color:
                                                                  _selectedColor,
                                                              size: 24.sp,
                                                            );
                                                          },
                                                    ),
                                                  )
                                                : Icon(
                                                    _selectedIcon,
                                                    color: _selectedColor,
                                                    size: 24.sp,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        // Color Button (hidden when a custom icon is selected)
                                        if (_selectedCustomIconUrl == null)
                                          InkWell(
                                            onTap: _openColorPicker,
                                            borderRadius: BorderRadius.circular(
                                              20.r,
                                            ),
                                            child: Container(
                                              width: 48.w,
                                              height: 48.h,
                                              decoration: BoxDecoration(
                                                color: _selectedColor,
                                                borderRadius:
                                                    BorderRadius.circular(20.r),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              Divider(color: dividerColor, height: 1.h),

                              // Attachments Section
                              Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Attachments',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: _showAttachmentOptions,
                                          borderRadius:
                                              BorderRadius.circular(20.r),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accentColor
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20.r),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.add,
                                                  color: _accentColor,
                                                  size: 18.sp,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  'Add',
                                                  style: TextStyle(
                                                    color: _accentColor,
                                                    fontSize: 14.sp,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_isUploadingAttachment) ...[
                                      SizedBox(height: 12.h),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 16.w,
                                            height: 16.h,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      _accentColor),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            'Uploading...',
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 14.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (_attachments.isNotEmpty) ...[
                                      SizedBox(height: 12.h),
                                      ...List.generate(_attachments.length,
                                          (index) {
                                        final attachment = _attachments[index];
                                        final fileType =
                                            attachment['type'] ?? 'file';
                                        final fileName =
                                            attachment['name'] ?? 'Unknown';
                                        final fileSize =
                                            attachment['size'] ?? 0;
                                        
                                        return Container(
                                          margin: EdgeInsets.only(bottom: 8.h),
                                          padding: EdgeInsets.all(12.r),
                                          decoration: BoxDecoration(
                                            color: inputBgColor,
                                            borderRadius:
                                                BorderRadius.circular(12.r),
                                          ),
                                          child: Row(
                                            children: [
                                              // File type icon or image preview
                                              if (fileType == 'image')
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8.r),
                                                  child: Image.network(
                                                    attachment['url'],
                                                    width: 48.w,
                                                    height: 48.h,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error,
                                                        stackTrace) {
                                                      return Container(
                                                        width: 48.w,
                                                        height: 48.h,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: _accentColor
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  8.r),
                                                        ),
                                                        child: Icon(
                                                          Icons.image,
                                                          color: _accentColor,
                                                          size: 24.sp,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                )
                                              else
                                                Container(
                                                  width: 48.w,
                                                  height: 48.h,
                                                  decoration: BoxDecoration(
                                                    color: _accentColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.r),
                                                  ),
                                                  child: Icon(
                                                    _getFileIcon(fileType),
                                                    color: _accentColor,
                                                    size: 24.sp,
                                                  ),
                                                ),
                                              SizedBox(width: 12.w),
                                              // File info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      fileName,
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 14.sp,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 2.h),
                                                    Text(
                                                      FileStorageService
                                                          .formatFileSize(
                                                              fileSize),
                                                      style: TextStyle(
                                                        color: subtitleColor,
                                                        fontSize: 12.sp,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Delete button
                                              IconButton(
                                                icon: Icon(
                                                  Icons.close,
                                                  color: Colors.red,
                                                  size: 20.sp,
                                                ),
                                                onPressed: () =>
                                                    _removeAttachment(index),
                                                padding: EdgeInsets.zero,
                                                constraints: BoxConstraints(
                                                  minWidth: 32.w,
                                                  minHeight: 32.h,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ],
                                ),
                              ),

                              Divider(color: dividerColor, height: 1.h),

                              // Repeat Switch
                              Padding(
                                key: _repeatSwitchKey,
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Repeat',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Switch(
                                      value: _repeatEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _repeatEnabled = value;
                                        });
                                      },
                                      activeColor: _accentColor,
                                    ),
                                  ],
                                ),
                              ),

                              Divider(color: dividerColor, height: 1.h),

                              // Auto-snooze Switch
                              Padding(
                                key: _autoSnoozeSwitchKey,
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-snooze',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Snooze if no response',
                                          style: TextStyle(
                                            color: subtitleColor,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: _autoSnoozeEnabled,
                                      onChanged: (value) async {
                                        // Check pro access for auto-snooze
                                        if (value) {
                                          final hasPro = await _proStatusService.hasProAccess();
                                          if (!hasPro) {
                                            final shouldUpgrade = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: _isDarkMode 
                                                    ? const Color(0xFF2A2A2A) 
                                                    : Colors.white,
                                                title: Row(
                                                  children: [
                                                    Icon(Icons.star_rounded, color: _accentColor, size: 24.sp),
                                                    SizedBox(width: 8.w),
                                                    Text(
                                                      'Pro Feature',
                                                      style: TextStyle(
                                                        color: _isDarkMode 
                                                            ? Colors.white 
                                                            : const Color(0xFF2D2D2D),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                content: Text(
                                                  'Auto-snooze is a Pro feature. Upgrade to automatically re-notify yourself if you don\'t respond to a reminder!',
                                                  style: TextStyle(
                                                    color: _isDarkMode 
                                                        ? Colors.white70 
                                                        : const Color(0xFF666666),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context, false),
                                                    child: Text('Not Now', style: TextStyle(color: _accentColor)),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(context, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: _accentColor,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    child: const Text('Upgrade to Pro'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (shouldUpgrade == true && mounted) {
                                              // Navigate to subscription screen
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const CueProPaywallScreen(),
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                        }
                                        
                                        setState(() {
                                          _autoSnoozeEnabled = value;
                                        });
                                      },
                                      activeColor: _accentColor,
                                    ),
                                  ],
                                ),
                              ),

                              // Auto-snooze Settings (only show when enabled)
                              if (_autoSnoozeEnabled) ...[
                                Divider(color: dividerColor, height: 1.h),
                                Padding(
                                  padding: EdgeInsets.all(16.r),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Snooze Interval',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          // Add button appears when slider is at max
                                          if (_autoSnoozeInterval >=
                                              _sliderMaxValue)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: _accentColor.withOpacity(
                                                  0.1,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.add,
                                                  color: _accentColor,
                                                  size: 20.sp,
                                                ),
                                                padding: EdgeInsets.all(4.r),
                                                constraints: BoxConstraints(
                                                  minWidth: 32.w,
                                                  minHeight: 32.h,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _sliderMaxValue += 60;
                                                    // Ensure divisions are updated
                                                  });
                                                },
                                                tooltip:
                                                    'Extend range to $_sliderMaxValue-${_sliderMaxValue + 60} min',
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 8.h),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Slider(
                                              value: _autoSnoozeInterval
                                                  .toDouble(),
                                              min: 1,
                                              max: _sliderMaxValue.toDouble(),
                                              divisions: _sliderMaxValue - 1,
                                              label: '$_autoSnoozeInterval min',
                                              activeColor: _accentColor,
                                              onChanged: (value) {
                                                setState(() {
                                                  _autoSnoozeInterval = value
                                                      .toInt();
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            '$_autoSnoozeInterval min',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Max Snoozes',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Slider(
                                              value: _autoSnoozeMaxCount
                                                  .toDouble(),
                                              min: 1,
                                              max: 10,
                                              divisions: 9,
                                              label:
                                                  '$_autoSnoozeMaxCount times',
                                              activeColor: _accentColor,
                                              onChanged: (value) {
                                                setState(() {
                                                  _autoSnoozeMaxCount = value
                                                      .toInt();
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            '$_autoSnoozeMaxCount times',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Recurrence Options Container (separate container when repeat is enabled)
                        if (_repeatEnabled) ...[
                          SizedBox(height: 20.h),
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Frequency Selector
                                Padding(
                                  padding: EdgeInsets.all(18.r),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FREQUENCY',
                                        style: TextStyle(
                                          color: subtitleColor.withOpacity(0.7),
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      SizedBox(height: 12.h),
                                      Row(
                                        children: [
                                          _buildFrequencyChip(
                                            'Hourly',
                                            RecurrenceFrequency.hourly,
                                            cardColor,
                                            textColor,
                                            subtitleColor,
                                            inputBgColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          _buildFrequencyChip(
                                            'Daily',
                                            RecurrenceFrequency.daily,
                                            cardColor,
                                            textColor,
                                            subtitleColor,
                                            inputBgColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          _buildFrequencyChip(
                                            'Weekly',
                                            RecurrenceFrequency.weekly,
                                            cardColor,
                                            textColor,
                                            subtitleColor,
                                            inputBgColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          _buildFrequencyChip(
                                            'Monthly',
                                            RecurrenceFrequency.monthly,
                                            cardColor,
                                            textColor,
                                            subtitleColor,
                                            inputBgColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          _buildFrequencyChip(
                                            'Yearly',
                                            RecurrenceFrequency.yearly,
                                            cardColor,
                                            textColor,
                                            subtitleColor,
                                            inputBgColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Interval Selector (only for hourly)
                                if (_selectedFrequency ==
                                    RecurrenceFrequency.hourly) ...[
                                  Divider(color: dividerColor, height: 1.h),
                                  Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'REPEAT EVERY',
                                          style: TextStyle(
                                            color: subtitleColor.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        GestureDetector(
                                          onTap: () {
                                            _showIntervalPicker(
                                              context,
                                              cardColor,
                                              textColor,
                                              subtitleColor,
                                            );
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16.w,
                                              vertical: 12.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: inputBgColor,
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  _getIntervalText(),
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.arrow_drop_down,
                                                  color: subtitleColor,
                                                  size: 24.sp,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Validation message
                                        if (_hourlyIntervalHours == 0 &&
                                            _hourlyIntervalMinutes == 0) ...[
                                          SizedBox(height: 8.h),
                                          Text(
                                            'Interval must be greater than 0',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                // Days Selector (only for weekly)
                                if (_selectedFrequency ==
                                    RecurrenceFrequency.weekly) ...[
                                  Divider(color: dividerColor, height: 1.h),
                                  Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ON THESE DAYS',
                                          style: TextStyle(
                                            color: subtitleColor.withOpacity(
                                              0.7,
                                            ),
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: List.generate(7, (index) {
                                            final dayIndex = index + 1;
                                            final isSelected = _selectedDays
                                                .contains(dayIndex);
                                            return _buildDayButton(
                                              _dayAbbreviations[index],
                                              dayIndex,
                                              isSelected,
                                              inputBgColor,
                                              textColor,
                                              subtitleColor,
                                            );
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // End Date Section
                                Divider(color: dividerColor, height: 1.h),
                                Padding(
                                  padding: EdgeInsets.all(16.r),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'End Date',
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          if (_endDateEnabled) ...[
                                            InkWell(
                                              onTap: _selectEndDate,
                                              borderRadius:
                                                  BorderRadius.circular(20.r),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8.h,
                                                  horizontal: 16.w,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: inputBgColor,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        20.r,
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _endDate != null
                                                          ? DateFormat(
                                                              'MMM dd, yyyy',
                                                            ).format(_endDate!)
                                                          : 'Select Date',
                                                      style: TextStyle(
                                                        color: textColor,
                                                        fontSize: 14.sp,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8.w),
                                                    Icon(
                                                      Icons.calendar_today,
                                                      color: subtitleColor,
                                                      size: 16.sp,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                          ],
                                          Switch(
                                            value: _endDateEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _endDateEnabled = value;
                                                if (value && _endDate == null) {
                                                  _endDate = _selectedDate.add(
                                                    const Duration(days: 30),
                                                  );
                                                }
                                              });
                                            },
                                            activeColor: _accentColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Next 3 Occurrences (only shown when repeat is enabled)
                        if (_repeatEnabled) ...[
                          SizedBox(height: 32.h),
                          Text(
                            'NEXT 3 OCCURRENCES',
                            style: TextStyle(
                              color: subtitleColor.withOpacity(0.7),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(24.r),
                            ),
                            child: Column(
                              children: () {
                                final occurrences = _generateNextOccurrences();
                                if (occurrences.isEmpty) {
                                  return [
                                    Padding(
                                      padding: EdgeInsets.all(16.r),
                                      child: Text(
                                        'No occurrences found',
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ];
                                }
                                return occurrences.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final occurrence = entry.value;
                                  final isLast =
                                      index == occurrences.length - 1;

                                  return Column(
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(16.r),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  occurrence['title']!,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 16.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 4.h),
                                                Text(
                                                  occurrence['subtitle']!,
                                                  style: TextStyle(
                                                    color: subtitleColor,
                                                    fontSize: 13.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                vertical: 6.h,
                                                horizontal: 12.w,
                                              ),
                                              decoration: BoxDecoration(
                                                color: inputBgColor,
                                                borderRadius:
                                                    BorderRadius.circular(20.r),
                                              ),
                                              child: Text(
                                                occurrence['time']!,
                                                style: TextStyle(
                                                  color: subtitleColor,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          color: dividerColor,
                                          height: 1.h,
                                        ),
                                    ],
                                  );
                                }).toList();
                              }(),
                            ),
                          ),
                        ],

                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.reminderToEdit == null || _hasChanges())
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StickySaveButton(
                onPressed: _saveReminder,
                onCancel: widget.reminderToEdit != null
                    ? _resetToInitial
                    : null,
                showCancel: widget.reminderToEdit != null,
                isLoading: _isSaving,
                accentColor: _accentColor,
                isDarkMode: _isDarkMode,
              ),
            ),
          // Tutorial overlays
          if (_showRepeatTutorial && _repeatSwitchKey.currentContext != null)
            TutorialOverlay(
              targetKey: _repeatSwitchKey,
              title: 'Repeat Reminders',
              description:
                  'Enable repeat to make this reminder recur daily, weekly, or on a custom schedule. Perfect for habits and regular tasks!',
              onSkip: _onRepeatTutorialSkip,
              onNext: _onRepeatTutorialNext,
              isLastStep: false,
              accentColor: _accentColor,
              isDarkMode: _isDarkMode,
              highlightPadding: EdgeInsets.all(8.w),
            ),
          if (_showAutoSnoozeTutorial &&
              _autoSnoozeSwitchKey.currentContext != null)
            TutorialOverlay(
              targetKey: _autoSnoozeSwitchKey,
              title: 'Auto-Snooze',
              description:
                  'Enable auto-snooze to automatically remind you again if you don\'t respond to a notification. Great for important tasks!',
              onSkip: _onAutoSnoozeTutorialSkip,
              onNext: _onAutoSnoozeTutorialNext,
              isLastStep: true,
              accentColor: _accentColor,
              isDarkMode: _isDarkMode,
              highlightPadding: EdgeInsets.all(8.w),
            ),
        ],
      ),
    );
  }

  Widget _buildFrequencyChip(
    String label,
    RecurrenceFrequency frequency,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
    Color inputBgColor,
  ) {
    final isSelected = _selectedFrequency == frequency;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFrequency = frequency;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : inputBgColor,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : subtitleColor,
                fontSize: 14.sp,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayButton(
    String label,
    int dayIndex,
    bool isSelected,
    Color inputBgColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return GestureDetector(
      onTap: () => _toggleDay(dayIndex),
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: isSelected ? _accentColor.withOpacity(0.3) : inputBgColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: _accentColor, width: 2.w)
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : subtitleColor,
              fontSize: 14.sp,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  String _getIntervalText() {
    if (_hourlyIntervalHours == 0 && _hourlyIntervalMinutes == 0) {
      return 'Select interval';
    }

    if (_hourlyIntervalHours == 0) {
      return '$_hourlyIntervalMinutes minutes';
    } else if (_hourlyIntervalMinutes == 0) {
      return '$_hourlyIntervalHours ${_hourlyIntervalHours == 1 ? 'hour' : 'hours'}';
    } else {
      return '$_hourlyIntervalHours ${_hourlyIntervalHours == 1 ? 'hour' : 'hours'} $_hourlyIntervalMinutes min';
    }
  }

  void _showIntervalPicker(
    BuildContext context,
    Color cardColor,
    Color textColor,
    Color subtitleColor,
  ) {
    int tempHours = _hourlyIntervalHours;
    int tempMinutes = _hourlyIntervalMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 280.h,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20.r),
              topRight: Radius.circular(20.r),
            ),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: subtitleColor, fontSize: 16.sp),
                      ),
                    ),
                    Text(
                      'Select Interval',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Validate that total doesn't exceed 24 hours
                        final totalHours = tempHours + (tempMinutes / 60);
                        if (totalHours <= 24) {
                          setState(() {
                            _hourlyIntervalHours = tempHours;
                            _hourlyIntervalMinutes = tempMinutes;
                          });
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1.h, color: subtitleColor.withOpacity(0.2)),
              // Picker
              Expanded(
                child: Row(
                  children: [
                    // Hours picker
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: tempHours,
                        ),
                        itemExtent: 40.h,
                        onSelectedItemChanged: (index) {
                          SystemSound.play(SystemSoundType.click);
                          HapticFeedback.lightImpact();
                          tempHours = index;
                        },
                        children: List.generate(
                          24,
                          (index) => Center(
                            child: Text(
                              '$index',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'hours',
                      style: TextStyle(color: textColor, fontSize: 16.sp),
                    ),
                    SizedBox(width: 20.w),
                    // Minutes picker
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: [
                            0,
                            5,
                            10,
                            15,
                            20,
                            30,
                            45,
                          ].indexOf(tempMinutes),
                        ),
                        itemExtent: 40.h,
                        onSelectedItemChanged: (index) {
                          tempMinutes = [0, 5, 10, 15, 20, 30, 45][index];
                        },
                        children: [0, 5, 10, 15, 20, 30, 45].map((min) {
                          return Center(
                            child: Text(
                              '$min',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 20.sp,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Text(
                      'min',
                      style: TextStyle(color: textColor, fontSize: 16.sp),
                    ),
                    SizedBox(width: 20.w),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
