import 'package:cue/features/reminders/presentation/create_reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../features/reminders/domain/reminder_model.dart';
import '../../features/reminders/data/reminder_service.dart';
import 'confirmation_dialog.dart';
import 'delete_recurring_dialog.dart';
import 'custom_snackbar.dart';

class CardBackSide extends StatelessWidget {
  final Reminder reminder;
  final Color accentColor;
  final bool isDarkMode;
  final Color cardColor;
  final Color textColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted; // Called after successful deletion

  const CardBackSide({
    super.key,
    required this.reminder,
    required this.accentColor,
    required this.isDarkMode,
    required this.cardColor,
    required this.textColor,
    this.onEdit,
    this.onDeleted,
  });

  Future<void> _handleDelete(BuildContext context) async {
    final reminderService = ReminderService();

    // For recurring reminders, show dialog to choose between skipping occurrence or deleting series
    if (reminder.recurrence != null) {
      final deleteOption = await DeleteRecurringDialog.show(
        context: context,
        reminderName: reminder.name,
        accentColor: accentColor,
        isDarkMode: isDarkMode,
      );

      // User cancelled the dialog
      if (deleteOption == null) {
        return;
      }

      if (deleteOption == DeleteRecurringOption.thisOccurrenceOnly) {
        // Skip this occurrence by creating a skipped override
        try {
          final occurrenceDate = reminder.effectiveNextDueAt;
          final dateKey = DateFormat('yyyy-MM-dd').format(occurrenceDate);

          // Get existing overrides or create new map
          final existingOverrides = reminder.overrides ?? {};
          final newOverrides = Map<String, Map<String, dynamic>>.from(
            existingOverrides,
          );

          // Create or update override for this date with skipped flag
          newOverrides[dateKey] = {
            ...(newOverrides[dateKey] ?? {}),
            'skipped': true,
          };

          await reminderService.updateReminder(reminder.id, {
            'overrides': newOverrides,
          });

          if (context.mounted) {
            context.showSuccessSnackbar('Occurrence skipped');
            onDeleted?.call();
          }
        } catch (e) {
          if (context.mounted) {
            context.showErrorSnackbar('Error skipping occurrence: $e');
          }
        }
        return;
      }
      // If wholeSeries, fall through to show confirmation dialog
    }

    // For non-recurring reminders or when deleting whole series, show confirmation dialog
    await ConfirmationDialog.show(
      context: context,
      title: reminder.recurrence != null
          ? 'Delete Entire Series'
          : 'Delete Reminder',
      message: reminder.recurrence != null
          ? 'Are you sure you want to permanently delete "${reminder.name}" and all its occurrences? This action cannot be undone.'
          : 'Are you sure you want to delete "${reminder.name}"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      accentColor: accentColor,
      isDarkMode: isDarkMode,
      isDestructive: true,
      onConfirm: () async {
        try {
          await reminderService.deleteReminder(reminder.id);
          if (context.mounted) {
            context.showSuccessSnackbar(
              reminder.recurrence != null
                  ? 'Reminder series deleted successfully'
                  : 'Reminder deleted successfully',
            );
            onDeleted?.call();
          }
        } catch (e) {
          if (context.mounted) {
            context.showErrorSnackbar('Error deleting reminder: $e');
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(vertical: 120.h, horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Edit button
          _buildActionButton(
            context: context,
            icon: Icons.edit_rounded,
            label: 'EDIT',
            color: accentColor,
            onTap: () {
              if (onEdit != null) {
                onEdit!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        NewReminderScreen(reminderToEdit: reminder),
                  ),
                );
              }
            },
          ),
          SizedBox(width: 16.w),
          // Delete button
          _buildActionButton(
            context: context,
            icon: Icons.delete_rounded,
            label: 'DELETE',
            color: Colors.red.shade400,
            onTap: () => _handleDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120.w,
        height: 100.h,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(32.r),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50.w,
              height: 50.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
