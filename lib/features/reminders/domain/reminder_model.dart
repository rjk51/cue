import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Consistency tracking data for recurring reminders
class ConsistencyData {
  final int completedCount;
  final int missedCount;
  final String lastEvaluatedDate; // YYYY-MM-DD format
  final List<String> completedDates; // List of completed dates (YYYY-MM-DD), limited to last 90 days

  ConsistencyData({
    required this.completedCount,
    required this.missedCount,
    required this.lastEvaluatedDate,
    this.completedDates = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'completedCount': completedCount,
      'missedCount': missedCount,
      'lastEvaluatedDate': lastEvaluatedDate,
      'completedDates': completedDates,
    };
  }

  factory ConsistencyData.fromMap(Map<String, dynamic> map) {
    return ConsistencyData(
      completedCount: map['completedCount'] as int? ?? 0,
      missedCount: map['missedCount'] as int? ?? 0,
      lastEvaluatedDate: map['lastEvaluatedDate'] as String? ?? '',
      completedDates: (map['completedDates'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  double get percentage {
    final total = completedCount + missedCount;
    if (total == 0) return 0.0;
    return (completedCount / total) * 100;
  }
  
  bool wasCompletedOnDate(String date) {
    return completedDates.contains(date);
  }
}

class Reminder {
  final String id;
  final String name;
  final DateTime time;
  final bool isCompleted;
  final String? deviceToken;
  final String userId;
  final DateTime? notifiedAt;
  final Map<String, dynamic>? recurrence;
  final DateTime? nextDueAt;
  final int? iconCodePoint;
  final int? colorValue;
  final String? notes;
  final bool autoSnoozeEnabled;
  final int autoSnoozeInterval; // in minutes
  final int autoSnoozeMaxCount; // maximum number of auto-snoozes
  final int autoSnoozeCount; // current auto-snooze count
  final ConsistencyData? consistency;

  Reminder({
    required this.id,
    required this.name,
    required this.time,
    this.isCompleted = false,
    this.deviceToken,
    required this.userId,
    this.notifiedAt,
    this.recurrence,
    this.nextDueAt,
    this.iconCodePoint,
    this.colorValue,
    this.notes,
    this.autoSnoozeEnabled = false,
    this.autoSnoozeInterval = 10, // default 10 minutes
    this.autoSnoozeMaxCount = 3, // default 3 times
    this.autoSnoozeCount = 0,
    this.consistency,
  });

  // Convert Reminder to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      // Keep a duplicate title field for backend functions expecting `title`
      'title': name,
      'time': Timestamp.fromDate(time),
      'isCompleted': isCompleted,
      'deviceToken': deviceToken,
      'userId': userId,
      if (notifiedAt != null) 'notifiedAt': Timestamp.fromDate(notifiedAt!),
      if (recurrence != null) 'recurrence': recurrence,
      if (nextDueAt != null) 'nextDueAt': Timestamp.fromDate(nextDueAt!),
      if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
      if (colorValue != null) 'colorValue': colorValue,
      if (notes != null) 'notes': notes,
      'autoSnoozeEnabled': autoSnoozeEnabled,
      'autoSnoozeInterval': autoSnoozeInterval,
      'autoSnoozeMaxCount': autoSnoozeMaxCount,
      'autoSnoozeCount': autoSnoozeCount,
      if (consistency != null) 'consistency': consistency!.toMap(),
    };
  }

  // Create Reminder from Firestore document
  factory Reminder.fromMap(Map<String, dynamic> map, String documentId) {
    return Reminder(
      id: documentId,
      name: map['name'] ?? map['title'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
      isCompleted: map['isCompleted'] ?? false,
      deviceToken: map['deviceToken'],
      userId: map['userId'] ?? 'demo_user',
      notifiedAt: map['notifiedAt'] != null 
          ? (map['notifiedAt'] as Timestamp).toDate() 
          : null,
        recurrence: map['recurrence'] as Map<String, dynamic>?,
        nextDueAt: map['nextDueAt'] != null
          ? (map['nextDueAt'] as Timestamp).toDate()
          : null,
      iconCodePoint: map['iconCodePoint'] as int?,
      colorValue: map['colorValue'] as int?,
      notes: map['notes'] as String?,
      autoSnoozeEnabled: map['autoSnoozeEnabled'] ?? false,
      autoSnoozeInterval: map['autoSnoozeInterval'] ?? 10,
      autoSnoozeMaxCount: map['autoSnoozeMaxCount'] ?? 3,
      autoSnoozeCount: map['autoSnoozeCount'] ?? 0,
      consistency: map['consistency'] != null
          ? ConsistencyData.fromMap(map['consistency'] as Map<String, dynamic>)
          : null,
    );
  }

  // Check if reminder is completed for today
  bool get isCompletedToday {
    // For non-recurring reminders, check isCompleted flag
    if (recurrence == null) {
      return isCompleted;
    }
    
    // For recurring reminders, check if today is in completedDates
    if (consistency != null) {
      final today = DateTime.now();
      final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      return consistency!.wasCompletedOnDate(todayStr);
    }
    
    return false;
  }

  // Create a copy with updated fields
  Reminder copyWith({
    String? id,
    String? name,
    DateTime? time,
    bool? isCompleted,
    String? deviceToken,
    String? userId,
    DateTime? notifiedAt,
    Map<String, dynamic>? recurrence,
    DateTime? nextDueAt,
    int? iconCodePoint,
    int? colorValue,
    String? notes,
    bool? autoSnoozeEnabled,
    int? autoSnoozeInterval,
    int? autoSnoozeMaxCount,
    int? autoSnoozeCount,
    ConsistencyData? consistency,
  }) {
    return Reminder(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      deviceToken: deviceToken ?? this.deviceToken,
      userId: userId ?? this.userId,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      recurrence: recurrence ?? this.recurrence,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      notes: notes ?? this.notes,
      autoSnoozeEnabled: autoSnoozeEnabled ?? this.autoSnoozeEnabled,
      autoSnoozeInterval: autoSnoozeInterval ?? this.autoSnoozeInterval,
      autoSnoozeMaxCount: autoSnoozeMaxCount ?? this.autoSnoozeMaxCount,
      autoSnoozeCount: autoSnoozeCount ?? this.autoSnoozeCount,
      consistency: consistency ?? this.consistency,
    );
  }
  
  // Helper to get icon as IconData
  IconData get icon => iconCodePoint != null 
      ? IconData(iconCodePoint!, fontFamily: 'MaterialIcons')
      : Icons.notification_important_outlined;
  
  // Helper to get color as Color
  Color get color => colorValue != null 
      ? Color(colorValue!)
      : const Color(0xFFFFB4A3);
  
  // Calculate consistency percentage
  double get consistencyPercentage {
    if (consistency == null) {
      return 0.0;
    }
    return consistency!.percentage;
  }
}
