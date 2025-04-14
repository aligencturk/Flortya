import 'package:cloud_firestore/cloud_firestore.dart';
import 'analysis_result_model.dart';

class Message {
  final String id;
  final String content;
  final DateTime sentAt;
  final bool sentByUser;
  final bool isAnalyzed;
  final String? imageUrl;
  final AnalysisResult? analysisResult;
  final String? userId;

  Message({
    required this.id,
    required this.content,
    required this.sentAt,
    required this.sentByUser,
    this.isAnalyzed = false,
    this.imageUrl,
    this.analysisResult,
    this.userId,
  });

  Message copyWith({
    String? id,
    String? content,
    DateTime? sentAt,
    bool? sentByUser,
    bool? isAnalyzed,
    String? imageUrl,
    AnalysisResult? analysisResult,
    String? userId,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      sentByUser: sentByUser ?? this.sentByUser,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      imageUrl: imageUrl ?? this.imageUrl,
      analysisResult: analysisResult ?? this.analysisResult,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sentAt': Timestamp.fromDate(sentAt),
      'sentByUser': sentByUser,
      'isAnalyzed': isAnalyzed,
      'imageUrl': imageUrl,
      'analysisResult': analysisResult?.toMap(),
      'userId': userId,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, String documentId) {
    try {
      // ID kontrolü - documentId veya map['id'] kullan (documentId öncelikli)
      final String messageId = documentId.isNotEmpty 
          ? documentId 
          : (map['id'] as String? ?? '');
          
      if (messageId.isEmpty) {
        print('UYARI: Boş mesaj ID oluşturuluyor. Bu, Firestore sorgularında sorunlara neden olabilir.');
      }
      
      // Mesaj içeriği kontrolü
      final String content = map['content'] as String? ?? '';
      
      // sentByUser değeri kontrolü
      final bool sentByUser = map['sentByUser'] as bool? ?? true;
      
      // sentAt tarih kontrolü - birden fazla format destekle
      DateTime sentAt = DateTime.now();
      final dynamic rawSentAt = map['sentAt'];
      
      if (rawSentAt != null) {
        if (rawSentAt is Timestamp) {
          sentAt = rawSentAt.toDate();
        } else if (rawSentAt is DateTime) {
          sentAt = rawSentAt;
        } else if (rawSentAt is int) {
          // Unix timestamp (milisaniye) olarak
          sentAt = DateTime.fromMillisecondsSinceEpoch(rawSentAt);
        } else if (rawSentAt is String) {
          // ISO string olarak
          try {
            sentAt = DateTime.parse(rawSentAt);
          } catch (e) {
            print('UYARI: Tarih ayrıştırma hatası: $e');
          }
        } else {
          print('UYARI: Bilinmeyen sentAt tipi: ${rawSentAt.runtimeType}');
        }
      }
      
      // Analiz durumu kontrolü
      final bool isAnalyzed = map['isAnalyzed'] as bool? ?? false;
      
      // Analiz sonucu kontrolü
      AnalysisResult? analysisResult;
      if (map['analysisResult'] != null && isAnalyzed) {
        try {
          analysisResult = AnalysisResult.fromMap(map['analysisResult'] as Map<String, dynamic>);
        } catch (e) {
          print('UYARI: AnalysisResult ayrıştırma hatası: $e');
        }
      }
      
      return Message(
        id: messageId,
        content: content, 
        sentByUser: sentByUser,
        sentAt: sentAt,
        isAnalyzed: isAnalyzed,
        analysisResult: analysisResult,
      );
    } catch (e) {
      print('HATA: Message.fromMap sırasında beklenmeyen hata: $e');
      // Hata durumunda varsayılan bir Message döndür
      return Message(
        id: documentId.isNotEmpty ? documentId : '',
        content: map['content'] as String? ?? 'Mesaj yüklenemedi',
        sentByUser: map['sentByUser'] as bool? ?? true,
        sentAt: DateTime.now(),
        isAnalyzed: false,
      );
    }
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, sentAt: $sentAt, sentByUser: $sentByUser, isAnalyzed: $isAnalyzed, imageUrl: $imageUrl, userId: $userId)';
  }
} 