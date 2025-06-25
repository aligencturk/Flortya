import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_coach_analysis.dart';
import '../models/message_coach_visual_analysis.dart';
import '../services/encryption_service.dart';

class PastMessageCoachAnalysis {
  final String id;
  final String userId;
  final DateTime createdAt;
  final String sohbetIcerigi;
  final String? aciklama;
  final bool isVisualAnalysis;
  final Map<String, dynamic> analysisData;
  
  // Görsel analiz için ek alan
  final String? imageUrl;
  
  PastMessageCoachAnalysis({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.sohbetIcerigi,
    this.aciklama,
    required this.isVisualAnalysis,
    required this.analysisData,
    this.imageUrl,
  });
  
  // Firestore dökümanından model oluşturma (şifreli verileri çözme)
  factory PastMessageCoachAnalysis.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Şifreli verileri çöz
    String sohbetIcerigi = '';
    String? aciklama;
    Map<String, dynamic> analysisData = {};
    
    try {
      // Sohbet içeriğini çöz
      final encryptedSohbetIcerigi = data['sohbetIcerigi'] ?? '';
      if (encryptedSohbetIcerigi.isNotEmpty) {
        sohbetIcerigi = EncryptionService().decryptString(encryptedSohbetIcerigi);
      }
      
      // Açıklamayı çöz
      final encryptedAciklama = data['aciklama'];
      if (encryptedAciklama != null && encryptedAciklama.isNotEmpty) {
        aciklama = EncryptionService().decryptString(encryptedAciklama);
      }
      
      // Analiz verilerini çöz
      final encryptedAnalysisData = data['analysisData'];
      if (encryptedAnalysisData is String && encryptedAnalysisData.isNotEmpty) {
        analysisData = EncryptionService().decryptJson(encryptedAnalysisData);
      } else if (encryptedAnalysisData is Map<String, dynamic>) {
        // Geriye dönük uyumluluk için şifrelenmemiş veri desteği
        analysisData = encryptedAnalysisData;
      }
    } catch (e) {
      print('Mesaj koçu verisi çözülürken hata: $e');
      // Hata durumunda orijinal veriyi kullan
      sohbetIcerigi = data['sohbetIcerigi'] ?? '';
      aciklama = data['aciklama'];
      analysisData = data['analysisData'] ?? {};
    }
    
    return PastMessageCoachAnalysis(
      id: doc.id,
      userId: data['userId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      sohbetIcerigi: sohbetIcerigi,
      aciklama: aciklama,
      isVisualAnalysis: data['isVisualAnalysis'] ?? false,
      analysisData: analysisData,
      imageUrl: data['imageUrl'],
    );
  }
  
  // Modeli Firestore için Map'e dönüştürme
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'sohbetIcerigi': sohbetIcerigi,
      'aciklama': aciklama,
      'isVisualAnalysis': isVisualAnalysis,
      'analysisData': analysisData,
      'imageUrl': imageUrl,
    };
  }
  
  // Mesaj koçu analizi verisini MessageCoachAnalysis nesnesine dönüştürme
  MessageCoachAnalysis? toMessageCoachAnalysis() {
    if (isVisualAnalysis) return null;
    
    try {
      return MessageCoachAnalysis.from(analysisData);
    } catch (e) {
      print('❌ Mesaj koçu analizi dönüştürme hatası: $e');
      return null;
    }
  }
  
  // Görsel analiz verisini MessageCoachVisualAnalysis nesnesine dönüştürme
  MessageCoachVisualAnalysis? toMessageCoachVisualAnalysis() {
    if (!isVisualAnalysis) return null;
    
    try {
      final isAnalysisRedirect = analysisData['isAnalysisRedirect'] ?? false;
      final redirectMessage = analysisData['redirectMessage'] as String?;
      final konumDegerlendirmesi = analysisData['konumDegerlendirmesi'] as String?;
      
      // Alternatif mesajlar
      List<String> alternativeMessages = [];
      if (analysisData['alternativeMessages'] != null) {
        if (analysisData['alternativeMessages'] is List) {
          alternativeMessages = (analysisData['alternativeMessages'] as List)
              .map((item) => item.toString())
              .toList();
        } else if (analysisData['alternativeMessages'] is String) {
          alternativeMessages = [analysisData['alternativeMessages'] as String];
        }
      }
      
      // Partner yanıtları
      List<String> partnerResponses = [];
      if (analysisData['partnerResponses'] != null) {
        if (analysisData['partnerResponses'] is List) {
          partnerResponses = (analysisData['partnerResponses'] as List)
              .map((item) => item.toString())
              .toList();
        } else if (analysisData['partnerResponses'] is String) {
          partnerResponses = [analysisData['partnerResponses'] as String];
        }
      }
      
      return MessageCoachVisualAnalysis(
        isAnalysisRedirect: isAnalysisRedirect,
        redirectMessage: redirectMessage,
        konumDegerlendirmesi: konumDegerlendirmesi,
        alternativeMessages: alternativeMessages,
        partnerResponses: partnerResponses,
      );
    } catch (e) {
      print('❌ Görsel analiz dönüştürme hatası: $e');
      return null;
    }
  }
  
  // Özet açıklama oluşturma
  String getOzet() {
    if (isVisualAnalysis) {
      return 'Görsel Analiz: ${aciklama ?? 'Açıklama yok'}';
    } else {
      final analiz = toMessageCoachAnalysis();
      return analiz?.genelYorum ?? 'Analiz yok';
    }
  }
  
  // Tarih formatında string oluşturma
  String getFormattedDate() {
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year;
    final hour = createdAt.hour.toString().padLeft(2, '0');
    final minute = createdAt.minute.toString().padLeft(2, '0');
    
    return '$day.$month.$year $hour:$minute';
  }
} 