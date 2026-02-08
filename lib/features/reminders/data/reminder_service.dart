import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/reminder_model.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final String _collection = 'reminders';

  // Get current user ID from Firebase Auth
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Get reminders stream for real-time updates (excludes completed non-recurring)
  Stream<List<Reminder>> getRemindersStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]); // Return empty stream if no user logged in
    }

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          // Sort in memory instead of on server
          final reminders = snapshot.docs
              .map((doc) => Reminder.fromMap(doc.data(), doc.id))
              .toList();

          // Update outdated nextDueAt values for recurring reminders in the background
          _updateOutdatedNextDueAt(reminders);

          reminders.sort((a, b) => a.time.compareTo(b.time));
          return reminders;
        });
  }

  /// Get ALL reminders for today (including completed non-recurring ones).
  /// Used for progress bar counting so completed tasks don't vanish from the total.
  Stream<List<Reminder>> getAllRemindersForTodayStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);
    }

    // We need both completed and incomplete reminders.
    // Firestore doesn't support OR queries on the same field easily,
    // so we fetch all reminders for this user and filter in memory.
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          final tomorrowStart = todayStart.add(const Duration(days: 1));

          return snapshot.docs
              .map((doc) => Reminder.fromMap(doc.data(), doc.id))
              .where((r) {
                if (r.recurrence != null) {
                  // Recurring reminders are always in the active stream,
                  // just include them so we can count their occurrences
                  return true;
                }
                // Non-recurring: include if its time is today (whether completed or not)
                return !r.time.isBefore(todayStart) && r.time.isBefore(tomorrowStart);
              })
              .toList();
        });
  }

  // Update outdated nextDueAt values for recurring reminders
  Future<void> _updateOutdatedNextDueAt(List<Reminder> reminders) async {
    final now = DateTime.now();
    final updates = <String, DateTime>{};

    for (final reminder in reminders) {
      if (reminder.recurrence != null && reminder.nextDueAt != null) {
        // Check if nextDueAt is outdated (in the past)
        if (reminder.nextDueAt!.isBefore(now)) {
          try {
            final effectiveDate = reminder.effectiveNextDueAt;
            // Only update if the calculated date is different and in the future
            if (effectiveDate != reminder.nextDueAt &&
                effectiveDate.isAfter(now)) {
              updates[reminder.id] = effectiveDate;
            }
          } catch (e) {
            print(
              'Error calculating effective date for reminder ${reminder.id}: $e',
            );
          }
        }
      }
    }

    // Batch update outdated nextDueAt values
    if (updates.isNotEmpty) {
      final batch = _firestore.batch();
      for (final entry in updates.entries) {
        batch.update(_firestore.collection(_collection).doc(entry.key), {
          'nextDueAt': Timestamp.fromDate(entry.value),
        });
      }
      try {
        await batch.commit();
        print('Updated ${updates.length} outdated nextDueAt values');
      } catch (e) {
        print('Error updating outdated nextDueAt values: $e');
      }
    }
  }

  // Add a new reminder
  Future<String> addReminder(Reminder reminder, String? fcmToken) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      final reminderData = reminder.toMap();
      // Ensure scheduledTime is set for Cloud Functions
      reminderData['scheduledTime'] =
          reminderData['nextDueAt'] ?? reminderData['time'];
      reminderData['status'] = reminderData['status'] ?? 'active';

      // Initialize consistency tracking for recurring reminders
      if (reminder.recurrence != null) {
        reminderData['consistency'] = {
          'completedCount': 0,
          'missedCount': 0,
          'lastEvaluatedDate': '',
          'completedDates': [],
        };
      }

      final docRef = await _firestore.collection(_collection).add({
        ...reminderData,
        'userId': userId,
        'deviceToken': fcmToken,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Reminder added with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error adding reminder: $e');
      rethrow;
    }
  }

  // Mark reminder as completed (this will trigger cross-device sync)
  // Consistency tracking is handled by Firebase Functions
  // For hourly reminders, occurrenceTime should be provided to track specific occurrence completion
  Future<void> markAsCompleted(
    String reminderId, {
    DateTime? occurrenceTime,
  }) async {
    try {
      // First try to update Firestore directly for immediate feedback
      // This ensures the UI updates even if Cloud Functions are slow
      final doc = await _firestore
          .collection(_collection)
          .doc(reminderId)
          .get();
      if (doc.exists) {
        final reminderData = doc.data()!;
        final isRecurring = reminderData['recurrence'] != null;

        final updates = <String, dynamic>{
          'lastCompletedAt': FieldValue.serverTimestamp(),
          'scheduledTimeAtSnooze': FieldValue.delete(),
          'snoozedUntil': FieldValue.delete(),
        };

        if (isRecurring) {
          final recurrence =
              reminderData['recurrence'] as Map<String, dynamic>?;
          final isHourly =
              recurrence != null &&
              recurrence['type'] == 'interval' &&
              (recurrence['unit'].toString().toLowerCase().contains('hour') ||
                  recurrence['unit'].toString().toLowerCase().contains(
                    'minute',
                  ));

          if (isHourly && occurrenceTime != null) {
            // For hourly reminders, track completion using overrides per occurrence time
            final dateKey =
                '${occurrenceTime.year.toString().padLeft(4, '0')}-${occurrenceTime.month.toString().padLeft(2, '0')}-${occurrenceTime.day.toString().padLeft(2, '0')}';
            final timeKey =
                '${occurrenceTime.hour.toString().padLeft(2, '0')}:${occurrenceTime.minute.toString().padLeft(2, '0')}';

            final overrides = Map<String, dynamic>.from(
              reminderData['overrides'] as Map<String, dynamic>? ?? {},
            );
            final dateOverride = Map<String, dynamic>.from(
              overrides[dateKey] as Map<String, dynamic>? ?? {},
            );

            // Track completed times for this date
            final completedTimes = List<String>.from(
              dateOverride['completedTimes'] as List<dynamic>? ?? [],
            );
            if (!completedTimes.contains(timeKey)) {
              completedTimes.add(timeKey);
              dateOverride['completedTimes'] = completedTimes;
              overrides[dateKey] = dateOverride;
              updates['overrides'] = overrides;
            }
          } else {
            // For non-hourly recurring reminders, update consistency data
            final today = DateTime.now();
            final todayStr =
                '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

            final consistency =
                reminderData['consistency'] as Map<String, dynamic>? ??
                {
                  'completedCount': 0,
                  'missedCount': 0,
                  'lastEvaluatedDate': '',
                  'completedDates': [],
                };

            final completedDates = List<String>.from(
              consistency['completedDates'] ?? [],
            );
            if (!completedDates.contains(todayStr)) {
              completedDates.add(todayStr);
              // Keep only last 90 days
              if (completedDates.length > 90) {
                completedDates.sort();
                completedDates.removeRange(0, completedDates.length - 90);
              }

              updates['consistency'] = {
                ...consistency,
                'completedCount': (consistency['completedCount'] ?? 0) + 1,
                'lastEvaluatedDate': todayStr,
                'completedDates': completedDates,
              };
            }
          }
        } else {
          // For non-recurring, just mark as completed
          updates['isCompleted'] = true;
          updates['completedAt'] = FieldValue.serverTimestamp();
        }

        await _firestore
            .collection(_collection)
            .doc(reminderId)
            .update(updates);
        print('Reminder marked as completed locally: $reminderId');

        // Delete the pending notification to prevent it from being sent
        try {
          await _firestore
              .collection('pending_notifications')
              .doc(reminderId)
              .delete();
          print(
            'Deleted pending notification for completed reminder: $reminderId',
          );
        } catch (e) {
          print('Error deleting pending notification: $e');
          // Don't rethrow - the reminder completion was successful
        }
      }

      // Call Firebase Functions to handle complex logic (recurrence scheduling, stats, etc.)
      try {
        final callable = _functions.httpsCallable('completeReminder');
        await callable.call({
          'reminderId': reminderId,
          'completedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('Cloud Function completeReminder called successfully');
      } catch (e) {
        print('Cloud Function call failed (but local update succeeded): $e');
      }

      // Trigger a notification to other devices
      await _notifyOtherDevices(reminderId, 'completed');
    } catch (e) {
      print('Error marking reminder as completed: $e');
      rethrow;
    }
  }

  // Delete a reminder
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _firestore.collection(_collection).doc(reminderId).delete();
      print('Reminder deleted: $reminderId');
    } catch (e) {
      print('Error deleting reminder: $e');
      rethrow;
    }
  }

  // Update a reminder
  Future<void> updateReminder(
    String reminderId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection(_collection).doc(reminderId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Reminder updated: $reminderId');

      // If the name is being updated, also update pending_notifications
      if (updates.containsKey('name')) {
        try {
          final pendingNotifDoc = await _firestore
              .collection('pending_notifications')
              .doc(reminderId)
              .get();

          if (pendingNotifDoc.exists) {
            await _firestore
                .collection('pending_notifications')
                .doc(reminderId)
                .update({
                  'reminderName': updates['name'],
                  'reminderDescription': updates['name'],
                });
            print('Updated pending notification name for: $reminderId');
          }
        } catch (e) {
          print('Error updating pending notification: $e');
          // Don't rethrow - the reminder update was successful
        }
      }

      // If the scheduled time is being updated (time or nextDueAt), update pending_notifications
      if (updates.containsKey('time') || updates.containsKey('nextDueAt')) {
        try {
          final pendingNotifDoc = await _firestore
              .collection('pending_notifications')
              .doc(reminderId)
              .get();

          if (pendingNotifDoc.exists) {
            final newScheduledTime = updates['nextDueAt'] ?? updates['time'];
            if (newScheduledTime != null) {
              await _firestore
                  .collection('pending_notifications')
                  .doc(reminderId)
                  .update({'scheduledTime': newScheduledTime});
              print(
                'Updated pending notification scheduledTime for: $reminderId',
              );
            }
          }
        } catch (e) {
          print('Error updating pending notification time: $e');
          // Don't rethrow - the reminder update was successful
        }
      }
    } catch (e) {
      print('Error updating reminder: $e');
      rethrow;
    }
  }

  // Snooze a reminder with custom duration (in minutes)
  Future<void> snoozeReminder(String reminderId, {int minutes = 10}) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(reminderId)
          .get();
      if (doc.exists) {
        final reminder = Reminder.fromMap(doc.data()!, doc.id);
        final newTime = DateTime.now().add(Duration(minutes: minutes));
        final isRecurring = reminder.recurrence != null;
        // Keep the original scheduled time for display — only set on first snooze, preserve on repeat snoozes
        final scheduledDisplayTime =
            reminder.scheduledTimeAtSnooze ??
            reminder.getEffectiveDisplayTime();

        final updates = <String, dynamic>{
          'scheduledTime': Timestamp.fromDate(newTime),
          'scheduledTimeAtSnooze': Timestamp.fromDate(scheduledDisplayTime),
          'snoozedUntil': Timestamp.fromDate(newTime),
          'notifiedAt':
              FieldValue.delete(), // Clear notifiedAt so it can notify again
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // For recurring reminders, update nextDueAt (current occurrence)
        // For non-recurring reminders, update time (original scheduled time)
        if (isRecurring) {
          updates['nextDueAt'] = Timestamp.fromDate(newTime);
          print('Recurring reminder snoozed - updating nextDueAt');
        } else {
          updates['time'] = Timestamp.fromDate(newTime);
          print('One-time reminder snoozed - updating time');
        }

        await _firestore
            .collection(_collection)
            .doc(reminderId)
            .update(updates);

        // Create a new pending notification for the snoozed time
        await _firestore
            .collection('pending_notifications')
            .doc(reminderId)
            .set({
              'reminderId': reminderId,
              'scheduledTime': Timestamp.fromDate(newTime),
              'reminderName': reminder.name,
              'reminderDescription': reminder.name, // Use name as description
              'createdAt': FieldValue.serverTimestamp(),
            });

        print('Reminder snoozed by $minutes minutes: $reminderId to $newTime');
      }
    } catch (e) {
      print('Error snoozing reminder: $e');
      rethrow;
    }
  }

  // Snooze a reminder to a specific date/time (for "later today", "tomorrow", or "another day")
  Future<void> snoozeReminderTo(String reminderId, DateTime targetTime) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(reminderId)
          .get();
      if (doc.exists) {
        final reminder = Reminder.fromMap(doc.data()!, doc.id);
        final isRecurring = reminder.recurrence != null;
        final scheduledDisplayTime =
            reminder.scheduledTimeAtSnooze ??
            reminder.getEffectiveDisplayTime();

        final updates = <String, dynamic>{
          'scheduledTime': Timestamp.fromDate(targetTime),
          'scheduledTimeAtSnooze': Timestamp.fromDate(scheduledDisplayTime),
          'snoozedUntil': Timestamp.fromDate(targetTime),
          'notifiedAt': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (isRecurring) {
          updates['nextDueAt'] = Timestamp.fromDate(targetTime);
        } else {
          updates['time'] = Timestamp.fromDate(targetTime);
        }

        await _firestore
            .collection(_collection)
            .doc(reminderId)
            .update(updates);

        await _firestore
            .collection('pending_notifications')
            .doc(reminderId)
            .set({
              'reminderId': reminderId,
              'scheduledTime': Timestamp.fromDate(targetTime),
              'reminderName': reminder.name,
              'reminderDescription': reminder.name,
              'createdAt': FieldValue.serverTimestamp(),
            });

        print('Reminder snoozed to $targetTime: $reminderId');
      }
    } catch (e) {
      print('Error snoozing reminder to time: $e');
      rethrow;
    }
  }

  // Dismiss notification on all devices (without marking as completed)
  // This triggers the same dismiss notification as Done button
  Future<void> dismissOnAllDevices(String reminderId) async {
    try {
      // Just update isCompleted temporarily to trigger onReminderUpdated Cloud Function
      // then immediately revert it. The Cloud Function will send dismiss notifications.
      await _firestore.collection(_collection).doc(reminderId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      print('Triggered dismiss on all devices for: $reminderId');
    } catch (e) {
      print('Error dismissing on all devices: $e');
      rethrow;
    }
  }

  // Get a single reminder
  Future<Reminder?> getReminder(String reminderId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(reminderId)
          .get();
      if (doc.exists) {
        return Reminder.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting reminder: $e');
      return null;
    }
  }

  // Listen to a specific reminder for changes
  Stream<Reminder?> getReminderStream(String reminderId) {
    return _firestore.collection(_collection).doc(reminderId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return Reminder.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }

  // Private method to notify other devices (via Cloud Functions in production)
  Future<void> _notifyOtherDevices(String reminderId, String action) async {
    // In production, this would trigger a Cloud Function that sends FCM messages
    // to all devices subscribed to the user's topic
    // For now, Firestore listeners will handle the sync
    print('Notifying other devices about $action on reminder: $reminderId');
  }

  // Get completed reminders (for history)
  Stream<List<Reminder>> getCompletedRemindersStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]); // Return empty stream if no user logged in
    }

    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('isCompleted', isEqualTo: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          // Sort in memory
          final reminders = snapshot.docs
              .map((doc) => Reminder.fromMap(doc.data(), doc.id))
              .toList();
          reminders.sort(
            (a, b) => b.time.compareTo(a.time),
          ); // Most recent first
          return reminders;
        });
  }

  // Clean up old completed reminders (optional)
  Future<void> cleanupOldReminders({int daysOld = 30}) async {
    try {
      final userId = _userId;
      if (userId == null) {
        throw Exception('No user logged in');
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: true)
          .where('completedAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Cleaned up ${querySnapshot.docs.length} old reminders');
    } catch (e) {
      print('Error cleaning up reminders: $e');
    }
  }
}
