// ============================================================================
// EXAMPLE: How to use the Recurrence System from Flutter
// ============================================================================
// This file is for reference only - showing how your Flutter app would
// interact with the recurrence Cloud Functions.
//
// Place this in your Flutter app's services or repositories layer.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for managing reminder recurrence
class ReminderRecurrenceService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  
  ReminderRecurrenceService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // ==========================================================================
  // COMPLETE A REMINDER
  // ==========================================================================
  
  /// Complete a reminder and calculate the next occurrence
  /// 
  /// Returns the next due date as an ISO string, or null if no recurrence
  Future<CompleteReminderResult> completeReminder({
    required String reminderId,
    int? currentVersion,
    DateTime? completedAt,
  }) async {
    try {
      final callable = _functions.httpsCallable('completeReminder');
      
      final result = await callable.call<Map<String, dynamic>>({
        'reminderId': reminderId,
        if (currentVersion != null) 'currentVersion': currentVersion,
        if (completedAt != null) 'completedAt': completedAt.millisecondsSinceEpoch,
      });

      final data = result.data;
      
      return CompleteReminderResult(
        success: data['success'] as bool,
        duplicate: data['duplicate'] as bool? ?? false,
        nextDueAt: data['nextDueAt'] != null 
            ? DateTime.parse(data['nextDueAt'] as String)
            : null,
        hasRecurrence: data['hasRecurrence'] as bool? ?? false,
      );
    } catch (e) {
      throw ReminderRecurrenceException('Failed to complete reminder: $e');
    }
  }

  // ==========================================================================
  // UPDATE RECURRENCE RULE
  // ==========================================================================
  
  /// Update the recurrence rule for a reminder
  Future<UpdateRecurrenceResult> updateRecurrence({
    required String reminderId,
    required RecurrenceConfig recurrence,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateReminderRecurrence');
      
      final result = await callable.call<Map<String, dynamic>>({
        'reminderId': reminderId,
        'recurrence': recurrence.toJson(),
      });

      final data = result.data;
      
      return UpdateRecurrenceResult(
        success: data['success'] as bool,
        nextDueAt: data['nextDueAt'] != null 
            ? DateTime.parse(data['nextDueAt'] as String)
            : null,
      );
    } catch (e) {
      throw ReminderRecurrenceException('Failed to update recurrence: $e');
    }
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

/// Result from completing a reminder
class CompleteReminderResult {
  final bool success;
  final bool duplicate;  // True if already processed
  final DateTime? nextDueAt;
  final bool hasRecurrence;

  CompleteReminderResult({
    required this.success,
    required this.duplicate,
    this.nextDueAt,
    required this.hasRecurrence,
  });
}

/// Result from updating recurrence
class UpdateRecurrenceResult {
  final bool success;
  final DateTime? nextDueAt;

  UpdateRecurrenceResult({
    required this.success,
    this.nextDueAt,
  });
}

/// Recurrence configuration for a reminder
class RecurrenceConfig {
  final RecurrenceType type;
  
  // For interval-based recurrence
  final int? every;
  final TimeUnit? unit;
  final AnchorType? anchor;
  
  // For weekly recurrence
  final List<Weekday>? days;
  final String? time;  // "HH:mm" format
  
  // For monthly recurrence
  final MonthlyPattern? pattern;
  final int? value;

  RecurrenceConfig.interval({
    required this.every,
    required this.unit,
    this.anchor = AnchorType.completion,
  })  : type = RecurrenceType.interval,
        days = null,
        time = null,
        pattern = null,
        value = null;

  RecurrenceConfig.weekly({
    required this.days,
    required this.time,
  })  : type = RecurrenceType.weekly,
        every = null,
        unit = null,
        anchor = null,
        pattern = null,
        value = null;

  RecurrenceConfig.monthly({
    required this.pattern,
    required this.value,
    required this.time,
  })  : type = RecurrenceType.monthly,
        every = null,
        unit = null,
        anchor = null,
        days = null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type.name,
    };

    if (every != null) json['every'] = every;
    if (unit != null) json['unit'] = unit!.name;
    if (anchor != null) json['anchor'] = anchor!.name;
    if (days != null) json['days'] = days!.map((d) => d.name).toList();
    if (time != null) json['time'] = time;
    if (pattern != null) json['pattern'] = pattern!.name;
    if (value != null) json['value'] = value;

    return json;
  }
}

