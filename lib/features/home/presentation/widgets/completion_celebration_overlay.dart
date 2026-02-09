import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CompletionCelebrationOverlay extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? customIconUrl;
  final Offset startPosition;
  final VoidCallback onComplete;

  const CompletionCelebrationOverlay({
    super.key,
    required this.icon,
    required this.color,
    this.customIconUrl,
    required this.startPosition,
    required this.onComplete,
  });

  @override
  State<CompletionCelebrationOverlay> createState() =>
      _CompletionCelebrationOverlayState();
}

class _CompletionCelebrationOverlayState
    extends State<CompletionCelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _explosionController;
  late AnimationController _fadeController;
  late AnimationController _pulseController;

  late Animation<Offset> _iconPositionAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Icon fly-in animation (0-300ms)
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final screenCenter = Offset(
      ScreenUtil().screenWidth / 2,
      ScreenUtil().screenHeight / 2,
    );

    _iconPositionAnimation = Tween<Offset>(
      begin: widget.startPosition,
      end: screenCenter,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOutCubic,
    ));

    _iconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 3.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOutBack,
    ));

    // Explosion animation (300-800ms)
    _explosionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // (checkmark animation removed)

    // Background pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade out animation (1200-1500ms)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Haptic feedback at start
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Haptic not available
    }

    // Phase 1: Icon flies to center (0-300ms)
    await _iconController.forward();

    // Haptic feedback when icon reaches center
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      // Haptic not available
    }

    // Phase 2: Explosion and checkmark (300-800ms)
    _generateConfetti();
    _pulseController.forward();
    await _explosionController.forward();

    // Haptic feedback at explosion
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      // Haptic not available
    }

    // Phase 3: Particle float (800-1200ms)
    await Future.delayed(const Duration(milliseconds: 400));

    // Phase 4: Fade out (1200-1500ms)
    await _fadeController.forward();

    // Complete
    widget.onComplete();
  }

  void _generateConfetti() {
    final centerX = ScreenUtil().screenWidth / 2;
    final centerY = ScreenUtil().screenHeight / 2;

    for (int i = 0; i < 60; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 200 + _random.nextDouble() * 300;
      final size = 8 + _random.nextDouble() * 12;

      _particles.add(ConfettiParticle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: size,
        color: widget.color,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
      ));
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _explosionController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _iconController,
        _explosionController,
        _fadeController,
        _pulseController,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Background pulse
                CustomPaint(
                  size: Size(
                    ScreenUtil().screenWidth,
                    ScreenUtil().screenHeight,
                  ),
                  painter: PulsePainter(
                    progress: _pulseController.value,
                    color: widget.color,
                  ),
                ),

                // Confetti particles
                if (_explosionController.value > 0)
                  CustomPaint(
                    size: Size(
                      ScreenUtil().screenWidth,
                      ScreenUtil().screenHeight,
                    ),
                    painter: ConfettiPainter(
                      particles: _particles,
                      progress: _explosionController.value,
                    ),
                  ),

                // Flying icon
                Positioned(
                  left: _iconPositionAnimation.value.dx - 75.w,
                  top: _iconPositionAnimation.value.dy - 75.h,
                  child: Transform.scale(
                    scale: _iconScaleAnimation.value,
                    child: Container(
                      width: 150.w,
                      height: 150.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Main icon
                          widget.customIconUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.customIconUrl!,
                                    width: 150.w,
                                    height: 150.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        widget.icon,
                                        color: widget.color,
                                        size: 80.sp,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  widget.icon,
                                  color: widget.color,
                                  size: 80.sp,
                                ),

                          // (Checkmark removed — keep icon journey, confetti, and pulse)
                        ],
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
}

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  final double size;
  final Color color;
  double rotation;
  final double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;

  ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Physics simulation
    const gravity = 500.0; // pixels per second squared
    const airResistance = 0.98;
    final dt = progress * 0.5; // Time elapsed

    for (final particle in particles) {
      // Update position with physics
      particle.x += particle.vx * dt * progress;
      particle.y += particle.vy * dt * progress + 0.5 * gravity * dt * dt;

      // Apply air resistance
      particle.vx *= airResistance;
      particle.vy *= airResistance;
      particle.vy += gravity * dt * progress;

      // Update rotation
      particle.rotation += particle.rotationSpeed * dt;

      // Draw particle
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.rotate(particle.rotation);

      paint.color = particle.color.withOpacity(1.0 - progress * 0.5);

      // Draw confetti as rectangles or circles
      if (particle.size > 10) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) => true;
}

class PulsePainter extends CustomPainter {
  final double progress;
  final Color color;

  PulsePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    // Draw multiple expanding rings
    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress - i * 0.15).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;

      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.3;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(centerX, centerY),
          radius: radius,
        ));

      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) => true;
}
