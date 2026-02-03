import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Tutorial overlay that blurs the screen and highlights a specific element
class TutorialOverlay extends StatefulWidget {
  /// The global key of the widget to highlight
  final GlobalKey targetKey;

  /// Title of the tutorial step
  final String title;

  /// Description text for the tutorial step
  final String description;

  /// Callback when skip is pressed
  final VoidCallback onSkip;

  /// Callback when next/got it is pressed
  final VoidCallback onNext;

  /// Whether this is the last step (shows "Got it!" instead of "Next")
  final bool isLastStep;

  /// Accent color for the UI
  final Color accentColor;

  /// Whether dark mode is enabled
  final bool isDarkMode;

  /// Additional padding around the highlighted widget
  final EdgeInsets highlightPadding;

  const TutorialOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.onSkip,
    required this.onNext,
    this.isLastStep = false,
    required this.accentColor,
    required this.isDarkMode,
    this.highlightPadding = const EdgeInsets.all(8),
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  Rect? _targetRect;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateTargetRect() {
    final RenderBox? targetRenderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayRenderBox =
        context.findRenderObject() as RenderBox?;

    if (targetRenderBox != null && overlayRenderBox != null) {
      final globalPosition = targetRenderBox.localToGlobal(Offset.zero);
      final localPosition = overlayRenderBox.globalToLocal(globalPosition);

      setState(() {
        _targetRect = Rect.fromLTWH(
          localPosition.dx - widget.highlightPadding.left,
          localPosition.dy - widget.highlightPadding.top,
          targetRenderBox.size.width +
              widget.highlightPadding.left +
              widget.highlightPadding.right,
          targetRenderBox.size.height +
              widget.highlightPadding.top +
              widget.highlightPadding.bottom,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurred backdrop with spotlight
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(opacity: _fadeAnimation.value, child: child);
            },
            child: _buildBlurredBackdrop(),
          ),

          // Tutorial dialog
          if (_targetRect != null) _buildTutorialDialog(),
        ],
      ),
    );
  }

  Widget _buildBlurredBackdrop() {
    return Stack(
      children: [
        // Backdrop blur with cutout for spotlight
        if (_targetRect != null)
          ClipPath(
            clipper: InvertedRectClipper(_targetRect!),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          )
        else
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

        // Dark overlay with spotlight cutout
        if (_targetRect != null)
          CustomPaint(
            painter: SpotlightPainter(
              targetRect: _targetRect!,
              accentColor: widget.accentColor,
            ),
            size: Size.infinite,
          ),
      ],
    );
  }

  Widget _buildTutorialDialog() {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.85;
    final estimatedDialogHeight = 250.h;

    // Calculate dialog position
    double dialogTop;
    bool showAbove = false;

    if (_targetRect != null) {
      // Calculate available space
      final spaceBelow = screenSize.height - _targetRect!.bottom;
      final spaceAbove = _targetRect!.top;

      if (spaceBelow >= estimatedDialogHeight + 40.h) {
        // Enough space below
        dialogTop = _targetRect!.bottom + 20.h;
        showAbove = false;
      } else if (spaceAbove >= estimatedDialogHeight + 40.h) {
        // Position above
        dialogTop = _targetRect!.top - estimatedDialogHeight - 20.h;
        showAbove = true;
      } else {
        // Not enough space either side, position below and allow scroll
        dialogTop = _targetRect!.bottom + 20.h;
      }
    } else {
      dialogTop = screenSize.height / 2 - 150.h;
    }

    return Positioned(
      left: (screenSize.width - dialogWidth) / 2,
      top: dialogTop,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            color: widget.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with skip button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: widget.isDarkMode
                            ? Colors.white
                            : const Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSkip,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: widget.isDarkMode
                            ? Colors.white70
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12.h),

              // Description
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.5,
                  color: widget.isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : const Color(0xFF6B6B6B),
                ),
              ),

              SizedBox(height: 24.h),

              // Next/Got it button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    widget.isLastStep ? 'Got it!' : 'Next',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clipper to invert a rectangle (exclude it from clipping)
class InvertedRectClipper extends CustomClipper<Path> {
  final Rect excludeRect;

  InvertedRectClipper(this.excludeRect);

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(excludeRect, const Radius.circular(16)),
      )
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(InvertedRectClipper oldClipper) {
    return oldClipper.excludeRect != excludeRect;
  }
}

/// Custom painter for the spotlight effect
class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final Color accentColor;

  SpotlightPainter({required this.targetRect, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a path for the entire screen
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create rounded rectangle for the spotlight
    final spotlightPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect, const Radius.circular(16)),
      );

    // Subtract spotlight from the full screen path
    final cutoutPath = Path.combine(
      PathOperation.difference,
      path,
      spotlightPath,
    );

    // Draw the darkened area
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(cutoutPath, paint);

    // Draw spotlight border
    final borderPaint = Paint()
      ..color = accentColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(16)),
      borderPaint,
    );

    // Draw subtle glow effect
    final glowPaint = Paint()
      ..color = accentColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(16)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.accentColor != accentColor;
  }
}
