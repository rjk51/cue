import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/theme_service.dart';
import '../../../services/theme_notifier.dart';
import '../data/buddy_service.dart';
import '../domain/buddy_pair_model.dart';

class BuddyScreen extends StatefulWidget {
  const BuddyScreen({super.key});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen>
    with TickerProviderStateMixin {
  final BuddyService _buddyService = BuddyService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _codeController = TextEditingController();

  late Color _accentColor;
  late Color? _backgroundColor;
  late bool _isDarkMode;

  bool _isLoading = true;
  bool _isGeneratingCode = false;
  bool _isJoining = false;
  bool _isSendingNudge = false;
  String? _myInviteCode;
  BuddyPair? _buddyPair;
  StreamSubscription? _buddySubscription;
  Timer? _refreshTimer;

  // Buddy progress data
  Map<String, int> _myProgress = {'total': 0, 'completed': 0};
  Map<String, int> _buddyProgress = {'total': 0, 'completed': 0};
  int _myStreak = 0;
  int _buddyStreak = 0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _nudgeController;
  late Animation<double> _nudgeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize theme values synchronously from ThemeNotifier to prevent white flash
    _accentColor = ThemeNotifier.instance.accentColor;
    _backgroundColor = ThemeNotifier.instance.backgroundColor;
    _isDarkMode = ThemeNotifier.instance.isDarkMode;
    
    _loadTheme();
    ThemeNotifier.instance.addListener(_onThemeChanged);
    _initAnimations();
    _loadBuddyData();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _nudgeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _nudgeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _nudgeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _buddySubscription?.cancel();
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _nudgeController.dispose();
    _codeController.dispose();
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
      final platformBrightness = MediaQuery.of(context).platformBrightness;
      setState(() {
        _accentColor = accentColor;
        _backgroundColor = bgColor;
        _isDarkMode = themePreference == 'dark' ||
            (themePreference == 'system' &&
                platformBrightness == Brightness.dark);
      });
    }
  }

  Future<void> _loadBuddyData() async {
    setState(() => _isLoading = true);

    // Listen to buddy pair changes
    _buddySubscription = _buddyService.buddyPairStream().listen((pair) {
      if (mounted) {
        setState(() {
          _buddyPair = pair;
          _isLoading = false;
        });
        if (pair != null) {
          _loadProgressData(pair);
          _startAutoRefresh(pair);
        } else {
          _stopAutoRefresh();
        }
      }
    });
  }

  void _startAutoRefresh(BuddyPair pair) {
    _stopAutoRefresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && _buddyPair != null) {
        _loadProgressData(_buddyPair!);
      }
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _loadProgressData(BuddyPair pair) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final buddyId = pair.getBuddyId(uid);

    final myProgress = await _buddyService.getMyProgress();
    final buddyProgress = await _buddyService.getBuddyProgress(buddyId);
    final myStreak = await _buddyService.getBuddyStreak(uid);
    final buddyStreak = await _buddyService.getBuddyStreak(buddyId);

    if (mounted) {
      setState(() {
        _myProgress = myProgress;
        _buddyProgress = buddyProgress;
        _myStreak = myStreak;
        _buddyStreak = buddyStreak;
      });
    }
  }

  Future<void> _generateCode() async {
    setState(() => _isGeneratingCode = true);
    try {
      final code = await _buddyService.generateInviteCode();
      setState(() => _myInviteCode = code);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGeneratingCode = false);
    }
  }

  Future<void> _joinBuddy() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showSnackbar('Please enter an invite code', isError: true);
      return;
    }

    setState(() => _isJoining = true);
    try {
      await _buddyService.acceptInvite(code);
      HapticFeedback.heavyImpact();
      if (mounted) {
        _showSnackbar('Buddy connected! 🎉');
        _codeController.clear();
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _sendNudge() async {
    if (_buddyPair == null || _isSendingNudge) return;

    setState(() => _isSendingNudge = true);
    try {
      await _buddyService.sendNudge(_buddyPair!);
      HapticFeedback.heavyImpact();
      _nudgeController.forward(from: 0.0);
      if (mounted) {
        _showSnackbar('Nudge sent! 👋');
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSendingNudge = false);
    }
  }

  Future<void> _disconnectBuddy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          'Disconnect Buddy',
          style: TextStyle(
            color: _isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to disconnect from your accountability buddy? This action cannot be undone.',
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Disconnect', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _buddyService.removeBuddy();
      setState(() {
        _buddyPair = null;
        _myInviteCode = null;
      });
      HapticFeedback.mediumImpact();
      if (mounted) _showSnackbar('Buddy disconnected');
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade400 : _accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _backgroundColor ??
        (_isDarkMode ? const Color(0xFF121212) : Colors.white);
    final textColor = _isDarkMode ? Colors.white : const Color(0xFF1A1A1A);
    final subtitleColor =
        _isDarkMode ? Colors.white.withOpacity(0.6) : const Color(0xFF8A8A8A);
    final cardColor = _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: _accentColor),
              )
            : Column(
                children: [
                  _buildHeader(textColor, subtitleColor),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: _buddyPair != null
                          ? _buildBuddyView(textColor, subtitleColor, cardColor)
                          : _buildInviteView(textColor, subtitleColor, cardColor),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subtitleColor) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 8.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _accentColor,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accountability Buddy',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _buddyPair != null ? 'Stay on track together' : 'Find your partner',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          if (_buddyPair != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'disconnect') _disconnectBuddy();
                if (value == 'refresh') {
                  if (_buddyPair != null) _loadProgressData(_buddyPair!);
                }
              },
              icon: Icon(Icons.more_vert_rounded, color: subtitleColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              color: _isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 20.sp, color: _accentColor),
                      SizedBox(width: 12.w),
                      Text('Refresh', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.link_off_rounded, size: 20.sp, color: Colors.red.shade400),
                      SizedBox(width: 12.w),
                      Text('Disconnect', style: TextStyle(color: Colors.red.shade400)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ==================== INVITE VIEW (NO BUDDY) ====================

  Widget _buildInviteView(Color textColor, Color subtitleColor, Color cardColor) {
    return Column(
      children: [
        SizedBox(height: 40.h),

        // Hero illustration
        Container(
          width: 120.w,
          height: 120.w,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.people_rounded,
            size: 60.sp,
            color: _accentColor,
          ),
        ),

        SizedBox(height: 24.h),

        Text(
          'Better Together',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'Pair up with a friend to keep each other accountable. See their progress, compete on streaks, and nudge them when they slack off.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: subtitleColor,
              height: 1.5,
            ),
          ),
        ),

        SizedBox(height: 40.h),

        // Generate invite code section
        _buildInviteCodeCard(textColor, subtitleColor, cardColor),

        SizedBox(height: 20.h),

        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: subtitleColor.withOpacity(0.3))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ),
            Expanded(child: Divider(color: subtitleColor.withOpacity(0.3))),
          ],
        ),

        SizedBox(height: 20.h),

        // Enter buddy's code section
        _buildJoinCodeCard(textColor, subtitleColor, cardColor),

        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildInviteCodeCard(Color textColor, Color subtitleColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.share_rounded,
            color: _accentColor,
            size: 28.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'Share Your Code',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Generate a code and share it with your buddy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 20.h),

          if (_myInviteCode != null) ...[
            // Show the code
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _myInviteCode!));
                HapticFeedback.lightImpact();
                _showSnackbar('Code copied to clipboard!');
              },
              child: _BuddyAnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _accentColor,
                        _accentColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _myInviteCode!,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Icon(Icons.copy_rounded, color: Colors.white70, size: 20.sp),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Tap to copy • Share this with your buddy',
              style: TextStyle(
                fontSize: 12.sp,
                color: subtitleColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else
            GestureDetector(
              onTap: _isGeneratingCode ? null : _generateCode,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accentColor,
                      _accentColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _isGeneratingCode
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Generate Invite Code',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinCodeCard(Color textColor, Color subtitleColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.link_rounded,
            color: _accentColor,
            size: 28.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'Join a Buddy',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter the code your buddy shared with you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: subtitleColor,
            ),
          ),
          SizedBox(height: 20.h),

          // Code input field
          Container(
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: _accentColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 6,
              ),
              decoration: InputDecoration(
                hintText: '------',
                hintStyle: TextStyle(
                  fontSize: 24.sp,
                  color: subtitleColor.withOpacity(0.4),
                  letterSpacing: 6,
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 16.h,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                UpperCaseTextFormatter(),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // Join button
          GestureDetector(
            onTap: _isJoining ? null : _joinBuddy,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: _accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: _isJoining
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: CircularProgressIndicator(
                          color: _accentColor,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BUDDY VIEW (CONNECTED) ====================

  Widget _buildBuddyView(Color textColor, Color subtitleColor, Color cardColor) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final buddyName = _buddyPair!.getBuddyName(uid);
    final buddyInitial = buddyName.isNotEmpty ? buddyName[0].toUpperCase() : '?';

    return Column(
      children: [
        SizedBox(height: 20.h),

        // Buddy profile card
        _buildBuddyProfileCard(buddyName, buddyInitial, textColor, subtitleColor, cardColor),

        SizedBox(height: 24.h),

        // Streak comparison
        _buildStreakComparison(buddyName, textColor, subtitleColor, cardColor),

        SizedBox(height: 24.h),

        // Today's progress comparison
        _buildProgressComparison(buddyName, textColor, subtitleColor, cardColor),

        SizedBox(height: 24.h),

        // Nudge button
        _buildNudgeButton(buddyName, textColor, subtitleColor),

        SizedBox(height: 40.h),
      ],
    );
  }

  Widget _buildBuddyProfileCard(String buddyName, String buddyInitial,
      Color textColor, Color subtitleColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentColor.withOpacity(0.15),
            _accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: _accentColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Buddy avatar
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accentColor, _accentColor.withOpacity(0.7)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                buddyInitial,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buddyName,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Accountability Buddy',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.link_rounded,
            color: _accentColor,
            size: 24.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildStreakComparison(String buddyName, Color textColor,
      Color subtitleColor, Color cardColor) {
    final isWinning = _myStreak >= _buddyStreak;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '🔥 Streak Battle',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              // My streak
              Expanded(
                child: _buildStreakColumn(
                  name: 'You',
                  streak: _myStreak,
                  isWinning: isWinning,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
              // VS divider
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: _accentColor,
                  ),
                ),
              ),
              // Buddy streak
              Expanded(
                child: _buildStreakColumn(
                  name: buddyName.split(' ').first,
                  streak: _buddyStreak,
                  isWinning: !isWinning,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakColumn({
    required String name,
    required int streak,
    required bool isWinning,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Column(
      children: [
        Text(
          streak > 0 ? '🔥' : '❄️',
          style: TextStyle(fontSize: 32.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          '$streak',
          style: TextStyle(
            fontSize: 36.sp,
            fontWeight: FontWeight.w800,
            color: isWinning ? _accentColor : subtitleColor,
          ),
        ),
        Text(
          'days',
          style: TextStyle(
            fontSize: 13.sp,
            color: subtitleColor,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          name,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (isWinning && streak > 0) ...[
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              '👑 Leading',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: _accentColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressComparison(String buddyName, Color textColor,
      Color subtitleColor, Color cardColor) {
    final myCompleted = _myProgress['completed'] ?? 0;
    final myTotal = _myProgress['total'] ?? 0;
    final buddyCompleted = _buddyProgress['completed'] ?? 0;
    final buddyTotal = _buddyProgress['total'] ?? 0;

    final myPercent = myTotal > 0 ? myCompleted / myTotal : 0.0;
    final buddyPercent = buddyTotal > 0 ? buddyCompleted / buddyTotal : 0.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "📊 Today's Progress",
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              // My progress
              Expanded(
                child: _buildProgressRing(
                  name: 'You',
                  completed: myCompleted,
                  total: myTotal,
                  percent: myPercent,
                  color: _accentColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
              SizedBox(width: 24.w),
              // Buddy progress
              Expanded(
                child: _buildProgressRing(
                  name: buddyName.split(' ').first,
                  completed: buddyCompleted,
                  total: buddyTotal,
                  percent: buddyPercent,
                  color: Colors.orange.shade400,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing({
    required String name,
    required int completed,
    required int total,
    required double percent,
    required Color color,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Column(
      children: [
        SizedBox(
          width: 100.w,
          height: 100.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background ring
              SizedBox(
                width: 100.w,
                height: 100.w,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  color: color.withOpacity(0.15),
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Progress ring
              SizedBox(
                width: 100.w,
                height: 100.w,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: percent),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      color: color,
                      strokeCap: StrokeCap.round,
                    );
                  },
                ),
              ),
              // Center text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(percent * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '$completed/$total',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    'completed',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          name,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildNudgeButton(String buddyName, Color textColor, Color subtitleColor) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final canNudge = _buddyPair?.canSendNudge(uid) ?? false;
    final cooldown = _buddyPair?.nudgeCooldownMinutes(uid) ?? 0;

    return _BuddyAnimatedBuilder(
      animation: _nudgeAnimation,
      builder: (context, child) {
        final shake = _nudgeAnimation.value > 0
            ? sin(_nudgeAnimation.value * 3.14 * 4) * 8 * (1 - _nudgeAnimation.value)
            : 0.0;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: canNudge && !_isSendingNudge ? _sendNudge : null,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 20.h),
          decoration: BoxDecoration(
            gradient: canNudge
                ? LinearGradient(
                    colors: [
                      Colors.orange.shade400,
                      Colors.orange.shade600,
                    ],
                  )
                : null,
            color: canNudge ? null : subtitleColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: canNudge
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSendingNudge)
                SizedBox(
                  width: 24.w,
                  height: 24.h,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                Text(
                  '👋',
                  style: TextStyle(fontSize: 24.sp),
                ),
                SizedBox(width: 12.w),
                Text(
                  canNudge
                      ? 'Nudge ${buddyName.split(' ').first}'
                      : 'Nudge in ${cooldown}m',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: canNudge ? Colors.white : subtitleColor,
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

// Helper: forces uppercase input
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Helper: AnimatedBuilder that accepts an Animation
class _BuddyAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const _BuddyAnimatedBuilder({
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
