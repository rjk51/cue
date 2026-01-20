import 'package:flutter/material.dart';

/// Custom Snackbar Widget for Cue App
/// 
/// Provides themed snackbars with different types:
/// - Success (green)
/// - Error (red)
/// - Warning (yellow)
/// - Info (dark purple with coral icon)
///
/// Usage:
/// ```dart
/// // Method 1: Using CustomSnackbar directly
/// CustomSnackbar.show(
///   context,
///   message: 'Operation completed',
///   type: SnackbarType.success,
///   duration: Duration(seconds: 3),
/// );
///
/// // Method 2: Using extension methods (recommended)
/// context.showSuccessSnackbar('Reminder created!');
/// context.showErrorSnackbar('Failed to save reminder');
/// context.showWarningSnackbar('Please check your connection');
/// context.showInfoSnackbar('Tap to see details');
///
/// // With action button
/// context.showSnackbar(
///   'Item deleted',
///   type: SnackbarType.warning,
///   actionLabel: 'Undo',
///   onAction: () {
///     // Undo logic here
///   },
/// );
/// ```

enum SnackbarType {
  success,
  error,
  info,
  warning,
}

class CustomSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = _getColors(type);
    final icon = _getIcon(type);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _SnackbarContent(
          message: message,
          icon: icon,
          iconColor: colors.iconColor,
        ),
        backgroundColor: colors.backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colors.actionColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  static _SnackbarColors _getColors(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarColors(
          backgroundColor: const Color(0xFF34A853),
          iconColor: Colors.white,
          actionColor: Colors.white,
        );
      case SnackbarType.error:
        return _SnackbarColors(
          backgroundColor: const Color(0xFFE74C3C),
          iconColor: Colors.white,
          actionColor: Colors.white,
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          backgroundColor: const Color(0xFFFBBC05),
          iconColor: Colors.white,
          actionColor: Colors.white,
        );
      case SnackbarType.info:
        return _SnackbarColors(
          backgroundColor: const Color(0xFF4A4458),
          iconColor: const Color(0xFFFFB4A3),
          actionColor: const Color(0xFFFFB4A3),
        );
    }
  }

  static IconData _getIcon(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle_outline;
      case SnackbarType.error:
        return Icons.error_outline;
      case SnackbarType.warning:
        return Icons.warning_amber_outlined;
      case SnackbarType.info:
        return Icons.info_outline;
    }
  }
}

class _SnackbarContent extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;

  const _SnackbarContent({
    required this.message,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SnackbarColors {
  final Color backgroundColor;
  final Color iconColor;
  final Color actionColor;

  _SnackbarColors({
    required this.backgroundColor,
    required this.iconColor,
    required this.actionColor,
  });
}

// Extension for easier access
extension SnackbarExtension on BuildContext {
  void showSnackbar(
    String message, {
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    CustomSnackbar.show(
      this,
      message: message,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void showSuccessSnackbar(String message) {
    CustomSnackbar.show(this, message: message, type: SnackbarType.success);
  }

  void showErrorSnackbar(String message) {
    CustomSnackbar.show(this, message: message, type: SnackbarType.error);
  }

  void showWarningSnackbar(String message) {
    CustomSnackbar.show(this, message: message, type: SnackbarType.warning);
  }

  void showInfoSnackbar(String message) {
    CustomSnackbar.show(this, message: message, type: SnackbarType.info);
  }
}
