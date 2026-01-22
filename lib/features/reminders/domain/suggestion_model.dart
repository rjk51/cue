import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  final String id;
  final String reminderId;
  final String userId;
  final String title;
  final String description;
  final String status;
  final DateTime? nextDueAt;
  final Map<String, dynamic>? recurrence;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Suggestion({
    required this.id,
    required this.reminderId,
    required this.userId,
    required this.title,
    required this.description,
    required this.status,
    required this.nextDueAt,
    required this.recurrence,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Suggestion.fromMap(Map<String, dynamic> map, String documentId) {
    return Suggestion(
      id: documentId,
      reminderId: map['reminderId'] ?? '',
      userId: map['userId'] ?? 'demo_user',
      title: map['title'] ?? map['name'] ?? 'Recurring task',
      description: map['description'] ?? '',
      status: map['status'] ?? 'active',
      nextDueAt: map['nextDueAt'] is Timestamp
          ? (map['nextDueAt'] as Timestamp).toDate()
          : null,
      recurrence: (map['recurrence'] as Map<String, dynamic>?) ?? {},
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
