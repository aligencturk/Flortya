import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_message.dart';

class AdviceChat {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String title;

  AdviceChat({
    required this.id,
    required this.userId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    required this.title,
  });

  factory AdviceChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> messageList = data['messages'] ?? [];
    
    return AdviceChat(
      id: doc.id,
      userId: data['userId'] ?? '',
      messages: messageList.map((m) => ChatMessage.fromMap(m)).toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      title: data['title'] ?? 'Yeni Sohbet',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'messages': messages.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'title': title,
    };
  }
} 