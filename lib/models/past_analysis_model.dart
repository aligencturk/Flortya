import 'package:cloud_firestore/cloud_firestore.dart';

/// Geçmiş analizleri temsil eden veri modeli
class PastAnalysis {
  final String id;
  final String messageId;
  final String messageContent;
  final String emotion;
  final String intent;
  final String tone;
  final int severity;
  final String summary;
  final DateTime createdAt;
  final String? imageUrl;

  PastAnalysis({
    required this.id,
    required this.messageId,
    required this.messageContent,
    required this.emotion,
    required this.intent,
    required this.tone,
    required this.severity,
    required this.summary,
    required this.createdAt,
    this.imageUrl,
  });

  factory PastAnalysis.fromFirestore(DocumentSnapshot doc, {String? messageContent, String? imageUrl}) {
    final data = doc.data() as Map<String, dynamic>;
    final aiResponse = data['aiResponse'] as Map<String, dynamic>? ?? {};
    
    // Özet metnini al, yoksa boş string döndür
    final summary = aiResponse['summary'] as String? ?? '';
    
    return PastAnalysis(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      messageContent: messageContent ?? data['messageContent'] ?? '',
      emotion: data['emotion'] ?? '',
      intent: data['intent'] ?? '',
      tone: data['tone'] ?? '',
      severity: data['severity'] ?? 0,
      summary: summary,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      imageUrl: imageUrl ?? data['imageUrl'],
    );
  }

  // Kısaltılmış içerik metni (ilk 80 karakter)
  String get shortContent {
    if (messageContent.length <= 80) return messageContent;
    return '${messageContent.substring(0, 77)}...';
  }

  // Tarih formatı (gün.ay.yıl saat:dakika)
  String get formattedDate {
    return '${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'messageContent': messageContent,
      'emotion': emotion,
      'intent': intent,
      'tone': tone,
      'severity': severity,
      'summary': summary,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
    };
  }
} 