// ============================================================================
// ENUMS
// ============================================================================

enum RecurrenceType { interval, weekly, monthly }

enum TimeUnit { minutes, hours, days }

enum AnchorType { completion, scheduled }

enum Weekday { sun, mon, tue, wed, thu, fri, sat }

enum MonthlyPattern { dayOfMonth, nthWeekday }

// ============================================================================
// EXCEPTIONS
// ============================================================================

class ReminderRecurrenceException implements Exception {
  final String message;
  ReminderRecurrenceException(this.message);
  
  @override
  String toString() => 'ReminderRecurrenceException: $message';
}

// ============================================================================
// USAGE EXAMPLES
// ============================================================================

void exampleUsage() async {
  final service = ReminderRecurrenceService();
  
  // Example 1: Complete a reminder
  final result = await service.completeReminder(
    reminderId: 'workout-123',
    currentVersion: 5,
  );
  
  if (result.duplicate) {
    print('Already completed this reminder');
  } else if (result.hasRecurrence) {
    print('Next workout: ${result.nextDueAt}');
  } else {
    print('One-time reminder completed');
  }
  
  // Example 2: Set up interval recurrence (every 3 days)
  await service.updateRecurrence(
    reminderId: 'water-plants-123',
    recurrence: RecurrenceConfig.interval(
      every: 3,
      unit: TimeUnit.days,
      anchor: AnchorType.scheduled,
    ),
  );
  
  // Example 3: Set up weekly recurrence (Mon/Wed/Fri at 9am)
  await service.updateRecurrence(
    reminderId: 'workout-123',
    recurrence: RecurrenceConfig.weekly(
      days: [Weekday.mon, Weekday.wed, Weekday.fri],
      time: '09:00',
    ),
  );
  
  // Example 4: Set up monthly recurrence (15th of each month)
  await service.updateRecurrence(
    reminderId: 'rent-123',
    recurrence: RecurrenceConfig.monthly(
      pattern: MonthlyPattern.dayOfMonth,
      value: 15,
      time: '09:00',
    ),
  );
}

// ============================================================================
// REMINDER MODEL EXAMPLE
// ============================================================================

class Reminder {
  final String id;
  final String title;
  final String status;
  final DateTime nextDueAt;
  final RecurrenceConfig? recurrence;
  final DateTime? lastCompletedAt;
  final DateTime updatedAt;
  final int version;

  Reminder({
    required this.id,
    required this.title,
    required this.status,
    required this.nextDueAt,
    this.recurrence,
    this.lastCompletedAt,
    required this.updatedAt,
    required this.version,
  });

  factory Reminder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Reminder(
      id: doc.id,
      title: data['title'] as String,
      status: data['status'] as String,
      nextDueAt: (data['nextDueAt'] as Timestamp).toDate(),
      recurrence: data['recurrence'] != null 
          ? _parseRecurrence(data['recurrence'] as Map<String, dynamic>)
          : null,
      lastCompletedAt: data['lastCompletedAt'] != null
          ? (data['lastCompletedAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      version: data['version'] as int? ?? 1,
    );
  }

  static RecurrenceConfig? _parseRecurrence(Map<String, dynamic> data) {
    final type = data['type'] as String;
    
    switch (type) {
      case 'interval':
        return RecurrenceConfig.interval(
          every: data['every'] as int? ?? 1,
          unit: TimeUnit.values.firstWhere(
            (u) => u.name == (data['unit'] as String? ?? 'days'),
          ),
          anchor: data['anchor'] != null
              ? AnchorType.values.firstWhere((a) => a.name == data['anchor'])
              : AnchorType.completion,
        );
        
      case 'weekly':
        return RecurrenceConfig.weekly(
          days: (data['days'] as List<dynamic>)
              .map((d) => Weekday.values.firstWhere((w) => w.name == d))
              .toList(),
          time: data['time'] as String,
        );
        
      case 'monthly':
        return RecurrenceConfig.monthly(
          pattern: MonthlyPattern.values.firstWhere(
            (p) => p.name == (data['pattern'] as String),
          ),
          value: data['value'] as int,
          time: data['time'] as String,
        );
        
      default:
        return null;
    }
  }
}
