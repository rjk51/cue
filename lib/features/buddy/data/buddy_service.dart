import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/buddy_pair_model.dart';
import '../../../services/local_storage_service.dart';

class BuddyService {
  static final BuddyService _instance = BuddyService._internal();
  factory BuddyService() => _instance;
  BuddyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'buddy_pairs';

  String? get _currentUserId => _auth.currentUser?.uid;
  String? get _currentUserName => _auth.currentUser?.displayName;
  String? get _currentUserEmail => _auth.currentUser?.email;

  /// Generate a random 6-character alphanumeric invite code
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No I/O/0/1 for clarity
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new buddy pair with an invite code
  Future<String> generateInviteCode() async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    // Check if user already has an active pair
    final existing = await getActiveBuddyPair();
    if (existing != null) throw Exception('You already have a buddy connected');

    // Check if user already has a pending invite
    final pendingQuery = await _firestore
        .collection(_collection)
        .where('userId1', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (pendingQuery.docs.isNotEmpty) {
      // Return existing pending code
      return pendingQuery.docs.first.data()['inviteCode'] as String;
    }

    // Generate unique code
    String code;
    bool exists;
    do {
      code = _generateCode();
      final check = await _firestore
          .collection(_collection)
          .where('inviteCode', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      exists = check.docs.isNotEmpty;
    } while (exists);

    // Create buddy pair document
    await _firestore.collection(_collection).add({
      'inviteCode': code,
      'userId1': uid,
      'userId2': '',
      'userName1': _currentUserName ?? 'User',
      'userName2': '',
      'userEmail1': _currentUserEmail ?? '',
      'userEmail2': '',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  /// Accept a buddy invite using the 6-character code
  Future<void> acceptInvite(String code) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    // Check if user already has an active pair
    final existing = await getActiveBuddyPair();
    if (existing != null) throw Exception('You already have a buddy connected');

    final normalizedCode = code.trim().toUpperCase();

    // Find the pending pair with this code
    final query = await _firestore
        .collection(_collection)
        .where('inviteCode', isEqualTo: normalizedCode)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid or expired invite code');
    }

    final doc = query.docs.first;
    final data = doc.data();

    // Can't pair with yourself
    if (data['userId1'] == uid) {
      throw Exception('You cannot use your own invite code');
    }

    // Accept the invite
    await doc.reference.update({
      'userId2': uid,
      'userName2': _currentUserName ?? 'User',
      'userEmail2': _currentUserEmail ?? '',
      'status': 'active',
    });

    // Send a welcome nudge notification to the inviter
    await _createNudgeNotification(
      data['userId1'] as String,
      '${_currentUserName ?? 'Someone'} joined as your accountability buddy! 🎉',
    );
  }

  /// Get the active buddy pair for the current user (real-time stream)
  Stream<BuddyPair?> buddyPairStream() {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(null);

    // Query where user is userId1 or userId2 with active status
    // Firestore doesn't support OR on different fields, so we merge two streams
    final stream1 = _firestore
        .collection(_collection)
        .where('userId1', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();

    final stream2 = _firestore
        .collection(_collection)
        .where('userId2', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots();

    // Merge both streams — whichever fires, check if docs exist
    return stream1.asyncExpand((snap1) {
      if (snap1.docs.isNotEmpty) {
        final doc = snap1.docs.first;
        return Stream.value(BuddyPair.fromMap(doc.data(), doc.id));
      }
      return stream2.map((snap2) {
        if (snap2.docs.isNotEmpty) {
          final doc = snap2.docs.first;
          return BuddyPair.fromMap(doc.data(), doc.id);
        }
        return null;
      });
    });
  }

  /// Get active buddy pair (one-time fetch)
  Future<BuddyPair?> getActiveBuddyPair() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    // Check as userId1
    var query = await _firestore
        .collection(_collection)
        .where('userId1', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return BuddyPair.fromMap(doc.data(), doc.id);
    }

    // Check as userId2
    query = await _firestore
        .collection(_collection)
        .where('userId2', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      return BuddyPair.fromMap(doc.data(), doc.id);
    }

    return null;
  }

  /// Get buddy's today progress (completed / total) — tasks created today
  Future<Map<String, int>> getBuddyProgress(String buddyUserId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Try querying by createdAt first
      var query = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: buddyUserId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get(const GetOptions(source: Source.server));

      int total = query.docs.length;
      int completed = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['isCompleted'] == true ||
            data['lastCompletedAt'] != null ||
            data['completedAt'] != null) {
          completed++;
        }
      }

      print('📊 Progress for $buddyUserId: $completed/$total');
      return {'total': total, 'completed': completed};
    } catch (e) {
      // If createdAt query fails (missing index or field), fall back to all reminders
      print('⚠️ createdAt query failed: $e, falling back to all reminders');
      
      final query = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: buddyUserId)
          .get(const GetOptions(source: Source.server));

      int total = query.docs.length;
      int completed = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        if (data['isCompleted'] == true ||
            data['lastCompletedAt'] != null ||
            data['completedAt'] != null) {
          completed++;
        }
      }

