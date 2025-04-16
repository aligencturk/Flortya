import 'package:cloud_firestore/cloud_firestore.dart';

/// İlişki analiz sonucunu temsil eden veri modeli
class AnalysisResult {
  final String id;
  final String messageId;
  final String emotion;
  final String intent;
  final String tone;
  final int severity;
  final String persons;
  final Map<String, dynamic> aiResponse;
  final DateTime createdAt;

  AnalysisResult({
    required this.id,
    required this.messageId,
    required this.emotion,
    required this.intent,
    required this.tone,
    required this.severity,
    this.persons = '',
    required this.aiResponse,
    required this.createdAt,
  });

  factory AnalysisResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnalysisResult(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      emotion: data['emotion'] ?? '',
      intent: data['intent'] ?? '',
      tone: data['tone'] ?? '',
      severity: data['severity'] ?? 0,
      persons: data['persons'] ?? '',
      aiResponse: data['aiResponse'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Map veri türünden doğrudan oluşturma
  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      id: map['id'] ?? '',
      messageId: map['messageId'] ?? '',
      emotion: map['emotion'] ?? '',
      intent: map['intent'] ?? '',
      tone: map['tone'] ?? '',
      severity: map['severity'] ?? 0,
      persons: map['persons'] ?? '',
      aiResponse: map['aiResponse'] ?? {},
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null ? DateTime.parse(map['createdAt'].toString()) : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'emotion': emotion,
      'intent': intent,
      'tone': tone,
      'severity': severity,
      'persons': persons,
      'aiResponse': aiResponse,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  String toString() {
    return 'AnalysisResult{id: $id, messageId: $messageId, emotion: $emotion, intent: $intent, tone: $tone, persons: $persons}';
  }
}

/// İlişki tavsiyesi sohbeti için mesaj modeli
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

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      userId: data['userId'] ?? '',
      content: data['content'] ?? '',
      role: data['role'] ?? 'user',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'content': content,
      'role': role,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  Map<String, String> toApiFormat() {
    return {
      'role': role,
      'text': content,
    };
  }

  @override
  String toString() {
    return 'ChatMessage{id: $id, role: $role, content: $content}';
  }
}

/// İlişki tavsiyesi sohbeti modeli
class AdviceChat {
  final String id;
  final String userId;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String title;

  AdviceChat({
    required this.id,
    required this.userId,
    required this.messages,
    required this.createdAt,
    this.updatedAt,
    required this.title,
  });
  
  factory AdviceChat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdviceChat(
      id: doc.id,
      userId: data['userId'] ?? '',
      messages: (data['messages'] as List<dynamic>?)
          ?.map((messageData) => ChatMessage(
                id: messageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                userId: messageData['userId'] ?? '',
                content: messageData['content'] ?? '',
                role: messageData['role'] ?? 'user',
                timestamp: (messageData['timestamp'] as Timestamp).toDate(),
              ))
          .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      title: data['title'] ?? 'İlişki Tavsiyesi Sohbeti',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'messages': messages.map((message) => message.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'title': title,
    };
  }

  @override
  String toString() {
    return 'AdviceChat{id: $id, title: $title, messageCount: ${messages.length}}';
  }
} 