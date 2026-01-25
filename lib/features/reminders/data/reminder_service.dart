import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/reminder_model.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'reminders';

  // Get current user ID from Firebase Auth
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // Get reminders stream for real-time updates
  Stream<List<Reminder>> getRemindersStream() {
    final userId = _userId;
    if (userId == null) {
      return Stream.value([]);  // Return empty stream if no user logged in
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
      reminders.sort((a, b) => a.time.compareTo(b.time));
      return reminders;
    });
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
      reminderData['scheduledTime'] = reminderData['nextDueAt'] ?? reminderData['time'];
      reminderData['status'] = reminderData['status'] ?? 'active';
      
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
  Future<void> markAsCompleted(String reminderId) async {
    try {
      await _firestore.collection(_collection).doc(reminderId).update({
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
      });
      print('Reminder marked as completed: $reminderId');
      
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
  Future<void> updateReminder(String reminderId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(reminderId).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Reminder updated: $reminderId');
    } catch (e) {
      print('Error updating reminder: $e');
      rethrow;
    }
  }

  // Snooze a reminder (add 10 minutes to the time)
  Future<void> snoozeReminder(String reminderId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(reminderId).get();
      if (doc.exists) {
        final reminder = Reminder.fromMap(doc.data()!, doc.id);
        final newTime = DateTime.now().add(const Duration(minutes: 10));
        
        await _firestore.collection(_collection).doc(reminderId).update({
          'time': Timestamp.fromDate(newTime),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Reminder snoozed: $reminderId');
      }
    } catch (e) {
      print('Error snoozing reminder: $e');
      rethrow;
    }
  }

  // Get a single reminder
  Future<Reminder?> getReminder(String reminderId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(reminderId).get();
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
    return _firestore
        .collection(_collection)
        .doc(reminderId)
        .snapshots()
        .map((snapshot) {
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
      return Stream.value([]);  // Return empty stream if no user logged in
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
      reminders.sort((a, b) => b.time.compareTo(a.time)); // Most recent first
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