      print('📊 Fallback progress for $buddyUserId: $completed/$total');
      return {'total': total, 'completed': completed};
    }
  }

  /// Get your own today progress
  Future<Map<String, int>> getMyProgress() async {
    final uid = _currentUserId;
    if (uid == null) return {'total': 0, 'completed': 0};
    return getBuddyProgress(uid);
  }

  /// Get buddy's current streak (consecutive days with at least 1 completion)
  Future<int> getBuddyStreak(String buddyUserId) async {
    // Force server query for real-time streak data
    final query = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: buddyUserId)
        .where('consistency', isNull: false)
        .limit(20)
        .get(const GetOptions(source: Source.server));

    if (query.docs.isEmpty) return 0;

    // Collect all completed dates across all reminders
    final allCompletedDates = <String>{};
    for (final doc in query.docs) {
      final data = doc.data();
      final consistency = data['consistency'] as Map<String, dynamic>?;
      if (consistency != null) {
        final dates = List<String>.from(consistency['completedDates'] ?? []);
        allCompletedDates.addAll(dates);
      }
    }

    if (allCompletedDates.isEmpty) return 0;

    // Sort dates and count streak from today backwards
    final sortedDates = allCompletedDates.toList()..sort();
    final today = DateTime.now();
    int streak = 0;

    for (int i = 0; i <= 90; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateStr =
          '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (sortedDates.contains(dateStr)) {
        streak++;
      } else if (i > 0) {
        // Allow today to be incomplete (streak counts up to yesterday)
        break;
      }
    }

    return streak;
  }

  /// Send a nudge to buddy
  Future<void> sendNudge(BuddyPair pair) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    if (!pair.canSendNudge(uid)) {
      final remaining = pair.nudgeCooldownMinutes(uid);
      throw Exception('Please wait ${remaining > 0 ? "$remaining min" : "a few seconds"} before nudging again');
    }

    final buddyId = pair.getBuddyId(uid);
    final myName = uid == pair.userId1 ? pair.userName1 : pair.userName2;

    // Update last nudge timestamp on the pair
    await _firestore.collection(_collection).doc(pair.id).update({
      'lastNudgeAt': FieldValue.serverTimestamp(),
      'lastNudgeBy': uid,
    });

    // Get custom nudge message from preferences
    final customMessage = LocalStorageService.instance.getNudgeMessage();
    final nudgeMessage = '$myName: $customMessage 💪';

    print('👋 [BuddyService] Sending nudge with message: "$nudgeMessage"');
    print('   Custom message from storage: "$customMessage"');

    // Create a nudge notification for the buddy
    await _createNudgeNotification(
      buddyId,
      nudgeMessage,
    );
  }

  /// Create a notification document for the buddy
  Future<void> _createNudgeNotification(String targetUserId, String message) async {
    print('📝 [BuddyService] Creating nudge notification');
    print('   Target user: $targetUserId');
    print('   Message: "$message"');
    
    // Use the same pending_notifications format that processPendingNotifications expects
    // Create a special "buddy_nudge" type notification
    await _firestore.collection('pending_notifications').add({
      'userId': targetUserId,
      'reminderId': 'buddy_nudge_${DateTime.now().millisecondsSinceEpoch}',
      'reminderName': '👋 Buddy Nudge',
      'reminderDescription': message,
      'type': 'buddy_nudge',
      'scheduledTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    print('✅ [BuddyService] Nudge notification created in Firestore');
  }

  /// Disconnect from buddy
  Future<void> removeBuddy() async {
    final pair = await getActiveBuddyPair();
    if (pair == null) return;

    await _firestore.collection(_collection).doc(pair.id).delete();
  }

  /// Cancel a pending invite
  Future<void> cancelPendingInvite() async {
    final uid = _currentUserId;
    if (uid == null) return;

    final query = await _firestore
        .collection(_collection)
        .where('userId1', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }
}
