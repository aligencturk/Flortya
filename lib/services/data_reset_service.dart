import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Veri sıfırlama işlemlerini yöneten servis sınıfı.
/// Bu servis, farklı veri türleri için ayrı silme işlemlerini
/// ve toplu silme işlemlerini yönetir.
class DataResetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// İlişki değerlendirme verilerini siler
  /// Sadece 'relationship_reports' koleksiyonundaki verileri hedefler
  Future<bool> resetRelationshipData(String userId) async {
    debugPrint('İlişki değerlendirme verileri siliniyor...');
    
    try {
      // Kullanıcının raporlarını al
      final reportsSnapshot = await _firestore
          .collection('relationship_reports')
          .where('userId', isEqualTo: userId)
          .get();
      
      if (reportsSnapshot.docs.isEmpty) {
        debugPrint('Silinecek ilişki değerlendirmesi verisi bulunamadı');
        return true;
      }
      
      // Batch işlemi başlat
      WriteBatch batch = _firestore.batch();
      
      // Her raporu silme işlemine ekle
      for (var doc in reportsSnapshot.docs) {
        // Önce yorumları sil
        final commentsSnapshot = await _firestore
            .collection('relationship_reports')
            .doc(doc.id)
            .collection('comments')
            .get();
            
        for (var commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
        }
        
        // Sonra rapor belgesini sil
        batch.delete(doc.reference);
      }
      
      // Firestore'daki user verisini güncelle - ilişki geçmişini sıfırla
      batch.update(
        _firestore.collection('users').doc(userId),
        {
          'relationshipHistory': [],
          'lastRelationshipReport': null
        }
      );
      
      // Batch işlemini uygula
      await batch.commit();
      
      debugPrint('İlişki değerlendirme verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('İlişki değerlendirme verileri silinirken hata: $e');
      return false;
    }
  }
  
  /// Mesaj koçu verilerini siler
  /// Firestore'da 'message_coach' koleksiyonundaki kullanıcı verilerini hedefler
  Future<bool> resetMessageCoachData(String userId) async {
    debugPrint('Mesaj koçu verileri siliniyor...');
    
    try {
      // Batch işlemi başlat
      WriteBatch batch = _firestore.batch();
      
      // Kullanıcının referansı
      final userRef = _firestore.collection('users').doc(userId);
      
      // 1. Mesaj koçu analizlerini sil
      final coachAnalysesSnapshot = await userRef.collection('message_coach_analyses').get();
      for (final analysisDoc in coachAnalysesSnapshot.docs) {
        batch.delete(analysisDoc.reference);
      }
      
      // 2. User belgesindeki koç verileri alanlarını sıfırla
      batch.update(userRef, {
        'lastMessageCoachData': null,
        'messageCoachHistory': []
      });
      
      // Batch işlemini uygula
      await batch.commit();
      
      debugPrint('Mesaj koçu verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Mesaj koçu verileri silinirken hata: $e');
      return false;
    }
  }
  
  /// Mesaj analizlerini siler
  /// Hem mesaj analiz sonuçlarını hem de text, image analizlerini siler
  Future<bool> resetMessageAnalysisData(String userId) async {
    debugPrint('Mesaj analiz verileri siliniyor...');
    
    try {
      // Batch işlemi başlat
      WriteBatch batch = _firestore.batch();
      
      // Kullanıcının referansı
      final userRef = _firestore.collection('users').doc(userId);
      
      // 1. Ana mesaj koleksiyonundaki analiz sonuçlarını sıfırla
      final messagesSnapshot = await userRef.collection('messages').get();
      for (final messageDoc in messagesSnapshot.docs) {
        final messageRef = userRef.collection('messages').doc(messageDoc.id);
        
        // Veri yapısını bozmadan sadece analiz sonuçlarını sil
        batch.update(messageRef, {
          'isAnalyzed': false,
          'analysisResult': null
        });
      }
      
      // 2. Text dosyası analizlerini sil
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
      
      // 5. User belgesindeki analiz verilerini sıfırla
      batch.update(userRef, {
        'sonAnalizSonucu': null,
        'analizGecmisi': []
      });
      
      // Batch işlemini uygula
      await batch.commit();
      
      debugPrint('Mesaj analiz verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Mesaj analiz verileri silinirken hata: $e');
      return false;
    }
  }
  
  /// Tüm verileri siler
  /// Hem ilişki değerlendirme verilerini hem de mesaj analizlerini hedefler
  Future<bool> resetAllData(String userId) async {
    debugPrint('Tüm veriler siliniyor...');
    
    try {
      // İlişki değerlendirmelerini sil
      bool relationshipResult = await resetRelationshipData(userId);
      
      // Mesaj analizlerini sil
      bool messageResult = await resetMessageAnalysisData(userId);
      
      // Mesaj koçu verilerini sil
      bool coachResult = await resetMessageCoachData(userId);
      
      // Ek olarak kullanıcı ana verilerini de sıfırla
      await _firestore.collection('users').doc(userId).update({
        'sonAnalizSonucu': null,
        'analizGecmisi': [],
        'lastRelationshipReport': null,
        'relationshipHistory': [],
        'lastMessageCoachData': null,
        'messageCoachHistory': [],
        'preferences.lastResetDate': FieldValue.serverTimestamp()
      });
      
      debugPrint('Tüm veriler başarıyla silindi. İlişki: $relationshipResult, Mesaj: $messageResult, Koç: $coachResult');
      return relationshipResult && messageResult && coachResult;
    } catch (e) {
      debugPrint('Tüm veriler silinirken hata: $e');
      return false;
    }
  }
} 