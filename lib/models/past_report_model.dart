import 'package:cloud_firestore/cloud_firestore.dart';

/// Geçmiş ilişki raporlarını temsil eden veri modeli
class PastReport {
  final String id;
  final String reportText;
  final String relationshipType;
  final List<String> suggestions;
  final List<String> questions;
  final List<String> answers;
  final DateTime createdAt;

  PastReport({
    required this.id,
    required this.reportText,
    required this.relationshipType,
    required this.suggestions,
    required this.questions,
    required this.answers,
    required this.createdAt,
  });

  factory PastReport.fromFirestore(DocumentSnapshot doc, {List<String>? questions}) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Önerileri listeye dönüştür, yoksa boş liste döndür
    List<String> getSuggestions(dynamic suggestions) {
      if (suggestions == null) return [];
      if (suggestions is List) {
        return suggestions.map((e) => e.toString()).toList();
      }
      if (suggestions is String) {
        return [suggestions];
      }
      return [];
    }
    
    return PastReport(
      id: doc.id,
      reportText: data['report'] ?? '',
      relationshipType: data['relationship_type'] ?? '',
      suggestions: getSuggestions(data['suggestions']),
      questions: questions ?? [],
      answers: (data['answers'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }
  
  // Kısaltılmış içerik metni (ilk 80 karakter)
  String get shortContent {
    if (reportText.length <= 80) return reportText;
    return '${reportText.substring(0, 77)}...';
  }
  
  // Tarih formatı (gün.ay.yıl saat:dakika)
  String get formattedDate {
    return '${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }
  
  Map<String, dynamic> toMap() {
    return {
      'report': reportText,
      'relationship_type': relationshipType,
      'suggestions': suggestions,
      'answers': answers,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
} 