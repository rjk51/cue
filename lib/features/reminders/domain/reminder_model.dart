import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String name;
  final DateTime time;
  final bool isCompleted;
  final String? deviceToken;
  final String userId;
  final DateTime? notifiedAt;

  Reminder({
    required this.id,
    required this.name,
    required this.time,
    this.isCompleted = false,
    this.deviceToken,
    required this.userId,
    this.notifiedAt,
  });

  // Convert Reminder to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'time': Timestamp.fromDate(time),
      'isCompleted': isCompleted,
      'deviceToken': deviceToken,
      'userId': userId,
      if (notifiedAt != null) 'notifiedAt': Timestamp.fromDate(notifiedAt!),
    };
  }

  // Create Reminder from Firestore document
  factory Reminder.fromMap(Map<String, dynamic> map, String documentId) {
    return Reminder(
      id: documentId,
      name: map['name'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
      isCompleted: map['isCompleted'] ?? false,
      deviceToken: map['deviceToken'],
      userId: map['userId'] ?? 'demo_user',
      notifiedAt: map['notifiedAt'] != null 
          ? (map['notifiedAt'] as Timestamp).toDate() 
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
  }) {
    return Reminder(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      isCompleted: isCompleted ?? this.isCompleted,
      deviceToken: deviceToken ?? this.deviceToken,
      userId: userId ?? this.userId,
      notifiedAt: notifiedAt ?? this.notifiedAt,
    );
  }
}
