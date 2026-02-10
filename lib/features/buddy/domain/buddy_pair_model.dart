import 'package:cloud_firestore/cloud_firestore.dart';

class BuddyPair {
  final String id;
  final String inviteCode;
  final String userId1;
  final String userId2;
  final String userName1;
  final String userName2;
  final String userEmail1;
  final String userEmail2;
  final String status; // 'pending', 'active'
  final DateTime createdAt;
  final DateTime? lastNudgeAt;
  final String? lastNudgeBy;

  BuddyPair({
    required this.id,
    required this.inviteCode,
    required this.userId1,
    this.userId2 = '',
    this.userName1 = 'User',
    this.userName2 = 'User',
    this.userEmail1 = '',
    this.userEmail2 = '',
    this.status = 'pending',
    required this.createdAt,
    this.lastNudgeAt,
    this.lastNudgeBy,
  });

  factory BuddyPair.fromMap(Map<String, dynamic> map, String id) {
    return BuddyPair(
      id: id,
      inviteCode: map['inviteCode'] ?? '',
      userId1: map['userId1'] ?? '',
      userId2: map['userId2'] ?? '',
      userName1: map['userName1'] ?? 'User',
      userName2: map['userName2'] ?? 'User',
      userEmail1: map['userEmail1'] ?? '',
      userEmail2: map['userEmail2'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastNudgeAt: (map['lastNudgeAt'] as Timestamp?)?.toDate(),
      lastNudgeBy: map['lastNudgeBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteCode': inviteCode,
      'userId1': userId1,
      'userId2': userId2,
      'userName1': userName1,
      'userName2': userName2,
      'userEmail1': userEmail1,
      'userEmail2': userEmail2,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastNudgeAt != null) 'lastNudgeAt': Timestamp.fromDate(lastNudgeAt!),
      if (lastNudgeBy != null) 'lastNudgeBy': lastNudgeBy,
    };
  }

  /// Get buddy's name given the current user's ID
  String getBuddyName(String currentUserId) {
    return currentUserId == userId1 ? userName2 : userName1;
  }

  /// Get buddy's user ID given the current user's ID
  String getBuddyId(String currentUserId) {
    return currentUserId == userId1 ? userId2 : userId1;
  }

  /// Get buddy's email given the current user's ID
  String getBuddyEmail(String currentUserId) {
    return currentUserId == userId1 ? userEmail2 : userEmail1;
  }

  /// Check if the current user can send a nudge (30 sec cooldown for testing)
  bool canSendNudge(String currentUserId) {
    if (lastNudgeBy != currentUserId) return true;
    if (lastNudgeAt == null) return true;
    return DateTime.now().difference(lastNudgeAt!).inSeconds >= 30;
  }

  /// Minutes remaining until nudge cooldown expires
  int nudgeCooldownMinutes(String currentUserId) {
    if (canSendNudge(currentUserId)) return 0;
    final elapsed = DateTime.now().difference(lastNudgeAt!).inSeconds;
    return ((30 - elapsed) / 60).ceil();
  }
}
