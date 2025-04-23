import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/past_analysis_model.dart';
import '../models/message.dart';

class PastAnalysesViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<PastAnalysis> _analyses = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<PastAnalysis> get analyses => _analyses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasAnalyses => _analyses.isNotEmpty;

  // Yükleme ve hata yardımcı metodları
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    if (error != null) {
      _isLoading = false;
    }
    notifyListeners();
  }

  // Kullanıcının tüm geçmiş analizlerini yükleme
  Future<void> loadUserAnalyses(String userId) async {
    _setLoading(true);
    try {
      // İlk olarak message koleksiyonuna erişim
      final userRef = _firestore.collection('users').doc(userId);
      
      // Kullanıcının mesajlarını al
      final messagesSnapshot = await userRef.collection('messages').get();
      
      // Analiz edilmiş mesajları filtreleme ve işleme
      List<PastAnalysis> loadedAnalyses = [];
      
      for (final messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        final Message message = Message.fromMap(messageData, docId: messageDoc.id);
        
        // Sadece analiz edilmiş mesajları işle
        if (message.isAnalyzed && message.analysisResult != null) {
          // Analiz sonucundan PastAnalysis oluştur
          final analysis = PastAnalysis(
            id: message.analysisResult!.id,
            messageId: message.id,
            messageContent: message.content,
            emotion: message.analysisResult!.emotion,
            intent: message.analysisResult!.intent,
            tone: message.analysisResult!.tone,
            severity: message.analysisResult!.severity,
            summary: message.analysisResult!.aiResponse['summary'] ?? '',
            createdAt: message.analysisResult!.createdAt,
            imageUrl: message.imageUrl,
          );
          
          loadedAnalyses.add(analysis);
        }
      }
      
      // Tarihe göre sırala (en yeniden en eskiye)
      loadedAnalyses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      _analyses = loadedAnalyses;
      notifyListeners();
      
    } catch (e) {
      _setError('Geçmiş analizler yüklenirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Belirli bir analizi ID'ye göre getirme
  PastAnalysis? getAnalysisById(String analysisId) {
    return _analyses.firstWhere(
      (analysis) => analysis.id == analysisId,
      orElse: () => throw Exception('Analiz bulunamadı: $analysisId'),
    );
  }
  
  // Belirli bir mesaja ait tüm analizleri getirme
  List<PastAnalysis> getAnalysesForMessage(String messageId) {
    return _analyses.where((analysis) => analysis.messageId == messageId).toList();
  }
  
  // Merkezi veri silme fonksiyonu - Tüm analiz tiplerini siler
  Future<void> clearAllAnalysisData(String userId) async {
    _setLoading(true);
    try {
      // Kullanıcının mesajlarını al
      final userRef = _firestore.collection('users').doc(userId);
      final messagesSnapshot = await userRef.collection('messages').get();
      
      // Batch işlemi başlat
      WriteBatch batch = _firestore.batch();
      
      // 1. Mesajlardaki analiz sonuçlarını sil
      for (final messageDoc in messagesSnapshot.docs) {
        final messageData = messageDoc.data();
        final Message message = Message.fromMap(messageData, docId: messageDoc.id);
        
        // Eğer mesaj analiz edilmişse
        if (message.isAnalyzed && message.analysisResult != null) {
          final messageRef = userRef.collection('messages').doc(messageDoc.id);
          
          // Analiz sonuçlarını sil, diğer mesaj verilerini koru
          batch.update(messageRef, {
            'isAnalyzed': false,
            'analysisResult': null,
          });
        }
      }
      
      // 2. Metin dosyası analizlerini sil
      final textAnalysesSnapshot = await userRef.collection('text_analyses').get();
      for (final textDoc in textAnalysesSnapshot.docs) {
        batch.delete(textDoc.reference);
      }
      
      // 3. Görsel analizlerini sil
      final imageAnalysesSnapshot = await userRef.collection('image_analyses').get();
      for (final imageDoc in imageAnalysesSnapshot.docs) {
        batch.delete(imageDoc.reference);
      }
      
      // 4. Danışma sonuçlarını sil
      final consultationSnapshot = await userRef.collection('consultations').get();
      for (final consultDoc in consultationSnapshot.docs) {
        batch.delete(consultDoc.reference);
      }
      
      // Batch işlemini uygula
      await batch.commit();
      
      // Yerel verileri temizle
      _analyses = [];
      notifyListeners();
      
      debugPrint('Tüm analiz tipleri başarıyla silindi');
    } catch (e) {
      _setError('Analizler silinirken hata oluştu: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Tüm analiz verilerini silme (verileri sıfırla için)
  Future<void> clearAllAnalyses(String userId) async {
    return clearAllAnalysisData(userId);
  }
} 