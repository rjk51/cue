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
  Future<Map<String, int>> getBuddyProgress(String buddyUserId, {DateTime? connectionDate}) async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      print('📊 [BuddyProgress] Calculating for user: $buddyUserId on $todayStr');

      // Query all reminders for this user
      var query = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: buddyUserId)
          .get(const GetOptions(source: Source.server));

      print('📊 [BuddyProgress] Found ${query.docs.length} total reminders');

      int total = 0;
      int completed = 0;

      for (final doc in query.docs) {
        final data = doc.data();
        
        print('  🔍 Checking reminder: ${doc.id}');
        
        // Skip deleted or archived reminders
        if (data['isDeleted'] == true || data['isArchived'] == true) {
          print('    ⏭️  Skipped (deleted/archived)');
          continue;
        }
        
        // Filter by connection date if provided
        if (connectionDate != null) {
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
          if (createdAt == null || createdAt.isBefore(connectionDate)) {
            print('    ⏭️  Skipped (created before connection)');
            continue;
          }
        }

        final nextDueAt = (data['nextDueAt'] as Timestamp?)?.toDate();
        final time = (data['time'] as Timestamp?)?.toDate();
        final recurrence = data['recurrence'] as Map<String, dynamic>?;
        final isCompleted = data['isCompleted'] == true;
        
        final dueTime = nextDueAt ?? time;
        if (dueTime == null) {
          print('    ⏭️  Skipped (no due time)');
          continue;
        }
        
        print('    📅 Due: $dueTime, Recurring: ${recurrence != null}, Completed: $isCompleted');
        
        // For hourly reminders
        final frequency = recurrence?['frequency'] as String?;
        if (frequency == 'hourly') {
          final unit = recurrence?['unit'] as String?;
          final every = recurrence?['every'] as int? ?? 1;
          
          int intervalMinutes;
          if (unit == 'hours') {
            intervalMinutes = every * 60;
          } else if (unit == 'minutes') {
            intervalMinutes = every;
          } else {
            continue;
          }
          
          // Calculate expected occurrences today (up to current time)
          final startOfDay = DateTime(now.year, now.month, now.day);

          
          // Find first occurrence today
          DateTime firstToday = DateTime(dueTime.year, dueTime.month, dueTime.day, dueTime.hour, dueTime.minute);
          
          // If the reminder starts on a different day, find first occurrence today
          if (firstToday.isBefore(startOfDay)) {
            final diff = now.difference(firstToday).inMinutes;
            final intervals = (diff / intervalMinutes).ceil();
            firstToday = firstToday.add(Duration(minutes: intervals * intervalMinutes));
            
            // Ensure it's today
            while (firstToday.isBefore(startOfDay)) {
              firstToday = firstToday.add(Duration(minutes: intervalMinutes));
            }
          }
          
          // Count expected occurrences today (only up to current time for "total")
          int occurrences = 0;
          DateTime current = firstToday;
          while (current.isBefore(now) && current.day == now.day) {
            occurrences++;
            current = current.add(Duration(minutes: intervalMinutes));
          }
          
          total += occurrences;
          
          print('    ⏰ Hourly: $occurrences occurrences expected today');
          
          // Count completed occurrences today using overrides
          final overrides = data['overrides'] as Map<String, dynamic>?;
          if (overrides != null && overrides.containsKey(todayStr)) {
            final dateOverride = overrides[todayStr] as Map<String, dynamic>?;
            if (dateOverride != null) {
              final completedTimes = List<String>.from(dateOverride['completedTimes'] ?? []);
              completed += completedTimes.length;
              print('    ✅ Hourly: ${completedTimes.length} completions');
            }
          }
        } else if (recurrence != null) {
          // For non-hourly recurring reminders
          // Check if it's due today based on recurrence pattern
          bool isDueToday = _isReminderDueToday(now, dueTime, recurrence);
          
          print('    🔁 Recurring: due today = $isDueToday');
          
          if (isDueToday) {
            total++;
            
            // Check if completed today
            final consistency = data['consistency'] as Map<String, dynamic>?;
            if (consistency != null) {
              final completedDates = List<String>.from(consistency['completedDates'] ?? []);
              if (completedDates.contains(todayStr)) {
                completed++;
                print('    ✅ Recurring: completed today');
              } else {
                print('    ⬜ Recurring: not completed today');
              }
            }
          }
        } else {
          // One-time reminder - check if it's due today
          final dueDate = DateTime(dueTime.year, dueTime.month, dueTime.day);
          final today = DateTime(now.year, now.month, now.day);
          
          print('    📌 One-time: due date = $dueDate, today = $today');
          
          if (dueDate.isAtSameMomentAs(today)) {
            total++;
            if (isCompleted) {
              completed++;
              print('    ✅ One-time: completed');
            } else {
              print('    ⬜ One-time: not completed');
            }
          }
        }
      }

      print('📊 Progress for $buddyUserId: $completed/$total');
      return {'total': total, 'completed': completed};
    } catch (e) {
      print('⚠️ Error getting buddy progress: $e');
      return {'total': 0, 'completed': 0};
    }
  }

  /// Helper to check if a recurring reminder is due today
  bool _isReminderDueToday(DateTime now, DateTime dueTime, Map<String, dynamic> recurrence) {
    final frequency = recurrence['frequency'] as String?;
    final interval = recurrence['interval'] as int? ?? 1;
    final daysOfWeek = List<int>.from(recurrence['daysOfWeek'] ?? []);
    
    if (frequency == 'daily') {
      // Due every N days
      final daysDiff = now.difference(dueTime).inDays;
      return daysDiff >= 0 && daysDiff % interval == 0;
    } else if (frequency == 'weekly') {
      // Due on specific days of week
      final todayWeekday = now.weekday; // 1=Monday, 7=Sunday
      return daysOfWeek.contains(todayWeekday);
    } else if (frequency == 'monthly') {
      // Due on same day of month
      return now.day == dueTime.day;
    } else if (frequency == 'yearly') {
      // Due on same month and day
      return now.month == dueTime.month && now.day == dueTime.day;
    }
    
    return false;
  }

  /// Get your own today progress
  Future<Map<String, int>> getMyProgress({DateTime? connectionDate}) async {
    final uid = _currentUserId;
    if (uid == null) return {'total': 0, 'completed': 0};
    return getBuddyProgress(uid, connectionDate: connectionDate);
  }

  /// Get buddy's current streak (consecutive days with at least 1 completion)
  Future<int> getBuddyStreak(String buddyUserId, {DateTime? connectionDate}) async {
    // Force server query for real-time streak data
    // Note: Cannot query on consistency field directly (map type), so fetch all reminders
    final query = await _firestore
        .collection('reminders')
        .where('userId', isEqualTo: buddyUserId)
        .get(const GetOptions(source: Source.server));

    if (query.docs.isEmpty) {
      print('🔥 No reminders found for streak calculation: $buddyUserId');
      return 0;
    }

    print('🔥 Found ${query.docs.length} reminders for streak calculation');

    // Collect all completed dates across all reminders
    final dateCounts = <String, int>{};
    for (final doc in query.docs) {
      final data = doc.data();
      
      // Skip deleted or archived reminders
      if (data['isDeleted'] == true || data['isArchived'] == true) {
        continue;
      }
      
      // Filter by connection date if provided
      if (connectionDate != null) {
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        if (createdAt == null || createdAt.isBefore(connectionDate)) {
          continue;
        }
      }
      
      final consistency = data['consistency'] as Map<String, dynamic>?;
      if (consistency != null && consistency['completedDates'] != null) {
        final dates = List<String>.from(consistency['completedDates'] ?? []);
        print('  📅 Reminder ${doc.id}: ${dates.length} completed dates');
        for (final date in dates) {
          dateCounts[date] = (dateCounts[date] ?? 0) + 1;
        }
      }
    }

    print('🔥 Total unique completion dates: ${dateCounts.length}');
    if (dateCounts.isEmpty) return 0;

    // Count consecutive days from today backwards
    final today = DateTime.now();
    int streak = 0;

    // Check today first
    final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (dateCounts.containsKey(todayStr)) {
      streak = 1;
    }

    // Then check backwards from yesterday
    for (int i = 1; i <= 90; i++) {
      final checkDate = today.subtract(Duration(days: i));
      final dateStr = '${checkDate.year.toString().padLeft(4, '0')}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      
      if (dateCounts.containsKey(dateStr)) {
        streak++;
      } else {
        // Streak is broken - stop counting
        break;
      }
    }

    print('🔥 Streak for $buddyUserId: $streak days');
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
