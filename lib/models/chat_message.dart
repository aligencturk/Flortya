import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String content;
  final String role; // 'user' veya 'model'
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      content: map['content'] ?? '',
      role: map['role'] ?? 'user',
      timestamp: (map['timestamp'] is Timestamp) 
        ? (map['timestamp'] as Timestamp).toDate() 
        : DateTime.parse(map['timestamp'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'content': content,
      'role': role,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Map<String, dynamic> toApiFormat() {
    return {
      'role': role,
      'content': content,
    };
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, userId: $userId, role: $role, content: $content, timestamp: $timestamp)';
  }
} 