import 'package:cloud_firestore/cloud_firestore.dart';

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
    );
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
    );
  }
}
