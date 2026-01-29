import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'recurrence_rule.dart';

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
  final Map<String, Map<String, dynamic>>? overrides; // Per-date overrides: { "YYYY-MM-DD": { time, title, skipped, ... } }

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
    this.overrides,
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
      if (overrides != null && overrides!.isNotEmpty) 'overrides': overrides,
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
      overrides: map['overrides'] != null
          ? Map<String, Map<String, dynamic>>.from(
              (map['overrides'] as Map).map(
                (key, value) => MapEntry(
                  key.toString(),
                  Map<String, dynamic>.from(value as Map),
                ),
              ),
            )
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
    Map<String, Map<String, dynamic>>? overrides,
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
      overrides: overrides ?? this.overrides,
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
  
  /// Get override for a specific date (YYYY-MM-DD format)
  Map<String, dynamic>? getOverrideForDate(String date) {
    return overrides?[date];
  }

  /// Check if a specific date is skipped
  bool isSkippedOnDate(String date) {
    final override = getOverrideForDate(date);
    return override?['skipped'] == true;
  }

  /// Get effective time for a specific date (considering overrides)
  DateTime? getEffectiveTimeForDate(String date) {
    final override = getOverrideForDate(date);
    if (override != null && override['time'] != null) {
      // Parse time string (HH:mm format) and combine with date
      final timeStr = override['time'] as String;
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = int.tryParse(parts[1]) ?? 0;
      final dateParts = date.split('-');
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        hour,
        minute,
      );
    }
    return null;
  }

  /// Get effective title for a specific date (considering overrides)
  String? getEffectiveTitleForDate(String date) {
    final override = getOverrideForDate(date);
    return override?['title'] as String?;
  }

  /// Get effective display time for the current occurrence (considering overrides)
  /// Returns the time that should be displayed, which may be overridden
  DateTime getEffectiveDisplayTime() {
    final nextDue = effectiveNextDueAt;
    final dateStr = DateFormat('yyyy-MM-dd').format(nextDue);
    final override = getOverrideForDate(dateStr);
    
    // If there's a time override, use it
    if (override != null && override['time'] != null) {
      final timeStr = override['time'] as String;
      final parts = timeStr.split(':');
      final hour = int.tryParse(parts[0]) ?? nextDue.hour;
      final minute = int.tryParse(parts[1]) ?? nextDue.minute;
      return DateTime(nextDue.year, nextDue.month, nextDue.day, hour, minute);
    }
    
    return nextDue;
  }

  /// Get effective display name for the current occurrence (considering overrides)
  String getEffectiveDisplayName() {
    final nextDue = effectiveNextDueAt;
    final dateStr = DateFormat('yyyy-MM-dd').format(nextDue);
    final overrideTitle = getEffectiveTitleForDate(dateStr);
    return overrideTitle ?? name;
  }

  /// Get the effective next due date for this reminder.
  /// For recurring reminders:
  /// - If nextDueAt hasn't been completed today, return it (even if in the past) to show missed occurrences
  /// - If nextDueAt has been completed or is in the future, return it
  /// - Otherwise, calculate the next occurrence
  /// For non-recurring reminders, returns the original time.
  DateTime get effectiveNextDueAt {
    if (recurrence == null) {
      // Non-recurring reminder - just return the original time
      return time;
    }
    
    final now = DateTime.now();
    
    // If nextDueAt exists and hasn't been completed today, show it (even if in the past)
    // This ensures missed occurrences are displayed until they're handled
    if (nextDueAt != null) {
      final nextDueDate = nextDueAt!;
      final nextDueDateStr = DateFormat('yyyy-MM-dd').format(nextDueDate);
      
      // Check if this occurrence has been completed today
      final isCompletedToday = consistency != null && 
          consistency!.wasCompletedOnDate(nextDueDateStr);
      
      // Check if this occurrence is skipped
      final isSkipped = isSkippedOnDate(nextDueDateStr);
      
      // If not completed and not skipped, show it (even if in the past)
      // This allows users to see and complete missed occurrences
      if (!isCompletedToday && !isSkipped) {
        return nextDueDate;
      }
      
      // If completed or skipped, and it's still in the future, return it
      if (nextDueDate.isAfter(now)) {
        return nextDueDate;
      }
    }
    
    // nextDueAt is null, completed, or skipped and in the past - calculate the next occurrence
    try {
      final rule = RecurrenceRule.fromBackendConfig(recurrence!);
      final nextOccurrence = rule.nextOccurrence(from: now);
      return nextOccurrence ?? time; // Fallback to original time if calculation fails
    } catch (e) {
      print('Error calculating next occurrence: $e');
      return nextDueAt ?? time; // Fallback to nextDueAt or original time
    }
  }
}
