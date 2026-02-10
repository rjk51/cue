import 'package:cue/features/reminders/presentation/create_reminder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../features/reminders/domain/reminder_model.dart';
import '../../features/reminders/data/reminder_service.dart';
import '../../features/reminders/presentation/reminder_details_screen.dart';
import '../../services/file_storage_service.dart';
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
    final subtitleColor = isDarkMode
        ? Colors.white.withOpacity(0.6)
        : const Color(0xFF8A8A8A);

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
      padding: EdgeInsets.all(32.r),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attachments Preview (if any)
          if (reminder.attachments != null &&
              reminder.attachments!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 20.sp,
                  color: subtitleColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${reminder.attachments!.length} file${reminder.attachments!.length == 1 ? '' : 's'} attached',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...List.generate(
              reminder.attachments!.length > 3
                  ? 3
                  : reminder.attachments!.length,
              (index) {
                final attachment = reminder.attachments![index];
                final fileType = attachment['type'] ?? 'file';
                final fileName = attachment['name'] ?? 'Unknown';
                final fileSize = attachment['size'] ?? 0;
                final fileUrl = attachment['url'] ?? '';

                return GestureDetector(
                  onTap: () => _openAttachment(context, fileUrl),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12.h),
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        // File icon or image preview
                        if (fileType == 'image')
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image.network(
                              fileUrl,
                              width: 56.w,
                              height: 56.h,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 56.w,
                                  height: 56.h,
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: accentColor,
                                    size: 28.sp,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 56.w,
                            height: 56.h,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(
                              _getFileIcon(fileType),
                              color: accentColor,
                              size: 28.sp,
                            ),
                          ),
                        SizedBox(width: 16.w),
                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                FileStorageService.formatFileSize(fileSize),
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Open icon
                        Icon(
                          Icons.open_in_new,
                          color: accentColor,
                          size: 20.sp,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (reminder.attachments!.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 8.h, bottom: 12.h),
                child: Text(
                  '+${reminder.attachments!.length - 3} more files',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
          // Spacer
          SizedBox(height: 20.h),
          // Action Buttons at bottom
          Row(
            children: [
              // Edit button
              Expanded(
                child: _buildSimpleActionButton(
                  context: context,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
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
              ),
              SizedBox(width: 16.w),
              // Delete button
              Expanded(
                child: _buildSimpleActionButton(
                  context: context,
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                  color: Colors.red.shade400,
                  onTap: () => _handleDelete(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Simple action button with icon and label
  Widget _buildSimpleActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 28.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Open attachment URL
  Future<void> _openAttachment(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          context.showErrorSnackbar('Cannot open attachment');
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnackbar('Error opening attachment: $e');
      }
    }
  }

  // Get icon for file type
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
}
