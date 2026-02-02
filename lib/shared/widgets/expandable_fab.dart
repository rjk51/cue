import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ExpandableFab extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onTextReminderTap;
  final VoidCallback onVoiceReminderTap;

  const ExpandableFab({
    super.key,
    required this.accentColor,
    required this.onTextReminderTap,
    required this.onVoiceReminderTap,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
          // Voice Reminder Button
          _buildExpandingActionButton(
            distance: 80.h,
            icon: Icons.mic,
            label: 'Voice',
            onTap: () {
              _toggle();
              widget.onVoiceReminderTap();
            },
          ),

          // Text Reminder Button
          _buildExpandingActionButton(
            distance: 50.h,
            icon: Icons.edit_outlined,
            label: 'Text',
            onTap: () {
              _toggle();
              widget.onTextReminderTap();
            },
          ),

          // Main FAB
          _buildMainFab(),
        ],
    );
  }

  Widget _buildExpandingActionButton({
    required double distance,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Container(
          margin: EdgeInsets.only(
            bottom: _expandAnimation.value * distance,
          ),
          child: Opacity(
            opacity: _expandAnimation.value,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Label
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                // Button
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      customBorder: const CircleBorder(),
                      child: Icon(
                        icon,
                        color: widget.accentColor,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainFab() {
    return Container(
      width: 64.w,
      height: 64.h,
      decoration: BoxDecoration(
        color: widget.accentColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          customBorder: const CircleBorder(),
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _expandAnimation.value * math.pi / 4, // 45 degrees rotation
                child: Icon(
                  _isExpanded ? Icons.close : Icons.add,
                  color: Colors.white,
                  size: 28.sp,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
