import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisResult {
  final String id;
  final String messageId;
  final String emotion; // Örn: "mutlu", "kızgın", "üzgün"
  final String intent; // Örn: "bilgi isteme", "şikayet", "övgü"
  final String tone; // Örn: "samimi", "resmi", "sert"
  final int severity; // 1-10 arası bir değer, mesajın ciddiyeti
  final Map<String, dynamic> aiResponse; // AI'dan gelen detaylı yanıt
  final DateTime createdAt;

  AnalysisResult({
    required this.id,
    required this.messageId,
    required this.emotion,
    required this.intent,
    required this.tone,
    required this.severity,
    required this.aiResponse,
    required this.createdAt,
  });

  // Firestore'dan veri okuma
  factory AnalysisResult.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AnalysisResult(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      emotion: data['emotion'] ?? '',
      intent: data['intent'] ?? '',
      tone: data['tone'] ?? '',
      severity: data['severity'] ?? 5,
      aiResponse: data['aiResponse'] ?? {},
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toFirestore() {
    return {
      'messageId': messageId,
      'emotion': emotion,
      'intent': intent,
      'tone': tone,
      'severity': severity,
      'aiResponse': aiResponse,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // AnalysisResult'ın kopyasını oluşturma
  AnalysisResult copyWith({
    String? id,
    String? messageId,
    String? emotion,
    String? intent,
    String? tone,
    int? severity,
    Map<String, dynamic>? aiResponse,
    DateTime? createdAt,
  }) {
    return AnalysisResult(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      emotion: emotion ?? this.emotion,
      intent: intent ?? this.intent,
      tone: tone ?? this.tone,
      severity: severity ?? this.severity,
      aiResponse: aiResponse ?? this.aiResponse,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 