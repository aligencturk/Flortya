import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String userId;
  final String content;
  final DateTime timestamp;
  final bool isAnalyzed;

  Message({
    required this.id,
    required this.userId,
    required this.content,
    required this.timestamp,
    this.isAnalyzed = false,
  });

  // Firestore'dan veri okuma
  factory Message.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isAnalyzed: data['isAnalyzed'] ?? false,
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isAnalyzed': isAnalyzed,
    };
  }

  // Mesajın kopyasını oluşturma
  Message copyWith({
    String? id,
    String? userId,
    String? content,
    DateTime? timestamp,
    bool? isAnalyzed,
  }) {
    return Message(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
    );
  }
} 