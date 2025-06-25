import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      
      // 2. Mesaj koçu geçmişi koleksiyonundaki verileri sil
      final messageCoachHistorySnapshot = await _firestore
          .collection('message_coach_history')
          .where('userId', isEqualTo: userId)
          .get();
      
      final int messageCoachCount = messageCoachHistorySnapshot.docs.length;
      debugPrint('Silinecek mesaj koçu geçmişi sayısı: $messageCoachCount');
      
      for (final historyDoc in messageCoachHistorySnapshot.docs) {
        batch.delete(historyDoc.reference);
      }
      
      // 3. User belgesindeki koç verileri alanlarını sıfırla
      batch.update(userRef, {
        'lastMessageCoachData': null,
        'messageCoachHistory': []
      });
      
      // Batch işlemini uygula
      await batch.commit();
      
      // Silme işleminin tamamlanması için 2 saniye bekleme
      await Future.delayed(const Duration(seconds: 2));
      
      // Doğrulama kontrolü
      final verificationQuery = await _firestore
          .collection('message_coach_history')
          .where('userId', isEqualTo: userId)
          .get();
          
      if (verificationQuery.docs.isNotEmpty) {
        debugPrint('Silme işlemi tamamlanmasına rağmen ${verificationQuery.docs.length} adet mesaj koçu kaydı hala mevcut. Tekrar silme deneniyor...');
        
        // İkinci kez silme girişimi
        final secondBatch = _firestore.batch();
        for (var doc in verificationQuery.docs) {
          secondBatch.delete(doc.reference);
        }
        
        await secondBatch.commit();
        debugPrint('İkinci silme işlemi tamamlandı.');
        
        // Son bir kontrol daha yap
        await Future.delayed(const Duration(seconds: 1));
        final finalCheck = await _firestore
            .collection('message_coach_history')
            .where('userId', isEqualTo: userId)
            .get();
            
        if (finalCheck.docs.isNotEmpty) {
          debugPrint('İkinci silme işlemi sonrası hala ${finalCheck.docs.length} adet kayıt mevcut!');
          return false;
        }
      }
      
      debugPrint('Mesaj koçu verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Mesaj koçu verileri silinirken hata: $e');
      return false;
    }
  }
  
  /// Wrapped (konuşma özeti) verilerini siler
  /// Hem SharedPreferences'taki hem de Firestore'daki wrapped verilerini temizler
  Future<bool> resetWrappedData(String userId) async {
    debugPrint('Wrapped (konuşma özeti) verileri siliniyor...');
    
    try {
      // 1. SharedPreferences'taki wrapped verilerini temizle
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('wrappedAnalysesList');
      await prefs.remove('wrappedCacheData');
      await prefs.remove('wrappedCacheContent');
      await prefs.remove('WRAPPED_CACHE_KEY');
      await prefs.remove('WRAPPED_CACHE_CONTENT_KEY');
      await prefs.remove('WRAPPED_IS_TXT_KEY');
      
      // 2. Firestore'daki wrapped_analyses koleksiyonunu temizle
      try {
        // Kullanıcının referansı
        final userRef = _firestore.collection('users').doc(userId);
        
        // wrapped_analyses koleksiyonunu al
        final wrappedSnapshot = await userRef.collection('wrapped_analyses').get();
        
        if (wrappedSnapshot.docs.isNotEmpty) {
          debugPrint('${wrappedSnapshot.docs.length} adet wrapped analizi bulundu, siliniyor...');
          
          // Batch işlemi başlat
          WriteBatch batch = _firestore.batch();
          
          for (final doc in wrappedSnapshot.docs) {
            batch.delete(doc.reference);
          }
          
          await batch.commit();
          debugPrint('Wrapped analizleri Firestore\'dan silindi');
        } else {
          debugPrint('Silinecek wrapped analizi bulunamadı');
        }
      } catch (e) {
        debugPrint('Firestore wrapped verileri silinirken hata: $e');
        // Bu hatayı yutuyoruz, SharedPreferences temizliği gerçekleşmişse
        // işlem kısmen başarılı sayılabilir
      }
      
      debugPrint('Wrapped analiz verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Wrapped analiz verileri silinirken hata: $e');
      return false;
    }
  }

  /// Mesaj analiz verilerini siler
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
  
  /// Tüm verileri siler - Kullanıcı temel bilgileri hariç Firestore'daki tüm verileri siler
  Future<bool> resetAllData(String userId) async {
    print('🚀 DataResetService.resetAllData BAŞLATIYOR...');
    print('👤 Kullanıcı ID: $userId');
    debugPrint('🚀 TÜM VERİLER SİLME İŞLEMİ BAŞLATIYOR...');
    debugPrint('👤 Kullanıcı ID: $userId');
    
    // DUPLICATE USER ID KONTROL
    const String knownOldUserId = '0u6tzbdAqPcMeMZaxEImf1agNdm2';
    const String knownNewUserId = 'RdBb1J7AfkX8xpRwW9bZ5k4iq2Z2';
    
    print('🔍 DUPLICATE USER KONTROL:');
    print('  - Current User: $userId');
    print('  - Known Old User: $knownOldUserId');
    print('  - Known New User: $knownNewUserId');
    
    bool shouldDeleteOldUser = false;
    String additionalUserId = '';
    
    if (userId == knownNewUserId) {
      print('⚠️ UYARI: Şu anda YENİ user ID kullanılıyor');
      print('💡 ESKİ user ID\'deki verileri de siliniyor...');
      shouldDeleteOldUser = true;
      additionalUserId = knownOldUserId;
    } else if (userId == knownOldUserId) {
      print('ℹ️ BİLGİ: Şu anda ESKİ user ID kullanılıyor');
    }
    
    if (userId.isEmpty) {
      print('❌ HATA: Boş kullanıcı ID!');
      debugPrint('❌ HATA: Boş kullanıcı ID!');
      return false;
    }
    
    try {
      // Kullanıcının varlığını kontrol et
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ UYARI: Kullanıcı belgesi bulunamadı: $userId');
      } else {
        debugPrint('✅ Kullanıcı belgesi bulundu');
      }
      
      // DİNAMİK YÖNTEMİ: Kullanıcının tüm alt koleksiyonlarını sil
      debugPrint('📂 Alt koleksiyonlar siliniyor...');
      bool allSubCollectionsResult = await _deleteAllUserSubCollections(userId);
      debugPrint('📊 Tüm alt koleksiyonlar silme sonucu: $allSubCollectionsResult');
      
      // Ana koleksiyonlardaki kullanıcı verilerini sil
      bool mainCollectionsResult = await _deleteUserDataFromMainCollections(userId);
      debugPrint('Ana koleksiyonlar silme sonucu: $mainCollectionsResult');
      
      // İşlemlerin yerine oturması için kısa bir bekleme
      await Future.delayed(const Duration(seconds: 2));
      
      // Danışma verilerini de temizle
      try {
        debugPrint('Danışma verileri temizleniyor...');
        
        // Kullanıcının referansı
        final userRef = _firestore.collection('users').doc(userId);
        
        // Danışma koleksiyonunu al
        final consultationSnapshot = await userRef.collection('consultations').get();
        
        if (consultationSnapshot.docs.isNotEmpty) {
          debugPrint('${consultationSnapshot.docs.length} adet danışma verisi bulundu, siliniyor...');
          
          // Batch işlemi başlat
          WriteBatch batch = _firestore.batch();
          
          for (final doc in consultationSnapshot.docs) {
            batch.delete(doc.reference);
          }
          
          await batch.commit();
          debugPrint('Danışma verileri silindi');
        } else {
          debugPrint('Silinecek danışma verisi bulunamadı');
        }
        
        // ÖNEMLİ: Analyses koleksiyonundaki consultation tipindeki verileri de temizle
        debugPrint('Analyses koleksiyonundaki danışma verileri temizleniyor...');
        
        // Analyses koleksiyonunu al
        final analysesSnapshot = await userRef.collection('analyses').where('type', isEqualTo: 'AnalysisType.consultation').get();
        
        if (analysesSnapshot.docs.isNotEmpty) {
          debugPrint('${analysesSnapshot.docs.length} adet analyses danışma verisi bulundu, siliniyor...');
          
          // Batch işlemi başlat
          WriteBatch analysesBatch = _firestore.batch();
          
          for (final doc in analysesSnapshot.docs) {
            analysesBatch.delete(doc.reference);
          }
          
          await analysesBatch.commit();
          debugPrint('Analyses koleksiyonundaki danışma verileri silindi');
        } else {
          debugPrint('Silinecek analyses danışma verisi bulunamadı');
        }
        
      } catch (e) {
        debugPrint('Danışma verileri silinirken hata: $e');
      }
      
      // Tüm analyses koleksiyonunu temizleyen kod
      try {
        debugPrint('Tüm analyses koleksiyonu temizleniyor...');
        
        // Kullanıcının referansı
        final userRef = _firestore.collection('users').doc(userId);
        
        // Analyses koleksiyonunu al (tüm danışma geçmişi burada)
        final analysesSnapshot = await userRef.collection('analyses').get();
        
        if (analysesSnapshot.docs.isNotEmpty) {
          debugPrint('${analysesSnapshot.docs.length} adet analyses verisi bulundu, siliniyor...');
          
          // Batch işlemi başlat
          WriteBatch batch = _firestore.batch();
          
          for (final doc in analysesSnapshot.docs) {
            batch.delete(doc.reference);
          }
          
          await batch.commit();
          debugPrint('Tüm analyses verileri silindi');
        } else {
          debugPrint('Silinecek analyses verisi bulunamadı');
        }
      } catch (e) {
        debugPrint('Analyses verileri silinirken hata: $e');
      }
      
      // SharedPreferences'taki tüm cache'leri temizle
      try {
        debugPrint('SharedPreferences cache\'leri temizleniyor...');
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        
        // Tüm analiz cache'lerini temizle
        await prefs.remove('lastAnalysisResult');
        await prefs.remove('pastAnalysesCache');
        await prefs.remove('pastReportsCache');
        await prefs.remove('messageCoachCache');
        await prefs.remove('consultationCache');
        await prefs.remove('relationshipReportCache');
        await prefs.remove('userDataCache');
        await prefs.remove('settingsCache');
        await prefs.remove('preferencesCache');
        
        // Wrapped cache'leri (zaten wrapped metodunda temizleniyor ama ek güvenlik)
        await prefs.remove('wrappedAnalysesList');
        await prefs.remove('wrappedCacheData');
        await prefs.remove('wrappedCacheContent');
        await prefs.remove('WRAPPED_CACHE_KEY');
        await prefs.remove('WRAPPED_CACHE_CONTENT_KEY');
        await prefs.remove('WRAPPED_IS_TXT_KEY');
        
        debugPrint('SharedPreferences cache\'leri temizlendi');
      } catch (e) {
        debugPrint('SharedPreferences temizlenirken hata: $e');
      }
      
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
      
      // Wrapped verilerini de temizle
      bool wrappedResult = await resetWrappedData(userId);
      debugPrint('Wrapped analizi silme sonucu: $wrappedResult');
      
      // Eğer eski kullanıcı verileri de silinecekse
      bool oldUserResult = true;
      if (shouldDeleteOldUser && additionalUserId.isNotEmpty) {
        print('🔄 ESKİ KULLANICI VERİLERİ SİLİNİYOR ($additionalUserId)...');
        final bool oldSubCollectionsResult = await _deleteAllUserSubCollections(additionalUserId);
        final bool oldMainCollectionsResult = await _deleteUserDataFromMainCollections(additionalUserId);
        final bool oldWrappedResult = await resetWrappedData(additionalUserId);
        
        oldUserResult = oldSubCollectionsResult && oldMainCollectionsResult && oldWrappedResult;
        
        if (oldUserResult) {
          print('✅ ESKİ KULLANICI VERİLERİ BAŞARIYLA SİLİNDİ');
        } else {
          print('❌ ESKİ KULLANICI VERİLERİ SİLİNİRKEN HATA OLUŞTU');
        }
      }
      
      debugPrint('Tüm veriler silme işlemi sonuçları: Alt koleksiyonlar: $allSubCollectionsResult, Ana koleksiyonlar: $mainCollectionsResult, Wrapped: $wrappedResult, Eski User: $oldUserResult');
      
      // Tam başarı için tüm işlemlerin başarılı olması gerekir
      return allSubCollectionsResult && mainCollectionsResult && wrappedResult && oldUserResult;
    } catch (e) {
      print('❌ DataResetService GENEL HATA: $e');
      debugPrint('Tüm veriler silinirken hata: $e');
      return false;
    }
  }

  /// Ek kullanıcı verilerini siler (past_analyses, past_reports vb.)
  Future<bool> _deleteAdditionalUserData(String userId) async {
    debugPrint('Ek kullanıcı verileri siliniyor...');
    
    try {
      final userRef = _firestore.collection('users').doc(userId);
      WriteBatch batch = _firestore.batch();
      
      // 1. Past analyses koleksiyonunu sil
      try {
        final pastAnalysesSnapshot = await userRef.collection('past_analyses').get();
        for (final doc in pastAnalysesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${pastAnalysesSnapshot.docs.length} adet past_analyses silindi');
      } catch (e) {
        debugPrint('past_analyses silinirken hata: $e');
      }
      
      // 2. Past reports koleksiyonunu sil
      try {
        final pastReportsSnapshot = await userRef.collection('past_reports').get();
        for (final doc in pastReportsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${pastReportsSnapshot.docs.length} adet past_reports silindi');
      } catch (e) {
        debugPrint('past_reports silinirken hata: $e');
      }
      
      // 3. Past message coach koleksiyonunu sil
      try {
        final pastMessageCoachSnapshot = await userRef.collection('past_message_coach').get();
        for (final doc in pastMessageCoachSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${pastMessageCoachSnapshot.docs.length} adet past_message_coach silindi');
      } catch (e) {
        debugPrint('past_message_coach silinirken hata: $e');
      }
      
      // 4. User data koleksiyonunu sil
      try {
        final userDataSnapshot = await userRef.collection('user_data').get();
        for (final doc in userDataSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${userDataSnapshot.docs.length} adet user_data silindi');
      } catch (e) {
        debugPrint('user_data silinirken hata: $e');
      }
      
      // 5. Settings koleksiyonunu sil
      try {
        final settingsSnapshot = await userRef.collection('settings').get();
        for (final doc in settingsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${settingsSnapshot.docs.length} adet settings silindi');
      } catch (e) {
        debugPrint('settings silinirken hata: $e');
      }
      
      // 6. Preferences koleksiyonunu sil
      try {
        final preferencesSnapshot = await userRef.collection('preferences').get();
        for (final doc in preferencesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${preferencesSnapshot.docs.length} adet preferences silindi');
      } catch (e) {
        debugPrint('preferences silinirken hata: $e');
      }
      
      // 7. Cache koleksiyonunu sil
      try {
        final cacheSnapshot = await userRef.collection('cache').get();
        for (final doc in cacheSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${cacheSnapshot.docs.length} adet cache silindi');
      } catch (e) {
        debugPrint('cache silinirken hata: $e');
      }
      
      // Batch işlemini uygula
      await batch.commit();
      
      debugPrint('Ek kullanıcı verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Ek kullanıcı verileri silinirken hata: $e');
      return false;
    }
  }

  /// Kullanıcının tüm alt koleksiyonlarını dinamik olarak siler
  Future<bool> _deleteAllUserSubCollections(String userId) async {
    debugPrint('Kullanıcının tüm alt koleksiyonları siliniyor...');
    
    try {
      final userRef = _firestore.collection('users').doc(userId);
      
      // Bilinen tüm olası alt koleksiyonlar
      final List<String> possibleSubCollections = [
        'messages',
        'text_analyses', 
        'image_analyses',
        'consultations',
        'analyses',
        'wrapped_analyses',
        'past_analyses',
        'past_reports', 
        'past_message_coach',
        'user_data',
        'settings',
        'preferences',
        'cache',
        'message_coach_analyses',
        'relationship_reports',
        'notifications',
        'sessions',
        'uploads',
        'downloads',
        'temp_data',
        'logs',
        'statistics',
        'feedback'
      ];
      
      int totalDeleted = 0;
      
      for (String collectionName in possibleSubCollections) {
        try {
          debugPrint('⏳ $collectionName koleksiyonu kontrol ediliyor...');
          final collectionSnapshot = await userRef.collection(collectionName).get();
          
          // Messages için özel debug
          if (collectionName == 'messages') {
            print('🔍 MESSAGES ÖZEL KONTROL:');
            print('  - Current UserId: $userId');
            print('  - Snapshot docs length: ${collectionSnapshot.docs.length}');
            print('  - Snapshot metadata: ${collectionSnapshot.metadata}');
            if (collectionSnapshot.docs.isNotEmpty) {
              print('  - İlk döküman ID: ${collectionSnapshot.docs.first.id}');
              print('  - İlk döküman data: ${collectionSnapshot.docs.first.data()}');
            }
            
            // DİĞER USER ID'Yİ DE KONTROL ET
            const String otherUserId = '0u6tzbdAqPcMeMZaxEImf1agNdm2';
            if (userId != otherUserId) {
              print('🔍 DİĞER USER ID KONTROL ($otherUserId):');
              try {
                final otherUserSnapshot = await _firestore.collection('users').doc(otherUserId).collection('messages').get();
                print('  - Diğer user messages count: ${otherUserSnapshot.docs.length}');
              } catch (e) {
                print('  - Diğer user kontrol hatası: $e');
              }
            }
          }
          
          if (collectionSnapshot.docs.isNotEmpty) {
            debugPrint('📋 $collectionName koleksiyonunda ${collectionSnapshot.docs.length} adet döküman bulundu');
            
            // İlk olarak tek bir döküman silme testı yap (güvenlik kuralları kontrolü)
            if (collectionName == 'messages' && collectionSnapshot.docs.isNotEmpty) {
              try {
                debugPrint('🧪 Güvenlik kuralları testi: İlk döküman silinmeye çalışılıyor...');
                final testDoc = collectionSnapshot.docs.first;
                await testDoc.reference.delete();
                debugPrint('✅ Güvenlik kuralları testi başarılı: Tek döküman silindi');
                
                // Test dökümanı silindiği için listeyi güncelle
                final updatedSnapshot = await userRef.collection(collectionName).get();
                if (updatedSnapshot.docs.isEmpty) {
                  debugPrint('🎉 Test silme sonrası koleksiyon boş kaldı');
                  return true; // Eğer tek döküman varsa işlem tamamlandı
                }
              } catch (e) {
                debugPrint('❌ GÜVENLİK KURALLARI HATASI: Tek döküman bile silinemiyor!');
                debugPrint('📍 Hata: $e');
                debugPrint('🔧 Firestore güvenlik kurallarını kontrol edin!');
                throw Exception('Firestore güvenlik kuralları silme işlemini engelliyor: $e');
              }
            }
            
            // Messages için özel işlem
            if (collectionName == 'messages') {
              debugPrint('🎯 Messages koleksiyonu özel silme işlemi başlatılıyor...');
              
              // Messages altında chunks alt koleksiyonları da olabilir
              for (final messageDoc in collectionSnapshot.docs) {
                try {
                  // Chunks alt koleksiyonunu kontrol et
                  final chunksSnapshot = await messageDoc.reference.collection('chunks').get();
                  if (chunksSnapshot.docs.isNotEmpty) {
                    debugPrint('📦 Message ${messageDoc.id} için ${chunksSnapshot.docs.length} chunk bulundu');
                    
                    // Chunks'ları parçalı sil
                    const int chunkBatchLimit = 500;
                    final chunkDocs = chunksSnapshot.docs;
                    
                    for (int j = 0; j < chunkDocs.length; j += chunkBatchLimit) {
                      final chunkEndIndex = (j + chunkBatchLimit < chunkDocs.length) ? j + chunkBatchLimit : chunkDocs.length;
                      final batchChunks = chunkDocs.sublist(j, chunkEndIndex);
                      
                      WriteBatch chunksBatch = _firestore.batch();
                      for (final chunkDoc in batchChunks) {
                        chunksBatch.delete(chunkDoc.reference);
                      }
                      await chunksBatch.commit();
                    }
                    debugPrint('✅ Message ${messageDoc.id} chunks silindi');
                  }
                } catch (e) {
                  debugPrint('⚠️ Message ${messageDoc.id} chunks silinirken hata: $e');
                }
              }
            }
            
            // Ana dökümanları sil - Batch limiti için parçalı silme
            const int batchLimit = 500; // Firestore batch limiti
            final docs = collectionSnapshot.docs;
            
            debugPrint('📊 Toplam ${docs.length} döküman silme işlemi başlatılıyor...');
            
            // 500'lük parçalara böl
            for (int i = 0; i < docs.length; i += batchLimit) {
              final endIndex = (i + batchLimit < docs.length) ? i + batchLimit : docs.length;
              final batchDocs = docs.sublist(i, endIndex);
              
              debugPrint('🔄 Batch ${(i ~/ batchLimit) + 1}: ${batchDocs.length} döküman siliniyor (${i + 1}-$endIndex)');
              
              WriteBatch batch = _firestore.batch();
              
              for (final doc in batchDocs) {
                batch.delete(doc.reference);
              }
              
              try {
                await batch.commit();
                debugPrint('✅ Batch ${(i ~/ batchLimit) + 1} başarıyla silindi');
                
                // Firestore rate limiting için kısa bekleme
                if (endIndex < docs.length) {
                  await Future.delayed(Duration(milliseconds: 100));
                }
              } catch (e) {
                debugPrint('❌ Batch ${(i ~/ batchLimit) + 1} silinirken hata: $e');
                throw e;
              }
            }
            
            totalDeleted += docs.length;
            debugPrint('✅ $collectionName koleksiyonu tamamen silindi (${docs.length} döküman)');
            
            // Silme sonrası doğrulama
            final verificationSnapshot = await userRef.collection(collectionName).get();
            if (verificationSnapshot.docs.isNotEmpty) {
              debugPrint('❌ HATA: $collectionName silme sonrası hala ${verificationSnapshot.docs.length} döküman var!');
            } else {
              debugPrint('✅ DOĞRULAMA: $collectionName tamamen silindi');
            }
          } else {
            debugPrint('🔍 $collectionName koleksiyonu zaten boş');
          }
        } catch (e) {
          debugPrint('❌ $collectionName koleksiyonu silinirken hata: $e');
          debugPrint('📍 Hata detayı: ${e.toString()}');
          // Tek koleksiyon hatası tüm işlemi durdurmasın
        }
      }
      
      debugPrint('📈 Toplam $totalDeleted döküman silindi');
      
      // FINAL KONTROL: Messages koleksiyonunu özel olarak kontrol et
      try {
        debugPrint('🔍 FINAL KONTROL: Messages koleksiyonu tekrar kontrol ediliyor...');
        final finalMessagesCheck = await userRef.collection('messages').get();
        if (finalMessagesCheck.docs.isNotEmpty) {
          debugPrint('⚠️ PROBLEM: Messages koleksiyonunda hala ${finalMessagesCheck.docs.length} döküman var!');
          debugPrint('📋 Kalan dökümanlarm ID\'leri:');
          for (final doc in finalMessagesCheck.docs) {
            debugPrint('  - ${doc.id}');
          }
          return false;
        } else {
          debugPrint('✅ BAŞARILI: Messages koleksiyonu tamamen temiz');
        }
      } catch (e) {
        debugPrint('❌ Final kontrol sırasında hata: $e');
      }
      
      return true;
    } catch (e) {
      debugPrint('Alt koleksiyonlar silinirken genel hata: $e');
      return false;
    }
  }

  /// Ana koleksiyonlardaki kullanıcı verilerini siler
  Future<bool> _deleteUserDataFromMainCollections(String userId) async {
    debugPrint('Ana koleksiyonlardaki kullanıcı verileri siliniyor...');
    
    try {
      WriteBatch batch = _firestore.batch();
      
      // 1. relationship_reports koleksiyonundaki kullanıcı raporları
      try {
        final relationshipReportsSnapshot = await _firestore
            .collection('relationship_reports')
            .where('userId', isEqualTo: userId)
            .get();
            
        for (final doc in relationshipReportsSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${relationshipReportsSnapshot.docs.length} adet relationship_reports silindi');
      } catch (e) {
        debugPrint('relationship_reports silinirken hata: $e');
      }
      
      // 2. message_coach_history koleksiyonundaki kullanıcı verileri
      try {
        final messageCoachHistorySnapshot = await _firestore
            .collection('message_coach_history')
            .where('userId', isEqualTo: userId)
            .get();
            
        for (final doc in messageCoachHistorySnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${messageCoachHistorySnapshot.docs.length} adet message_coach_history silindi');
      } catch (e) {
        debugPrint('message_coach_history silinirken hata: $e');
      }
      
      // 3. analyses koleksiyonundaki kullanıcı analizleri (ana koleksiyon olarak)
      try {
        final analysesSnapshot = await _firestore
            .collection('analyses')
            .where('userId', isEqualTo: userId)
            .get();
            
        for (final doc in analysesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${analysesSnapshot.docs.length} adet ana analyses silindi');
      } catch (e) {
        debugPrint('ana analyses silinirken hata: $e');
      }
      
      // 4. user_activities koleksiyonundaki kullanıcı aktiviteleri
      try {
        final activitiesSnapshot = await _firestore
            .collection('user_activities')
            .where('userId', isEqualTo: userId)
            .get();
            
        for (final doc in activitiesSnapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('${activitiesSnapshot.docs.length} adet user_activities silindi');
      } catch (e) {
        debugPrint('user_activities silinirken hata: $e');
      }
      
      // 5. Kullanıcı ana belgesindeki veri alanlarını sıfırla (kullanıcı bilgileri hariç)
      try {
        batch.update(_firestore.collection('users').doc(userId), {
          'sonAnalizSonucu': null,
          'analizGecmisi': [],
          'lastRelationshipReport': null,
          'relationshipHistory': [],
          'lastMessageCoachData': null,
          'messageCoachHistory': [],
          'lastWrappedData': null,
          'wrappedHistory': [],
          'consultationHistory': [],
          'preferences.lastResetDate': FieldValue.serverTimestamp(),
          // Kullanıcı temel bilgileri (displayName, email, photoURL, createdAt) KORUNUYOR
        });
        debugPrint('Kullanıcı ana belgesi veri alanları sıfırlandı');
      } catch (e) {
        debugPrint('Kullanıcı ana belgesi güncellenirken hata: $e');
      }
      
      await batch.commit();
      debugPrint('Ana koleksiyonlardaki kullanıcı verileri başarıyla silindi');
      return true;
    } catch (e) {
      debugPrint('Ana koleksiyonlardaki veriler silinirken hata: $e');
      return false;
    }
  }
} 